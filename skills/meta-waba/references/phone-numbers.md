# Phone Numbers — Ciclo de vida completo

> Esta é uma das partes mais sensíveis da plataforma. Errar aqui derruba o número do cliente. Confirmações duplas na UI e logs detalhados são obrigatórios.

## Operações de leitura

```http
# Listar números da WABA
GET https://graph.facebook.com/v23.0/<WABA_ID>/phone_numbers
  ?fields=id,verified_name,display_phone_number,quality_rating,
          code_verification_status,name_status,new_name_status,
          certificate,new_certificate,messaging_limit_tier,
          platform_type,throughput,status,account_mode,
          is_official_business_account,is_pin_enabled,
          last_onboarded_time,search_visibility
Authorization: Bearer <TOKEN>

# Detalhes de um número específico
GET https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>
  ?fields=verified_name,display_phone_number,quality_rating,
          messaging_limit_tier,throughput,status,is_pin_enabled,
          is_official_business_account,name_status,platform_type

# Status atual via endpoint dedicado (alternativa)
GET https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/whatsapp_business_to_number_current_status
```

### Significado dos campos críticos

| Campo | Valores | Significado |
|---|---|---|
| `code_verification_status` | `VERIFIED`, `NOT_VERIFIED`, `EXPIRED` | Se o passo `verify_code` foi concluído |
| `name_status` | `APPROVED`, `PENDING_REVIEW`, `DECLINED`, `NONE` | Estado do display name |
| `quality_rating` | `GREEN`, `YELLOW`, `RED`, `UNKNOWN` | Qualidade percebida pelos usuários |
| `messaging_limit_tier` | `TIER_50`, `TIER_250`, `TIER_1K`, `TIER_10K`, `TIER_100K`, `TIER_UNLIMITED` | Quantos contatos únicos por dia |
| `status` | `CONNECTED`, `OFFLINE`, `FLAGGED`, `RESTRICTED`, `PENDING`, `UNVERIFIED`, `DISCONNECTED` | Estado operacional |
| `platform_type` | `CLOUD_API`, `ON_PREMISE`, `NOT_APPLICABLE` | Sempre Cloud em 2026 |
| `throughput.level` | `STANDARD` (80 msg/s), `HIGH` (1000 msg/s) | Capacidade de envio |
| `is_official_business_account` | bool | OBA = selo verde |

## Adicionar e registrar um número (4 passos sequenciais)

### Passo 1 — Criar o número na WABA

```http
POST https://graph.facebook.com/v23.0/<WABA_ID>/phone_numbers
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "cc": "55",
  "phone_number": "11987654321",
  "verified_name": "FGB Consultoria",
  "search_visibility": false
}
```

Resposta:
```json
{ "id": "<PHONE_NUMBER_ID>" }
```

> O `verified_name` precisa seguir as regras de display name (sem caracteres especiais excessivos, refletir o negócio real, idêntico ou similar ao nome verificado no Business Manager). Se a Meta achar que destoa, `name_status` vira `DECLINED` e bloqueia o registro.

### Passo 2 — Solicitar código de verificação

```http
POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/request_code
  ?code_method=SMS
  &language=pt_BR
Authorization: Bearer <TOKEN>
```

Métodos: `SMS` ou `VOICE`. Para números 0800/IVR, **só `VOICE`** funciona, e o IVR precisa estar configurado para encaminhar a chamada internacional para um humano que digite o código (ou criar allowlist dos números de origem da Meta).

### Passo 3 — Verificar o código recebido

```http
POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/verify_code
  ?code=123456
Authorization: Bearer <TOKEN>
```

Resposta:
```json
{ "success": true }
```

### Passo 4 — Registrar na Cloud API com PIN (two-step verification)

```http
POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/register
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "messaging_product": "whatsapp",
  "pin": "654321"
}
```

Resposta:
```json
{ "success": true }
```

