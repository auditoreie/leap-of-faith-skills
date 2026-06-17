/**
 * resumable_upload.ts
 * -------------------
 * Cliente das 3 etapas da Resumable Upload API da Meta.
 *
 * Produz `header_handle` para usar em:
 *  - Templates com HEADER de mídia (`example.header_handle`)
 *  - Foto de perfil comercial (`profile_picture_handle`)
 *
 * NÃO confundir com a Cloud API Media (`/<PHONE_NUMBER_ID>/media`):
 *   - Resumable Upload usa app token e Authorization: OAuth.
 *   - Cloud API Media usa BISU/System User e Authorization: Bearer.
 *
 * Recursos:
 *  - Chunking automático para arquivos > CHUNK_SIZE.
 *  - Retry pelo `file_offset` reportado pela Meta após falha.
 *  - Cache opcional por SHA-256 (interface plugável: memória, Redis, DB).
 *  - Header `Authorization: OAuth` correto na etapa 2.
 *
 * Pré-requisito: validar localmente mime + tamanho ANTES de chamar `uploadForTemplate`,
 * porque a Meta às vezes aceita um upload e depois rejeita ao criar o template.
 *
 * Limites canônicos:
 *  - image/jpeg, image/png      → 5 MB
 *  - video/mp4, video/3gp (H.264 + AAC) → 16 MB
 *  - application/pdf            → 100 MB
 */

import { createHash, createReadStream } from 'node:crypto';
import { stat, readFile } from 'node:fs/promises';
import { request as undiciRequest } from 'undici';
import { setTimeout as sleep } from 'node:timers/promises';

// =============================================================================
// Tipos
// =============================================================================

export type SupportedMime =
  | 'image/jpeg'
  | 'image/png'
  | 'video/mp4'
  | 'video/3gp'
  | 'application/pdf';

export interface ResumableUploadOptions {
  /** App ID da Meta (do App Dashboard). */
  appId: string;
  /** Token: pode ser `<APP_ID>|<APP_SECRET>` ou um System User token com whatsapp_business_management. */
  token: string;
  /** Versão Graph API. Default `v23.0`. */
  apiVersion?: string;
  /** Cache opcional para evitar reupload do mesmo arquivo. */
  cache?: HandleCache;
  /** Tamanho do chunk em bytes. Default 4 MB. */
  chunkSize?: number;
  /** Máximo de retries por chunk. */
  maxRetries?: number;
  /** Logger opcional. */
  logger?: {
    debug: (msg: string, extra?: unknown) => void;
    warn: (msg: string, extra?: unknown) => void;
    error: (msg: string, extra?: unknown) => void;
  };
}

export interface UploadInput {
  /** Caminho local do arquivo OU Buffer já carregado. Use `path` para arquivos grandes. */
  path?: string;
  buffer?: Buffer;
  fileName: string;
  mime: SupportedMime;
}

export interface UploadResult {
  /** Header handle a ser usado em templates ou business profile. */
  handle: string;
  /** SHA-256 do arquivo (útil para indexar). */
  sha256: string;
  /** Tamanho em bytes. */
  sizeBytes: number;
  /** Veio do cache? */
  fromCache: boolean;
}

export interface HandleCache {
  get(sha256: string): Promise<string | null>;
  set(sha256: string, handle: string, mime: string, sizeBytes: number): Promise<void>;
}

/** Implementação simples em memória — apenas para dev. Em produção, use Redis ou tabela. */
export class InMemoryHandleCache implements HandleCache {
  private readonly map = new Map<string, string>();
  async get(sha256: string): Promise<string | null> {
    return this.map.get(sha256) ?? null;
  }
  async set(sha256: string, handle: string): Promise<void> {
    this.map.set(sha256, handle);
  }
}

// =============================================================================
// Validação local (rápida — antes de gastar quota)
// =============================================================================

const SIZE_LIMITS_BYTES: Record<SupportedMime, number> = {
  'image/jpeg': 5 * 1024 * 1024,
  'image/png': 5 * 1024 * 1024,
  'video/mp4': 16 * 1024 * 1024,
  'video/3gp': 16 * 1024 * 1024,
  'application/pdf': 100 * 1024 * 1024,
};

