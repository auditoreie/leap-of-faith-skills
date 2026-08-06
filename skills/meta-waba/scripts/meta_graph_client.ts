/**
 * meta_graph_client.ts
 * --------------------
 * HTTP client base para a Graph API da Meta (WhatsApp Business Platform).
 *
 * Encapsula:
 *  - Auth via Bearer token (com escape para `OAuth` do Resumable Upload)
 *  - Retry exponencial com jitter para 429/5xx/erros de rede
 *  - Leitura dos headers de rate limit (`X-App-Usage`, `X-Business-Use-Case-Usage`)
 *  - Mapeamento de erros para `MetaApiError` tipado
 *  - Captura de `fbtrace_id` em todo erro para correlação com Meta Support
 *
 * Dependências sugeridas: `undici` (ou `axios` — basta trocar a chamada).
 */

import { request as undiciRequest } from 'undici';
import { setTimeout as sleep } from 'node:timers/promises';

export interface MetaGraphClientOptions {
  /** Token de acesso. BISU para Tech Provider, System User Token para apps próprios. */
  token: string;
  /** Versão da Graph API. Parametrize via env e atualize anualmente. */
  apiVersion?: string;
  /** Base URL — só mude para testes. */
  baseUrl?: string;
  /** Máximo de retries. */
  maxRetries?: number;
  /** Logger para hooks (opcional). */
  logger?: {
    debug: (msg: string, extra?: unknown) => void;
    warn: (msg: string, extra?: unknown) => void;
    error: (msg: string, extra?: unknown) => void;
  };
}

export interface RequestOptions {
  /** Query string como objeto. Valores são serializados como JSON quando arrays/objetos. */
  query?: Record<string, unknown>;
  /** Body JSON. */
  body?: unknown;
  /** Headers extras (Content-Type já é setado automaticamente). */
  headers?: Record<string, string>;
  /** Sobrescreve o método de auth — use 'OAuth' apenas para Resumable Upload bytes. */
  authScheme?: 'Bearer' | 'OAuth';
  /** Permite upload de body raw (Buffer) — não JSON. */
  rawBody?: Buffer;
  /** Timeout em ms (default 30s). */
  timeoutMs?: number;
  /** Idempotency key opcional para retries seguros. */
  idempotencyKey?: string;
  /** Não retentar mesmo em 5xx (uso raro). */
  noRetry?: boolean;
}

export interface RateLimitInfo {
  appCallCount?: number;
  appTotalCpu?: number;
  appTotalTime?: number;
  businessUseCases?: Record<string, { call_count: number; total_cputime: number; total_time: number }>;
}

export class MetaApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: number,
    public readonly subcode: number | null,
    public readonly type: string,
    public readonly userMessage: string,
    public readonly fbtraceId: string,
    public readonly rawBody: string,
  ) {
    super(`Meta API ${status} (code ${code}/${subcode ?? '-'}): ${userMessage}${fbtraceId ? ` [trace ${fbtraceId}]` : ''}`);
    this.name = 'MetaApiError';
  }

  static fromHttp(status: number, body: string): MetaApiError {
    try {
      const parsed = JSON.parse(body);
      const e = parsed?.error ?? {};
      return new MetaApiError(
        status,
        e.code ?? status,
        e.error_subcode ?? null,
        e.type ?? 'UnknownError',
        e.error_user_msg ?? e.message ?? body.slice(0, 500),
        e.fbtrace_id ?? '',
        body,
      );
    } catch {
      return new MetaApiError(status, status, null, 'UnknownError', body.slice(0, 500), '', body);
    }
  }

  isPermanent(): boolean {
    return [
      100, 102, 200, 368, 506,
      131008, 131009, 131021, 131045, 131047, 131049, 131051,
      132000, 132005, 132012, 132016,
      133005, 133006, 133010,
    ].includes(this.code);
  }

  isRateLimit(): boolean {
    return [4, 17, 32, 80007, 80008, 130429].includes(this.code) || this.status === 429;
  }

  isTransient(): boolean {
    return this.isRateLimit() || this.status >= 500;
  }
}

export class MetaGraphClient {
  private readonly token: string;
  private readonly apiVersion: string;
  private readonly baseUrl: string;
  private readonly maxRetries: number;
  private readonly logger?: MetaGraphClientOptions['logger'];

  /** Última leitura de rate limit (atualizada a cada chamada). */
  public lastRateLimit: RateLimitInfo = {};

  constructor(opts: MetaGraphClientOptions) {
    this.token = opts.token;
    this.apiVersion = opts.apiVersion ?? 'v23.0';
    this.baseUrl = opts.baseUrl ?? 'https://graph.facebook.com';
    this.maxRetries = opts.maxRetries ?? 5;
    this.logger = opts.logger;
  }