> O PIN é obrigatório. Geração: 6 dígitos aleatórios não-sequenciais. Persistir o **hash** (não o PIN em claro) e mostrar uma única vez ao cliente para fins de auditoria. **Não é possível desabilitar 2FA via API** — só sobrescrever (ver §Two-step verification).

### Erros mais comuns no fluxo dos 4 passos

| Erro | Onde aparece | Causa |
|---|---|---|
| `code 133005 Invalid PIN` | Passo 4 | PIN não tem 6 dígitos ou contém caracteres não numéricos |
| `code 133006 Phone number re-verification needed` | Passo 4 | Verificação expirou — refazer passo 2/3 |
| `code 133008 Too many attempts` | Passo 4 | Tentativas demais com PIN errado — esperar 12h |
| `code 133010 Phone number not registered` | Send messages | Esqueceu o passo 4 |
| `code 100 phone_number invalid` | Passo 1 | Número já em outra WABA, ou no app WhatsApp consumer |
| `code 1006 Two factor verification not active` | Send messages | Tentou enviar antes de completar registro |

## Display name — atualização e reaprovação

Display name aparece no topo do chat e na lista de contatos. Mudar exige aprovação Meta (até 48h).

### Solicitar novo display name

```http
POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>
Authorization: Bearer <TOKEN>
Content-Type: application/json

{ "verified_name": "Novo Nome" }
```

Após isso:
- `new_name_status` vira `PENDING_REVIEW`.
- Webhook `phone_number_name_update` vai chegar com aprovação/rejeição.
- Se aprovado, `verified_name` é atualizado automaticamente.

### Regras de display name (resumo das diretrizes Meta)

- Refletir o negócio. "Suporte Empresa X" tudo bem; "Atendimento" sozinho geralmente é rejeitado.
- Sem caracteres especiais excessivos, emojis, ou números aleatórios.
- Idioma do mercado-alvo.
- Maiúsculas/minúsculas precisam fazer sentido (não tudo MAIÚSCULO ou tudo minúsculo).
- 3–25 caracteres é a faixa segura.

## Two-step verification (PIN)

### Definir/atualizar PIN

```http
POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>
Authorization: Bearer <TOKEN>
Content-Type: application/json

{ "pin": "654321" }
```

> **Não dá para desabilitar 2FA pela API.** Para "trocar" o PIN, basta sobrescrever. Se o cliente perdeu o PIN e a WABA está bloqueada, abrir Direct Support ticket — não há API para reset.

## Identity change check (recomendado para fintech, saúde, governo)

Quando ativado, payloads de webhook trazem `identity_key_hash` do usuário. Se o usuário trocar de SIM/aparelho, o hash muda — você detecta possível fraude.

```http
POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/settings
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "identity_change": {
    "enable_identity_key_check": true
  }
}
```

## Throughput e messaging limits

### Tiers (contatos únicos iniciados por dia)

```
TIER_50      → 50 contatos / 24h    (sandbox)
TIER_250     → 250                  (start padrão pós-registro)
TIER_1K      → 1.000
TIER_10K     → 10.000
TIER_100K    → 100.000
TIER_UNLIMITED → ilimitado
```

Promoção entre tiers é automática, baseada em qualidade (`GREEN`/`YELLOW`) + volume. Cair para `RED` por X dias faz regredir.

### Throughput de envio

- `STANDARD` = 80 msg/s por número (default).
- `HIGH` = 1000 msg/s — Meta concede automaticamente para WABAs ativas que sustentam volume sem queda de qualidade.

Não é endpoint de upgrade — é decidido pela Meta. Apenas ler o campo `throughput`.

## Deregister e delete

### Deregister (libera o número da Cloud API, mantém na WABA)

```http
POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/deregister
Authorization: Bearer <TOKEN>
```

Útil quando o cliente quer voltar a usar o número no app WhatsApp Business consumer.

### Delete (remove o número da WABA)

