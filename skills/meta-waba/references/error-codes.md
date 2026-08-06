# Códigos de erro da Meta — referência completa

Toda resposta de erro da Graph API segue:

```json
{
  "error": {
    "message": "(#100) Param ... is invalid",
    "type": "OAuthException",
    "code": 100,
    "error_subcode": 33,
    "error_user_title": "...",
    "error_user_msg": "...",
    "fbtrace_id": "Aabcdef..."
  }
}
```

**Sempre capturar `fbtrace_id`** e logar — ao abrir ticket Meta, é o identificador que acelera o suporte.

## Tabela de códigos por categoria

### Autenticação e permissões (1–199)

| Code | Subcode | Significado | Ação |
|---|---|---|---|
| 4 | — | App rate limit (limite global do app) | Backoff exponencial. Se persistir, pedir aumento via App Dashboard |
| 17 | — | User request limit | Backoff por usuário |
| 32 | — | Page request limit | N/A para WhatsApp |
| 100 | — | Invalid parameter | Validar payload contra schema antes de enviar |
| 102 | — | Session key invalid | Re-auth |
| 190 | — | Access token expired | Renovar (System User) ou re-Embedded Signup (BISU) |
| 200 | — | Permission denied (System User sem acesso ao recurso) | Conceder access via UI ou `assigned_users` |
| 368 | — | Temporarily blocked for policies violation | Crítico — abrir Business Support |
| 506 | — | Duplicate post | Idempotência — verificar antes de criar |

### Cloud API — envio de mensagens (130000–131099)

| Code | Significado | Ação |
|---|---|---|
| 130429 | Rate limit hit (per-message) | Backoff |
| 131000 | Generic user error (Meta side) | Logar, retry |
| 131005 | Access denied (sem acesso ao recurso) | Conferir BISU/System User access |
| 131008 | Required param missing | Bug de payload |
| 131009 | Param value invalid | Validar (ex.: `to` não é número WhatsApp válido) |
| 131016 | Service unavailable | Retry com backoff |
| 131021 | Recipient cannot be sender | Validar que `to` ≠ número da WABA |
| 131026 | Message undeliverable | Esperado: usuário sem WhatsApp ativo, número inválido, bloqueio |
| 131031 | Account locked | Crítico — Business Support |
| 131045 | Sender must be in cart catalog | Setup commerce |
| 131047 | Re-engagement message | Janela 24h fechou — só template |
| 131048 | Spam rate limit | Reduzir cadência. Risco de quality drop |
| 131049 | Per-user marketing template message limit | Usuário recebeu marketing demais — distribuir no tempo |
| 131051 | Unsupported message type | Validar `type` |
| 131052 | Media download error | Mídia que enviou não está acessível pela Meta |
| 131053 | Media upload error | Retry |
| 131056 | Pair (recipient, phone_id) rate limit | Backoff por par |
| 131057 | Account in maintenance | Esperar |

### Templates (132000–132099)

| Code | Significado | Ação |
|---|---|---|
| 132000 | Template param mismatch (número de variáveis errado) | Conferir `parameters` no envio vs `components` na criação |
| 132001 | Template não existe | Resync da WABA — talvez foi deletado |
| 132005 | Template hydration failed (variável vazia/inválida) | Validar valores antes do send |
| 132007 | Template paused devido a quality | Ver `references/templates.md` — esperar despausar (1h/6h/24h) ou criar novo |
| 132012 | Template param format mismatch (named vs positional) | Conferir `parameter_format` |
| 132015 | Template paused | Ver acima |
| 132016 | Template disabled (quality red persistente) | Não há recuperação — criar template novo |
| 132068 | Flow disabled | Republicar Flow ou usar outro |
| 132069 | Flow blocked | Crítico — Flow violou política, abrir suporte |

### Phone Numbers (133000–133099)

| Code | Significado | Ação |
|---|---|---|
| 133000 | Incomplete deregistration | Repetir deregister |
| 133004 | Server temporarily unavailable | Retry |
| 133005 | Two-step verification PIN incorrect | Conferir PIN salvo |
| 133006 | Phone number re-verification needed | Refazer `request_code`/`verify_code` |
| 133008 | Too many 2FA attempts | Esperar 12h |
| 133009 | 2FA PIN guessed too many times | Esperar 1h |
| 133010 | Phone number not registered | Completar passo 4 (`/register`) |
| 1006 | Two factor verification not active | Idem 133010 |

### Business e WABA (80000–80999)

