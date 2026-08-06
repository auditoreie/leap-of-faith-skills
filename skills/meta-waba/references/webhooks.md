# Webhooks — Subscribed apps + HMAC + Handlers

> Webhooks são a fonte da verdade para tudo o que muda no estado de WABA, números, templates e mensagens. Polling é antipattern. Esta peça precisa ser à prova de bala porque é onde os dados chegam, e a Meta retenta agressivamente se você falhar.

## Arquitetura da entrega

```
Meta envia POST → seu endpoint público HTTPS → valida HMAC → 
enfileira raw payload → responde 200 em ≤5s → worker processa async
```

Princípio **inviolável:** responder 200 em até 5 segundos sempre. Se demorar mais, a Meta entende que falhou e retenta. Você acaba processando o mesmo evento N vezes.

## Configuração no App Dashboard

1. App Meta → Produtos → WhatsApp → Configuration.
2. **Callback URL:** `https://app.fgbconsultoria.com.br/webhooks/whatsapp` (HTTPS obrigatório, certificado válido — self-signed não passa).
3. **Verify token:** string aleatória 32+ chars, persistida em env `META_WEBHOOK_VERIFY_TOKEN`.
4. **Webhook fields a inscrever** (lista completa abaixo).

## Verificação inicial (GET challenge)

Ao salvar a configuração, a Meta faz GET no callback:

```
GET /webhooks/whatsapp?hub.mode=subscribe&hub.verify_token=<SEU_TOKEN>&hub.challenge=<RANDOM>
```

Você precisa responder com o `hub.challenge` em texto puro:

```typescript
// Express
app.get('/webhooks/whatsapp', (req, res) => {
  if (
    req.query['hub.mode'] === 'subscribe' &&
    req.query['hub.verify_token'] === process.env.META_WEBHOOK_VERIFY_TOKEN
  ) {
    return res.status(200).send(req.query['hub.challenge']);
  }
  return res.sendStatus(403);
});
```

## Subscribe / List / Unsubscribe (por WABA)

Configurar a callback URL no App **não** é suficiente. Para receber eventos de uma WABA, precisa também:

```http
# Assinar
POST https://graph.facebook.com/v23.0/<WABA_ID>/subscribed_apps
Authorization: Bearer <BISU_OU_SYSTEM_USER_TOKEN>

# Listar apps assinados
GET https://graph.facebook.com/v23.0/<WABA_ID>/subscribed_apps

# Desassinar (para offboarding)
DELETE https://graph.facebook.com/v23.0/<WABA_ID>/subscribed_apps
```

Sem esse subscribe, **nenhum webhook chega** daquela WABA, mesmo com a callback configurada. Fazer subscribe automaticamente após Embedded Signup e logar o resultado.

## Webhook fields a inscrever (todos os relevantes)

No App Dashboard → WhatsApp → Configuration → Webhook fields:

| Field | O que dispara | Carregar para |
|---|---|---|
| `messages` | Mensagem recebida + status (sent/delivered/read/failed) de mensagens enviadas | Inbox + tracking de envio |
| `message_template_status_update` | Aprovação/rejeição/pausa/disable de template | Atualizar `status` local |
| `message_template_quality_update` | `quality_score` mudou | Alertar UI quando vai para `RED` |
| `template_category_update` | Meta reclassificou (UTILITY ↔ MARKETING) | Avisar cliente do impacto financeiro |
| `message_template_components_update` | Componentes/variáveis foram detectados | Resync metadados |
| `phone_number_quality_update` | `quality_rating` do número mudou | Dashboard |
| `phone_number_name_update` | Display name aprovado/rejeitado | Notificar |
| `account_update` | Verificação, restrição, banimento, OBA, capacidade | Status geral da WABA |
| `account_review_update` | Status de review da Meta | Dashboard de saúde |
| `business_capability_update` | Tier/throughput mudou | UI de limites |
| `security` | Eventos de segurança (PIN reset, login) | Alertas |
| `business_status_update` | Status do business portfolio | Compliance |
| `message_echoes` | Mensagens enviadas vinda de outras integrações | Multi-app coexistence |
| `flows` | Status de Flow (publicado/rejeitado/etc) | Sync de flows |
| `calls` | Eventos de WhatsApp Business Calling | Telefonia |