```http
DELETE https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>
Authorization: Bearer <TOKEN>
```

Restrições:
- **Apenas admins do business portfolio** podem deletar.
- **Não pode deletar** se o número enviou mensagens pagas nos últimos 30 dias (espere 30d a partir da última paga).
- Se o número está `CONNECTED`, precisa do PIN da two-step verification para confirmar.

## Solicitar Official Business Account (OBA — selo verde)

Não tem endpoint API para pedir OBA. Processo manual:

1. WhatsApp Manager → Phone numbers → escolher número → "Request green tick".
2. Meta avalia presença de marca: Wikipedia, cobertura de imprensa, perfil verificado em outras redes.
3. Aprovação manual, sem SLA fixo (semanas a meses).

A skill expõe apenas o status via campo `is_official_business_account` no GET phone number.

## Coexistence (uso simultâneo da Cloud API e do app WhatsApp Business)

Recurso novo (2024+) que permite o cliente usar **o mesmo número** no app móvel e na Cloud API. Se o cliente vier desse fluxo:

- Não dá para `deregister` via API se a Coexistence está ativa — o cliente precisa desconectar pelo app (Settings → Account → Business Platform → Disconnect Account).
- Subscribe webhooks adicionais: `history`, `smb_message_echoes`, `smb_app_state_sync`.
- Mensagens enviadas pelo cliente diretamente do app móvel chegam como webhook `smb_message_echoes` (replicar no inbox do FGB).
- Sincronizar contatos do app móvel com:
  ```http
  POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/smb_app_data
  { "messaging_product": "whatsapp", "sync_type": "smb_app_state_sync" }
  ```
  Só pode chamar **uma vez** por onboarding.

## Webhooks importantes para este módulo

- `phone_number_quality_update` — `quality_rating` mudou (`GREEN` → `YELLOW` → `RED`).
- `phone_number_name_update` — display name aprovado/rejeitado.
- `account_update` com `event` em `[VERIFIED_ACCOUNT, ACCOUNT_RESTORED, ACCOUNT_DELETED, PHONE_NUMBER_FLAGGED, PHONE_NUMBER_QUALITY_UPDATE]`.
- `business_capability_update` — mudança de tier ou throughput.

Atualizar status local **imediatamente** ao receber esses eventos. Mostrar no painel com cores (verde/amarelo/vermelho) e tooltip explicando consequência.

## Wizard recomendado de UI (para o painel)

1. **Tela 1** — Inputs: país (DDI), telefone, display name desejado, descrição. Aviso: "número não pode estar em uso no app WhatsApp comum nem em outra WABA".
2. **Tela 2** — Confirmação. Botão "Enviar código por SMS / Voz".
3. **Tela 3** — Input do código de 6 dígitos recebido. Timer de 10min.
4. **Tela 4** — Geração do PIN 2FA. Mostrar uma única vez. Confirmação dupla "Anotei o PIN".
5. **Tela 5** — Sucesso. Subscribe automático. Botão "Enviar mensagem de teste".

Cada tela faz uma chamada da sequência. Se uma falhar, oferecer "tentar novamente" ou "começar do zero" (descarta o `phone_number_id`).

## Checklist de produção (números)

- [ ] Wizard com 4 passos da sequência separados em transações distintas (cada passo é commit).
- [ ] PIN gerado pelo backend, hash armazenado, mostrado uma vez.
- [ ] Botão "Resetar PIN" com confirmação dupla.
- [ ] Botão "Desregistrar" e "Deletar" com confirmação tripla (texto digitado + 2FA do operador FGB).
- [ ] Tela de detalhes com quality_rating, tier, throughput, OBA badge, identity change toggle.
- [ ] Job de sync diário do `phone_numbers` da WABA para detectar drift.
- [ ] Listener dos 4 webhooks acima atualizando status local.
- [ ] Bloqueio de envio para números US quando categoria for marketing (ver `references/templates.md`).
