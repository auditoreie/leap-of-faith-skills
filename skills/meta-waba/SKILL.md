---
name: meta-waba
description: Especialista em WhatsApp Business Platform (Meta Cloud API, Graph API, WABA). Cobre Embedded Signup e BISU/Tech Provider, CRUD de message templates incluindo header de vídeo via Resumable Upload, ciclo de vida de números (request_code/verify_code/register, PIN 2FA, display name), webhooks com HMAC SHA-256, QR codes, analytics (account/conversation/template/pricing), WhatsApp Flows com endpoint criptografado, Conversational Components, Block User API, business profile, commerce, e códigos de erro da Meta. Use sempre que o usuário mencionar WhatsApp Business API, WABA, Cloud API, whatsapp_business_management, message template, registrar número WhatsApp, Embedded Signup, Tech Provider, BSP, webhook WhatsApp, Resumable Upload, header_handle, ou endpoint de graph.facebook.com — mesmo quando ele descrever o problema informalmente (template rejeitado, número não registra, vídeo não sobe, webhook não chega) desde que o contexto seja integração com a plataforma WhatsApp Business da Meta.
---

# Meta WABA — WhatsApp Business Platform

Especialista em **WhatsApp Business Platform** (Cloud API). Trate como referência de produção para construir, depurar e estender integrações que usam `graph.facebook.com` e a permissão `whatsapp_business_management`.

## Quando usar esta skill

Triggers explícitos: o usuário cita WABA, Cloud API, Graph API do WhatsApp, message template, Embedded Signup, Tech Provider, BSP, Resumable Upload, header_handle, ou um endpoint do tipo `graph.facebook.com/<versão>/...`.

Triggers implícitos (igualmente válidos): o usuário descreve um sintoma da plataforma sem nomear ("template foi rejeitado", "número não consegue registrar", "webhook não chega", "PIN não aceita", "vídeo não sobe no template"), pergunta como cobrar pelo serviço (categorias de mensagem), ou está implementando funcionalidades que só existem nessa plataforma (24-hour window, quality rating, OBA, identity change check).

Pular esta skill apenas quando: a tarefa for sobre o app **WhatsApp Business** (não a Platform/API), sobre a versão consumer do WhatsApp, ou for um chat genérico que apenas menciona WhatsApp en passant.

## Estado da arte (referência rápida — maio/2026)

- **On-Premises API foi descontinuada em 23/10/2025.** Tudo em 2026 é Cloud API. Se alguém ainda fala em rodar Docker da Meta, está com informação obsoleta.
- **Versão da Graph API alvo:** `v23.0`. Sempre parametrizar `API_VERSION` como variável — quando a Meta lançar `v24.0`, basta trocar num lugar.
- **Cobrança per-message** desde julho/2025 (não mais por janela de 24h para templates marketing/utility). Janela de 24h ainda existe para a regra de "mensagem livre vs template".
- **Marketing templates para números US** estão pausados desde abril/2025 e seguem pausados em 2026. Validar `+1` no front e bloquear envio antes de chamar a API.
- **BSUID (Business-Scoped User ID)** está em rollout em 2026 — usuários podem ocultar o telefone. Persistir BSUID junto com o telefone para não quebrar identificação.
- **Throughput padrão:** 80 msg/s por número, com upgrade automático para WABAs ativas.
- **Limite de criação de templates:** 100 por hora por WABA.
- **Limite de WABAs:** 20 por Business Manager verificado / 1000 com OBA (Official Business Account).

## Princípios não-negociáveis

1. **Token nunca em query string.** Sempre header `Authorization: Bearer <TOKEN>` (com uma exceção: Resumable Upload usa `Authorization: OAuth <TOKEN>` na etapa de bytes — anomalia conhecida da API).
2. **Webhooks são fonte da verdade** para status de templates, números, qualidade e categorização. Polling é antipattern.
3. **Validar HMAC** (`X-Hub-Signature-256`) em **todo** webhook, com `timingSafeEqual` sobre o `rawBody` Buffer (não o JSON parseado).
4. **Idempotência** em qualquer criação de recurso — antes de tentar criar, verificar se já existe (template homônimo, número já adicionado à WABA).
5. **Retry com backoff exponencial e jitter** somente para `429` e `5xx`. Nunca em `4xx` (exceto `429`).
6. **Logs nunca contêm token em claro** — usar redaction explícita.
7. **Multi-tenant desde o dia zero** — todo recurso é escopado por `cliente_id` + `waba_id` + `phone_number_id`.

## Roteamento — onde encontrar o que

A documentação está fatiada por domínio. Carregue **apenas o reference que a tarefa exige** — ler tudo é desperdício de contexto.

| Tarefa do usuário | Carregar |
|---|---|
| Conectar conta WhatsApp do cliente, virar Tech Provider, trocar `code` por token, gerenciar tokens, App Review | `references/auth-and-tokens.md` |
| Adicionar/registrar/deletar número, mexer com display name, PIN, throughput, OBA, identity change | `references/phone-numbers.md` |
| Criar/listar/editar/deletar template, qualquer template type (texto, mídia, OTP, carousel, LTO, MPM, Flow), Library Templates | `references/templates.md` |
| Subir vídeo/imagem/PDF para usar em template ou foto de perfil | `references/media-resumable-upload.md` |
| Configurar webhook, assinar/desassinar WABA, validar HMAC, processar payloads | `references/webhooks.md` |
| Pegar métricas — enviadas/entregues/lidas/custo por categoria/por template | `references/analytics.md` |
| Construir/publicar/depreciar Flows, endpoint dinâmico criptografado | `references/flows.md` |
| QR codes, ice breakers/welcome message/commands, bloquear usuário, perfil comercial, commerce settings | `references/qr-codes-and-misc.md` |
| Decifrar erro `{"error": {...}}` que voltou da Meta | `references/error-codes.md` |