Para **Coexistence** (cliente com app WhatsApp Business + Cloud API):

| Field | Disparado por |
|---|---|
| `smb_message_echoes` | Mensagens enviadas pelo cliente diretamente do app móvel |
| `smb_app_state_sync` | Mudanças de contatos no app móvel |
| `history` | Mensagens passadas que o cliente compartilhou no onboarding |

## Validação HMAC SHA-256 (não-negociável)

Toda request POST traz header `X-Hub-Signature-256: sha256=<hex>`. Você **deve** validar antes de qualquer side-effect, com:

1. **Raw body** em Buffer — não o JSON parseado.
2. App Secret (não Verify Token).
3. Comparação **timing-safe** (`crypto.timingSafeEqual`).

```typescript
import { createHmac, timingSafeEqual } from 'node:crypto';

export function verifyMetaSignature(
  rawBody: Buffer,
  signatureHeader: string | undefined,
  appSecret: string,
): boolean {
  if (!signatureHeader?.startsWith('sha256=')) return false;
  const expected = createHmac('sha256', appSecret).update(rawBody).digest('hex');
  const received = signatureHeader.slice('sha256='.length);
  if (expected.length !== received.length) return false;
  return timingSafeEqual(Buffer.from(expected, 'hex'), Buffer.from(received, 'hex'));
}
```

### Configurar Express para preservar rawBody

```typescript
import express from 'express';

const app = express();
app.use(
  '/webhooks/whatsapp',
  express.json({
    verify: (req: any, _res, buf) => {
      req.rawBody = buf;
    },
  }),
);
```

### Configurar Fastify

```typescript
import Fastify from 'fastify';

const fastify = Fastify();
fastify.addContentTypeParser(
  'application/json',
  { parseAs: 'buffer' },
  (_req, body, done) => {
    try {
      const json = JSON.parse((body as Buffer).toString());
      done(null, { json, raw: body });
    } catch (err) {
      done(err as Error);
    }
  },
);
```

Pronto pra usar em `scripts/verify_hmac.ts` desta skill.

## Estrutura padrão do payload

```json
{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "<WABA_ID>",
      "time": 1714947600,
      "changes": [
        {
          "value": { /* específico do field */ },
          "field": "messages"
        }
      ]
    }
  ]
}
```

Cada `entry` corresponde a uma WABA. Cada `change` é um evento. Múltiplas mudanças podem chegar no mesmo POST — iterar.

## Exemplos canônicos por field

### `messages` — mensagem recebida (texto)

```json
{
  "field": "messages",
  "value": {
    "messaging_product": "whatsapp",
    "metadata": {
      "display_phone_number": "551130000000",
      "phone_number_id": "<PHONE_NUMBER_ID>"
    },
    "contacts": [{
      "profile": { "name": "Felipe" },
      "wa_id": "5511999998888"
    }],
    "messages": [{
      "from": "5511999998888",
      "id": "wamid.HBg...",
      "timestamp": "1714947600",
      "type": "text",
      "text": { "body": "Olá" }
    }]
  }
}
```

### `messages` — status de mensagem enviada

```json
{
  "field": "messages",
  "value": {
    "messaging_product": "whatsapp",
    "metadata": { /* ... */ },
    "statuses": [{
      "id": "wamid.HBg...",
      "status": "delivered",  // sent | delivered | read | failed
      "timestamp": "1714947610",
      "recipient_id": "5511999998888",
      "conversation": {
        "id": "<CONV_ID>",
        "expiration_timestamp": "1715034000",
        "origin": { "type": "marketing" }  // marketing | utility | authentication | service
      },
      "pricing": {
        "billable": true,
        "pricing_model": "CBP",
        "category": "marketing"
      }
    }]
  }
}
```

### `message_template_status_update`

```json
{
  "field": "message_template_status_update",
  "value": {
    "event": "APPROVED",
    "message_template_id": 1234567890,
    "message_template_name": "agendamento_confirmacao",
    "message_template_language": "pt_BR",
    "reason": null,
    "disable_info": null,
    "other_info": null
  }
}
```