export function validateMediaForTemplate(mime: string, sizeBytes: number): void {
  if (!(mime in SIZE_LIMITS_BYTES)) {
    throw new Error(`Mime ${mime} não suportado em template HEADER. Aceitos: ${Object.keys(SIZE_LIMITS_BYTES).join(', ')}`);
  }
  const limit = SIZE_LIMITS_BYTES[mime as SupportedMime];
  if (sizeBytes > limit) {
    throw new Error(`Arquivo ${(sizeBytes / 1024 / 1024).toFixed(1)} MB excede limite de ${(limit / 1024 / 1024).toFixed(0)} MB para ${mime}.`);
  }
}

// =============================================================================
// Cliente
// =============================================================================

export class ResumableUploadClient {
  private readonly appId: string;
  private readonly token: string;
  private readonly apiVersion: string;
  private readonly cache?: HandleCache;
  private readonly chunkSize: number;
  private readonly maxRetries: number;
  private readonly logger?: ResumableUploadOptions['logger'];

  constructor(opts: ResumableUploadOptions) {
    this.appId = opts.appId;
    this.token = opts.token;
    this.apiVersion = opts.apiVersion ?? 'v23.0';
    this.cache = opts.cache;
    this.chunkSize = opts.chunkSize ?? 4 * 1024 * 1024;
    this.maxRetries = opts.maxRetries ?? 5;
    this.logger = opts.logger;
  }

  /**
   * Sobe arquivo e retorna o `header_handle`.
   * Faz cache por SHA-256 se `cache` foi configurado.
   */
  async uploadForTemplate(input: UploadInput): Promise<UploadResult> {
    const { buffer, sizeBytes } = await this.loadInput(input);
    validateMediaForTemplate(input.mime, sizeBytes);

    const sha256 = createHash('sha256').update(buffer).digest('hex');

    // Cache hit?
    if (this.cache) {
      const cached = await this.cache.get(sha256);
      if (cached) {
        this.logger?.debug('resumable_cache_hit', { sha256, handle: cached });
        return { handle: cached, sha256, sizeBytes, fromCache: true };
      }
    }

    // Etapa 1 — iniciar sessão
    const sessionId = await this.startSession(input.fileName, sizeBytes, input.mime);

    // Etapa 2 — enviar bytes (com chunking + retry de offset)
    const handle = await this.uploadBytesWithResume(sessionId, buffer);

    if (this.cache) {
      await this.cache.set(sha256, handle, input.mime, sizeBytes);
    }

    return { handle, sha256, sizeBytes, fromCache: false };
  }

  // -------------------------------------------------------------------------
  // Helpers internos
  // -------------------------------------------------------------------------

  private async loadInput(input: UploadInput): Promise<{ buffer: Buffer; sizeBytes: number }> {
    if (input.buffer) {
      return { buffer: input.buffer, sizeBytes: input.buffer.length };
    }
    if (!input.path) throw new Error('UploadInput precisa de `path` OU `buffer`.');
    const stats = await stat(input.path);
    const buffer = await readFile(input.path);
    return { buffer, sizeBytes: stats.size };
  }