| Code | Significado | Ação |
|---|---|---|
| 80007 | WABA rate limit (200/h sem número, 5000/h com) | Reduzir taxa ou registrar número para subir limite |
| 80008 | Business rate limit (limite por business portfolio) | Backoff por business |
| 80014 | Marketing message daily limit per recipient | Distribuir |

### Webhooks (não numerados, mas comuns)

| Sintoma | Causa | Ação |
|---|---|---|
| Webhook não chega | Esqueceu `subscribed_apps` na WABA | `POST /<WABA_ID>/subscribed_apps` |
| Webhook não chega após adicionar number novo | Subscription é por WABA, não por número | OK — confere se o `field` está inscrito no Dashboard |
| HMAC sempre falha | Está validando contra body parseado, não rawBuffer | Preservar rawBody no middleware |
| HMAC sempre falha (parte 2) | Está usando Verify Token em vez de App Secret | App Secret, não Verify Token |
| Webhook duplicado | Não respondeu 200 em 5s na primeira | Acelerar handler ou enfileirar antes de responder |

## Estratégia de tratamento centralizada

```typescript
class MetaApiError extends Error {
  constructor(
    public readonly code: number,
    public readonly subcode: number | null,
    public readonly type: string,
    public readonly userMessage: string,
    public readonly fbtraceId: string,
    public readonly rawBody: string,
  ) {
    super(`Meta API ${code}/${subcode}: ${userMessage}`);
  }

  static fromResponse(status: number, body: string): MetaApiError {
    try {
      const parsed = JSON.parse(body);
      const e = parsed.error;
      return new MetaApiError(
        e.code,
        e.error_subcode ?? null,
        e.type,
        e.error_user_msg ?? e.message,
        e.fbtrace_id,
        body,
      );
    } catch {
      return new MetaApiError(status, null, 'UnknownError', body.slice(0, 500), '', body);
    }
  }

  /** Erro permanente — nunca retry */
  isPermanent(): boolean {
    return [
      100, 102, 200, 368, 506,
      131008, 131009, 131021, 131045, 131047, 131049, 131051,
      132000, 132005, 132012, 132016,
      133005, 133006, 133010,
    ].includes(this.code);
  }

  /** Pede ação do cliente (re-auth, novo PIN, etc.) */
  requiresUserAction(): boolean {
    return [190, 200, 133006, 133008, 133009, 132016].includes(this.code);
  }

  /** Mensagem amigável em pt-BR para mostrar no painel */
  toUserFriendlyPtBR(): string {
    const map: Record<number, string> = {
      190: 'Sua conexão com a Meta expirou. Reconecte sua conta WhatsApp.',
      200: 'Permissão insuficiente para essa ação. Verifique os acessos no Business Manager.',
      131047: 'A janela de 24h com este contato fechou. Use um template para reabrir a conversa.',
      131049: 'Este contato já recebeu o limite diário de mensagens de marketing. Tente em 24h.',
      132000: 'Variáveis enviadas não correspondem ao template aprovado.',
      132007: 'Template está temporariamente pausado pela Meta devido à qualidade. Aguarde algumas horas.',
      132016: 'Template foi desativado pela Meta. Crie um novo template.',
      133005: 'PIN de verificação em duas etapas incorreto.',
      133010: 'Número não está registrado na Cloud API. Complete o registro.',
      80007: 'Limite de chamadas para esta conta atingido. Aguarde alguns minutos.',
    };
    return map[this.code] ?? `Erro Meta (${this.code}): ${this.userMessage}`;
  }
}
```

## Headers de rate limit a monitorar

A Meta retorna em todo response:

- `X-Business-Use-Case-Usage` — uso por par (business, use case)
- `X-App-Usage` — uso global do app
- `X-Ad-Account-Usage` — N/A para WhatsApp

Estrutura:
```
X-App-Usage: {"call_count":50,"total_cputime":25,"total_time":30}
```

Quando qualquer dos três passar de **80%**, pausar chamadas voluntariamente. Implementar token bucket interno baseado nesses headers.

## Erros que NUNCA devem retentar automaticamente

- `100` (param inválido) — bug, não vai resolver
- `102` (session) — re-auth necessário
- `200` (permission denied) — re-auth ou conceder access
- `368` (policy violation) — escalonar
- `131009` (param invalid) — bug
- `132000` (template mismatch) — bug
- Qualquer `4xx` exceto `429`

## Erros que sempre podem retentar com backoff

- `1` (unknown error)
- `2` (service)
- `4`, `17`, `32`, `80007`, `80008`, `130429` (rate limits)
- `5xx`
- Erros de rede (ECONNRESET, ETIMEDOUT)

Backoff sugerido: `min(60s, 2^n + jitter)` com `n` = nº de tentativas, máximo 5 retries.
