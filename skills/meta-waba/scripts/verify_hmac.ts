/**
 * verify_hmac.ts
 * --------------
 * Validação de assinatura HMAC SHA-256 para webhooks da Meta.
 *
 * Princípios:
 *  - Compara contra o RAW BODY (Buffer), nunca contra JSON parseado.
 *  - Usa `timingSafeEqual` para evitar timing attacks.
 *  - O segredo é o **App Secret**, não o Verify Token.
 *  - Inclui middlewares prontos para Express e Fastify.
 *
 * Uso de Express:
 *
 *   import express from 'express';
 *   import { expressWebhookMiddleware } from './verify_hmac';
 *
 *   const app = express();
 *   app.post(
 *     '/webhooks/whatsapp',
 *     expressWebhookMiddleware({ appSecret: process.env.META_APP_SECRET! }),
 *     async (req, res) => {
 *       // req.body já está parseado e a assinatura já foi validada
 *       await enqueue(req.body, (req as any).rawBody);
 *       res.sendStatus(200);
 *     },
 *   );
 *
 * Uso de Fastify:
 *
 *   import fastify from 'fastify';
 *   import { registerFastifyWebhookRoute } from './verify_hmac';
 *
 *   const app = fastify();
 *   registerFastifyWebhookRoute(app, '/webhooks/whatsapp', process.env.META_APP_SECRET!, async (req, reply) => {
 *     await enqueue(req.body, req.rawBody);
 *     reply.code(200).send();
 *   });
 */

import { createHmac, timingSafeEqual } from 'node:crypto';
import type { Request, Response, NextFunction, RequestHandler } from 'express';
import express from 'express';

// =============================================================================
// CORE: validação independente de framework
// =============================================================================

export interface VerifyResult {
  valid: boolean;
  reason?: 'missing_header' | 'wrong_format' | 'length_mismatch' | 'signature_mismatch';
}

/**
 * Valida o header `X-Hub-Signature-256` contra o body cru.
 * Use sempre o `rawBody` em Buffer — não o JSON parseado.
 */
export function verifyMetaSignature(
  rawBody: Buffer,
  signatureHeader: string | undefined,
  appSecret: string,
): VerifyResult {
  if (!signatureHeader) return { valid: false, reason: 'missing_header' };
  if (!signatureHeader.startsWith('sha256=')) return { valid: false, reason: 'wrong_format' };

  const expectedHex = createHmac('sha256', appSecret).update(rawBody).digest('hex');
  const receivedHex = signatureHeader.slice('sha256='.length);

  if (expectedHex.length !== receivedHex.length) {
    return { valid: false, reason: 'length_mismatch' };
  }

  const a = Buffer.from(expectedHex, 'hex');
  const b = Buffer.from(receivedHex, 'hex');
  if (a.length !== b.length) return { valid: false, reason: 'length_mismatch' };

  const ok = timingSafeEqual(a, b);
  return ok ? { valid: true } : { valid: false, reason: 'signature_mismatch' };
}

// =============================================================================
// VERIFY TOKEN (GET challenge na configuração inicial do webhook)
// =============================================================================

/**
 * Valida o GET de verificação inicial.
 * Retorna o `hub.challenge` se OK, ou null se falhar.
 */
export function verifyChallenge(
  query: Record<string, string | string[] | undefined>,
  expectedToken: string,
): string | null {
  const mode = query['hub.mode'];
  const token = query['hub.verify_token'];
  const challenge = query['hub.challenge'];
  if (mode === 'subscribe' && token === expectedToken && typeof challenge === 'string') {
    return challenge;
  }
  return null;
}

// =============================================================================
// EXPRESS — middleware completo
// =============================================================================

export interface ExpressMiddlewareOptions {
  appSecret: string;
  /** Verify token para responder o GET challenge. Se omitido, GET retorna 403. */
  verifyToken?: string;
  /** Hook para logar tentativas inválidas (suspeitas de abuso). */
  onInvalid?: (req: Request, reason: string) => void;
}

/**
 * Middleware que:
 *  - Em GET: responde ao hub.challenge.
 *  - Em POST: valida HMAC contra rawBody e popula req.body.
 *
 * IMPORTANTE: este middleware substitui o `express.json()` padrão para esta rota
 * — ele cuida do parse e da preservação do rawBody numa só passada.
 */
export function expressWebhookMiddleware(opts: ExpressMiddlewareOptions): RequestHandler[] {
  const jsonParser = express.json({
    verify: (req: Request, _res: Response, buf: Buffer) => {
      (req as Request & { rawBody?: Buffer }).rawBody = buf;
    },
    limit: '5mb',
  });

  const validator = (req: Request, res: Response, next: NextFunction): void => {
    if (req.method === 'GET') {
      if (!opts.verifyToken) {
        res.sendStatus(403);
        return;
      }
      const challenge = verifyChallenge(
        req.query as Record<string, string | string[] | undefined>,
        opts.verifyToken,
      );
      if (challenge !== null) {
        res.status(200).type('text/plain').send(challenge);
        return;
      }
      res.sendStatus(403);
      return;
    }

    const rawBody = (req as Request & { rawBody?: Buffer }).rawBody;
    if (!rawBody) {
      opts.onInvalid?.(req, 'no_raw_body');
      res.sendStatus(400);
      return;
    }

    const sig = req.header('x-hub-signature-256');
    const result = verifyMetaSignature(rawBody, sig, opts.appSecret);
    if (!result.valid) {
      opts.onInvalid?.(req, result.reason ?? 'unknown');
      res.sendStatus(401);
      return;
    }

    next();
  };

  return [jsonParser, validator];
}

// =============================================================================
// FASTIFY — registrar rota com parser customizado
// =============================================================================

import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';

declare module 'fastify' {
  interface FastifyRequest {
    rawBody?: Buffer;
  }
}

/**
 * Registra parser de application/json que preserva rawBody, e a rota POST/GET
 * com validação HMAC. Você passa o handler de POST.
 */
export function registerFastifyWebhookRoute(
  app: FastifyInstance,
  routePath: string,
  appSecret: string,
  postHandler: (req: FastifyRequest, reply: FastifyReply) => void | Promise<void>,
  verifyToken?: string,
): void {
  app.addContentTypeParser(
    'application/json',
    { parseAs: 'buffer' },
    (req, body, done) => {
      try {
        const buf = body as Buffer;
        req.rawBody = buf;
        const json = JSON.parse(buf.toString('utf8'));
        done(null, json);
      } catch (err) {
        done(err as Error);
      }
    },
  );

  if (verifyToken) {
    app.get(routePath, async (req, reply) => {
      const challenge = verifyChallenge(
        req.query as Record<string, string | string[] | undefined>,
        verifyToken,
      );
      if (challenge !== null) {
        return reply.code(200).type('text/plain').send(challenge);
      }
      return reply.code(403).send();
    });
  }

  app.post(routePath, async (req, reply) => {
    if (!req.rawBody) return reply.code(400).send();
    const sig = req.headers['x-hub-signature-256'];
    const sigStr = Array.isArray(sig) ? sig[0] : sig;
    const result = verifyMetaSignature(req.rawBody, sigStr, appSecret);
    if (!result.valid) return reply.code(401).send();
    return postHandler(req, reply);
  });
}