Eventos: `APPROVED`, `REJECTED`, `PENDING_DELETION`, `DISABLED`, `PAUSED`, `IN_APPEAL`, `LIMIT_EXCEEDED`, `FLAGGED`. `reason` traz string com motivo quando rejeitado.

### `phone_number_quality_update`

```json
{
  "field": "phone_number_quality_update",
  "value": {
    "display_phone_number": "551130000000",
    "event": "FLAGGED",
    "current_limit": "TIER_1K"
  }
}
```

### `account_update`

```json
{
  "field": "account_update",
  "value": {
    "phone_number": "551130000000",
    "event": "VERIFIED_ACCOUNT",
    "ban_info": null,
    "violation_info": null,
    "restriction_info": null,
    "auth_international_rate_eligibility": null
  }
}
```

Eventos comuns: `VERIFIED_ACCOUNT`, `ACCOUNT_RESTORED`, `ACCOUNT_DELETED`, `PHONE_NUMBER_FLAGGED`, `PARTNER_ADDED`, `PARTNER_REMOVED`, `BUSINESS_VERIFICATION_STATUS_UPDATE`.

## Idempotência e enfileiramento

Cada POST pode trazer eventos repetidos por retry. Implementar:

```typescript
// Antes de processar
const idempotencyKey = createHash('sha256')
  .update(rawBody)
  .digest('hex');

const exists = await db.webhook_events.findOne({ idempotency_key: idempotencyKey });
if (exists) return res.sendStatus(200);

await db.webhook_events.insert({
  waba_id,
  idempotency_key: idempotencyKey,
  raw_payload: rawBody.toString('utf8'),
  status: 'received',
});

// Enfileirar para o worker
await queue.add('whatsapp_webhook', { event_id: ... });

res.sendStatus(200);
```

Worker (BullMQ/SQS/Inngest) pega o `event_id`, processa por field, marca como `done` ou `failed`.

## Roteamento por field

```typescript
const handlers: Record<string, (waba_id: string, value: any) => Promise<void>> = {
  messages: handleMessages,
  message_template_status_update: handleTemplateStatusUpdate,
  message_template_quality_update: handleTemplateQualityUpdate,
  template_category_update: handleTemplateCategoryUpdate,
  phone_number_quality_update: handlePhoneNumberQualityUpdate,
  phone_number_name_update: handlePhoneNumberNameUpdate,
  account_update: handleAccountUpdate,
  // ... etc
};

for (const entry of payload.entry) {
  const waba_id = entry.id;
  for (const change of entry.changes) {
    const handler = handlers[change.field];
    if (handler) await handler(waba_id, change.value);
    else logger.warn({ field: change.field }, 'Unhandled webhook field');
  }
}
```

## Reentrega manual (debug)

Para investigação, manter no painel admin do FGB um botão "Reprocessar evento" que pega o `raw_payload` do banco e re-injeta no worker. Útil quando um bug em `handleX` derrubou eventos antigos.

## Erros e retry da Meta

A Meta retenta com backoff por **24 horas** se você não responder 200. Após isso, desiste e marca o webhook como falho no Dashboard. Cliente perde o evento permanentemente.

Se sua API ficar fora por 6h, espere uma rajada de retries quando voltar. Worker precisa aguentar.

## Checklist de produção (webhooks)

- [ ] HTTPS válido na callback URL.
- [ ] Verify token em env, não hardcoded.
- [ ] App Secret em KMS/secret manager.
- [ ] Middleware HMAC com `timingSafeEqual` e rawBody preservado.
- [ ] Resposta 200 em <500ms (medir P99).
- [ ] Enfileiramento async (BullMQ, SQS, etc).
- [ ] Tabela `webhook_events` append-only com idempotency_key SHA-256 do rawBody.
- [ ] Roteador por field com handlers separados.
- [ ] Subscribe automático após Embedded Signup.
- [ ] Health check do endpoint (alerta se POST não chega há mais de N horas).
- [ ] Botão de reprocessamento no admin.
- [ ] Logs estruturados com `waba_id`, `field`, `idempotency_key`, `x-fb-trace-id`.