  private buildUrl(path: string, query?: Record<string, unknown>): string {
    // Path absoluto não inclui versão; relativo prefixa.
    const url = new URL(path.startsWith('http') ? path : `${this.baseUrl}/${this.apiVersion}${path.startsWith('/') ? path : `/${path}`}`);
    if (query) {
      for (const [k, v] of Object.entries(query)) {
        if (v === undefined || v === null) continue;
        if (Array.isArray(v) || (typeof v === 'object' && !(v instanceof Date))) {
          url.searchParams.set(k, JSON.stringify(v));
        } else {
          url.searchParams.set(k, String(v));
        }
      }
    }
    return url.toString();
  }

  private parseRateLimitHeaders(headers: Record<string, string | string[] | undefined>): void {
    const appUsageRaw = headers['x-app-usage'];
    if (typeof appUsageRaw === 'string') {
      try {
        const parsed = JSON.parse(appUsageRaw);
        this.lastRateLimit.appCallCount = parsed.call_count;
        this.lastRateLimit.appTotalCpu = parsed.total_cputime;
        this.lastRateLimit.appTotalTime = parsed.total_time;
      } catch { /* ignore */ }
    }
    const bucRaw = headers['x-business-use-case-usage'];
    if (typeof bucRaw === 'string') {
      try {
        this.lastRateLimit.businessUseCases = JSON.parse(bucRaw);
      } catch { /* ignore */ }
    }
  }

  /** Faz uma request com retry. */
  async request<T = unknown>(
    method: 'GET' | 'POST' | 'DELETE' | 'PUT' | 'PATCH',
    path: string,
    opts: RequestOptions = {},
  ): Promise<T> {
    const url = this.buildUrl(path, opts.query);
    const authScheme = opts.authScheme ?? 'Bearer';

    const headers: Record<string, string> = {
      Authorization: `${authScheme} ${this.token}`,
      ...opts.headers,
    };

    let bodyToSend: Buffer | string | undefined;
    if (opts.rawBody) {
      bodyToSend = opts.rawBody;
      headers['Content-Type'] = headers['Content-Type'] ?? 'application/octet-stream';
    } else if (opts.body !== undefined) {
      bodyToSend = JSON.stringify(opts.body);
      headers['Content-Type'] = 'application/json';
    }

    let attempt = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      attempt++;
      try {
        const res = await undiciRequest(url, {
          method,
          headers,
          body: bodyToSend,
          headersTimeout: opts.timeoutMs ?? 30_000,
          bodyTimeout: opts.timeoutMs ?? 30_000,
        });

        // @ts-expect-error: undici headers compatible
        this.parseRateLimitHeaders(res.headers);

        const text = await res.body.text();
        const status = res.statusCode;

        if (status >= 200 && status < 300) {
          this.logger?.debug('meta_graph_ok', { method, path, status, attempt });
          if (text.length === 0) return undefined as T;
          try {
            return JSON.parse(text) as T;
          } catch {
            return text as unknown as T;
          }
        }

        const err = MetaApiError.fromHttp(status, text);
        const shouldRetry = !opts.noRetry && err.isTransient() && attempt <= this.maxRetries;
        if (shouldRetry) {
          const delay = this.computeBackoff(attempt);
          this.logger?.warn('meta_graph_retry', { method, path, status, code: err.code, attempt, delay });
          await sleep(delay);
          continue;
        }
        this.logger?.error('meta_graph_error', { method, path, status, code: err.code, fbtraceId: err.fbtraceId });
        throw err;
      } catch (err) {
        if (err instanceof MetaApiError) throw err;
        // Erros de rede — retentar
        if (attempt <= this.maxRetries && !opts.noRetry) {
          const delay = this.computeBackoff(attempt);
          this.logger?.warn('meta_graph_network_retry', { method, path, attempt, delay, message: (err as Error).message });
          await sleep(delay);
          continue;
        }
        throw err;
      }
    }
  }

  private computeBackoff(attempt: number): number {
    // 2^n segundos com jitter ±25%, máximo 60s
    const base = Math.min(60_000, 1000 * 2 ** (attempt - 1));
    const jitter = base * (Math.random() * 0.5 - 0.25);
    return Math.max(500, Math.floor(base + jitter));
  }

  // Helpers convenientes

  get<T>(path: string, query?: Record<string, unknown>) {
    return this.request<T>('GET', path, { query });
  }
  post<T>(path: string, body?: unknown, query?: Record<string, unknown>) {
    return this.request<T>('POST', path, { body, query });
  }
  delete<T>(path: string, query?: Record<string, unknown>, body?: unknown) {
    return this.request<T>('DELETE', path, { query, body });
  }
}

// Exemplo de uso
//
// const meta = new MetaGraphClient({
//   token: process.env.META_BISU!,
//   apiVersion: 'v23.0',
//   logger: pinoLogger,
// });
//
// const templates = await meta.get<{ data: any[] }>(`/${wabaId}/message_templates`, {
//   fields: 'id,name,language,status,category,components',
//   limit: 200,
// });
//
// const created = await meta.post(`/${wabaId}/message_templates`, {
//   name: 'agendamento_confirmacao',
//   category: 'UTILITY',
//   language: 'pt_BR',
//   components: [...],
// });