  /** Etapa 1 — POST /<APP_ID>/uploads */
  private async startSession(fileName: string, fileLength: number, fileType: string): Promise<string> {
    const url = new URL(`https://graph.facebook.com/${this.apiVersion}/${this.appId}/uploads`);
    url.searchParams.set('file_name', fileName);
    url.searchParams.set('file_length', String(fileLength));
    url.searchParams.set('file_type', fileType);
    url.searchParams.set('access_token', this.token);

    const res = await undiciRequest(url.toString(), { method: 'POST' });
    const text = await res.body.text();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw new Error(`Resumable startSession falhou: ${res.statusCode} ${text}`);
    }
    const parsed = JSON.parse(text) as { id: string };
    if (!parsed.id) throw new Error(`Resumable startSession sem id: ${text}`);
    this.logger?.debug('resumable_session_started', { sessionId: parsed.id, fileLength, fileType });
    return parsed.id;
  }

  /** Etapa 2 — envia bytes a partir do offset; em caso de falha, consulta offset atual e retoma. */
  private async uploadBytesWithResume(sessionId: string, buffer: Buffer): Promise<string> {
    let offset = 0;
    let attempt = 0;

    while (offset < buffer.length) {
      const chunk = buffer.subarray(offset, Math.min(offset + this.chunkSize, buffer.length));

      try {
        const handle = await this.sendChunk(sessionId, chunk, offset);
        offset += chunk.length;
        // Se o servidor já retornou handle, terminou.
        if (handle) {
          this.logger?.debug('resumable_done', { sessionId, sizeBytes: buffer.length });
          return handle;
        }
      } catch (err) {
        attempt++;
        if (attempt > this.maxRetries) throw err;

        // Consultar offset atual e retomar
        const currentOffset = await this.queryOffset(sessionId);
        const delay = Math.min(30_000, 1000 * 2 ** (attempt - 1) + Math.floor(Math.random() * 500));
        this.logger?.warn('resumable_chunk_failed_retrying', {
          sessionId, attempt, oldOffset: offset, currentOffset, delay,
          message: (err as Error).message,
        });
        offset = currentOffset;
        await sleep(delay);
      }
    }

    // Se chegamos aqui sem retornar handle no chunk final, algo errado.
    throw new Error('Resumable Upload terminou bytes mas não recebeu handle.');
  }

  /**
   * POST /<UPLOAD_SESSION_ID> com bytes raw.
   *
   * IMPORTANTE: o header Authorization aqui é `OAuth <TOKEN>`, não `Bearer`.
   * Esta é a única exceção em toda a Cloud API. Se trocar para Bearer, vem OAuthException.
   */
  private async sendChunk(sessionId: string, chunk: Buffer, offset: number): Promise<string | null> {
    const url = `https://graph.facebook.com/${this.apiVersion}/${sessionId}`;
    const res = await undiciRequest(url, {
      method: 'POST',
      headers: {
        Authorization: `OAuth ${this.token}`,
        file_offset: String(offset),
        'Content-Type': 'application/octet-stream',
      },
      body: chunk,
      headersTimeout: 120_000,
      bodyTimeout: 120_000,
    });
    const text = await res.body.text();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw new Error(`Resumable sendChunk falhou: ${res.statusCode} ${text}`);
    }
    // Quando termina, Meta retorna { h: "..." }
    try {
      const parsed = JSON.parse(text) as { h?: string };
      return parsed.h ?? null;
    } catch {
      return null;
    }
  }

  /** Consulta offset atual após falha — GET /<UPLOAD_SESSION_ID>. */
  private async queryOffset(sessionId: string): Promise<number> {
    const url = `https://graph.facebook.com/${this.apiVersion}/${sessionId}`;
    const res = await undiciRequest(url, {
      method: 'GET',
      headers: { Authorization: `OAuth ${this.token}` },
    });
    const text = await res.body.text();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw new Error(`Resumable queryOffset falhou: ${res.statusCode} ${text}`);
    }
    const parsed = JSON.parse(text) as { file_offset?: number };
    return parsed.file_offset ?? 0;
  }
}

// =============================================================================
// Exemplo de uso
// =============================================================================

// const client = new ResumableUploadClient({
//   appId: process.env.META_APP_ID!,
//   token: `${process.env.META_APP_ID}|${process.env.META_APP_SECRET}`,
//   apiVersion: 'v23.0',
//   cache: new InMemoryHandleCache(),
//   logger: pino(),
// });
//
// const { handle } = await client.uploadForTemplate({
//   path: '/tmp/produto_demo.mp4',
//   fileName: 'produto_demo.mp4',
//   mime: 'video/mp4',
// });
//
// // Use handle em template:
// // components: [{ type: 'HEADER', format: 'VIDEO', example: { header_handle: [handle] } }, ...]