## Scripts utilitários prontos para uso

Em `scripts/` há código TypeScript de produção que você pode copiar direto para o projeto do usuário. Eles encapsulam padrões corretos (auth, retry, HMAC, chunking de upload):

- **`meta_graph_client.ts`** — Cliente HTTP base com retry exponencial, leitura de rate-limit headers (`x-business-use-case-usage`, `x-app-usage`), e mapeamento de erros para `MetaApiError` tipado. Use como fundação de qualquer módulo.
- **`verify_hmac.ts`** — Middleware Express/Fastify que valida `X-Hub-Signature-256` corretamente (timing-safe + rawBody preservado). Inclui exemplo de configuração para os dois frameworks.
- **`resumable_upload.ts`** — Cliente das 3 etapas da Resumable Upload API com chunking, retry pelo `file_offset` atual, e cache por SHA-256 do arquivo (evita reupload do mesmo vídeo).

Quando o usuário pedir implementação dessas peças, **sugira esses scripts antes de gerar código novo do zero** — são versões já validadas contra a API.

## Estrutura sugerida ao implementar do zero

```
src/whatsapp/
├── auth/                      # tokens, embedded signup, troca de code
├── waba/                      # WhatsApp Business Account
├── phone-numbers/             # ciclo de vida de números
├── templates/                 # CRUD + library templates
├── media/                     # Resumable Upload API
├── flows/                     # WhatsApp Flows
├── qr-codes/                  # message_qrdls
├── conversational-components/
├── block/                     # Block User API
├── webhooks/                  # subscribed_apps + HMAC + receiver
├── analytics/                 # account/conversation/template/pricing
├── business-profile/
├── commerce/                  # commerce_settings
└── shared/                    # http client, errors, rate-limit, logger
```

Esta divisão não é arbitrária — espelha a fronteira de responsabilidade dos endpoints da Meta. Manter é mais fácil porque cada módulo conversa com um conjunto fechado de URLs.

## Persistência mínima sugerida

Tabelas que aparecem em qualquer integração séria. Use isso como ponto de partida na modelagem:

- `clientes` — tenant raiz
- `waba_accounts` — `waba_id`, `cliente_id`, `business_id`, `business_verification_status`, `account_review_status`, `currency`, `country`, `timezone_id`
- `tokens_clientes` — token criptografado em AES-256-GCM (chave em KMS), `tipo` (`system_user` | `bisu`), `escopo`, `expires_at`
- `phone_numbers` — `phone_number_id`, `waba_id`, `display_phone_number`, `verified_name`, `quality_rating`, `messaging_limit_tier`, `throughput`, `status`, `pin_hash`, `pin_set_at`
- `message_templates` — `template_id`, `waba_id`, `name`, `language`, `category`, `correct_category`, `status`, `quality_score`, `components_json`
- `template_media_handles` — `sha256` (PK), `mime`, `header_handle`, `created_at` — cache de Resumable Upload
- `webhook_subscriptions` — `waba_id`, `subscribed_at`, `last_event_at`
- `webhook_events` — append-only, raw payload, status (`received` / `processing` / `done` / `failed`), `idempotency_key`
- `qr_codes` — `code`, `phone_number_id`, `prefilled_message`, `tag` (interno)
- `flows` — `flow_id`, `waba_id`, `status`, `categories_json`, `endpoint_uri`
- `analytics_snapshots` — leitura cacheada de Account/Conversation/Template/Pricing analytics
- `audit_log` — toda ação que muda estado na Meta (quem, quando, request_id `x-fb-trace-id`)

## Sobre exemplos cURL nesta skill

Todos os exemplos `curl` ou JSON nos references são canônicos — copiados/adaptados da documentação oficial da Meta e validados em produção. Quando adaptar para `fetch`/`axios`/`undici`, manter:

- O header `Authorization: Bearer <TOKEN>` (exceto Resumable Upload bytes — `OAuth <TOKEN>`).
- O `Content-Type: application/json` exceto em uploads multipart.
- A versão da Graph API parametrizada.
- O capture do header `x-fb-trace-id` da resposta para correlação em suporte com a Meta.

## Referências canônicas oficiais

Quando a documentação da Meta for atualizada, **estas URLs** são a fonte da verdade — confirmar qualquer endpoint duvidoso aqui antes de implementar:

- Cloud API overview: `https://developers.facebook.com/docs/whatsapp/cloud-api`
- Business Management API: `https://developers.facebook.com/docs/whatsapp/business-management-api`
- Templates: `https://developers.facebook.com/docs/whatsapp/business-management-api/message-templates`
- Phone numbers: `https://developers.facebook.com/docs/whatsapp/business-management-api/phone-numbers`
- Resumable Upload: `https://developers.facebook.com/docs/graph-api/guides/upload`
- Webhooks: `https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks`
- Embedded Signup: `https://developers.facebook.com/docs/whatsapp/embedded-signup`
- Tech Provider Program: `https://developers.facebook.com/docs/whatsapp/solution-providers`
- QR Codes: `https://developers.facebook.com/docs/whatsapp/business-management-api/qr-codes`
- Analytics: `https://developers.facebook.com/docs/whatsapp/business-management-api/analytics`
- Flows: `https://developers.facebook.com/docs/whatsapp/flows`
- Postman collection oficial: `https://www.postman.com/meta/whatsapp-business-platform`
- Códigos de erro: `https://developers.facebook.com/docs/whatsapp/cloud-api/support/error-codes`

Se algo nesta skill divergir do que está nessas URLs hoje, a documentação oficial vence.
