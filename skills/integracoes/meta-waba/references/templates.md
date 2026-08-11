# Message Templates — CRUD completo

## Modelo de domínio

```typescript
type TemplateCategory = 'MARKETING' | 'UTILITY' | 'AUTHENTICATION';
// SERVICE não é uma categoria de template — é uma categoria de conversação (resposta dentro da janela 24h, sem template).

type TemplateStatus =
  | 'APPROVED'
  | 'IN_APPEAL'
  | 'PENDING'
  | 'REJECTED'
  | 'PENDING_DELETION'
  | 'DELETED'
  | 'DISABLED'
  | 'PAUSED'         // qualidade RED por dias seguidos
  | 'LIMIT_EXCEEDED'; // template enviado em excesso vs qualidade

type ParameterFormat = 'POSITIONAL' | 'NAMED';

type ComponentType =
  | 'HEADER'
  | 'BODY'
  | 'FOOTER'
  | 'BUTTONS'
  | 'CAROUSEL'
  | 'LIMITED_TIME_OFFER';

type HeaderFormat = 'TEXT' | 'IMAGE' | 'VIDEO' | 'DOCUMENT' | 'LOCATION';

type ButtonType =
  | 'QUICK_REPLY'
  | 'URL'
  | 'PHONE_NUMBER'
  | 'COPY_CODE'        // marketing — código promocional
  | 'OTP'              // authentication
  | 'FLOW'             // dispara WhatsApp Flow
  | 'CATALOG'          // commerce
  | 'MPM'              // multi-product message
  | 'SPM'              // single-product message
  | 'VOICE_CALL';      // calls (recente)
```

## Categorias e como a Meta classifica

| Categoria | Quando usar | Exemplos | Preço relativo |
|---|---|---|---|
| **MARKETING** | Promoção, anúncio, retargeting | "10% off em maio", lançamento, carrinho abandonado | Mais caro |
| **UTILITY** | Triggered por ação do usuário, transacional | Pedido enviado, lembrete de consulta, alerta de saldo | Médio |
| **AUTHENTICATION** | OTP, verificação | "Seu código é 123456" | Mais barato (regulado) |

> **Regra crítica:** se um template UTILITY contém qualquer pitch de venda, a Meta reclassifica automaticamente para MARKETING e você paga a diferença. O webhook `template_category_update` avisa. Inversamente: a partir de abril/2025, `allow_category_change` é o default — não precisa mais setar manualmente.

> **Exclusão MARKETING-US:** desde 1º/abril/2025 e seguindo em maio/2026, mensagens de **marketing** para números **+1 (US)** **não são entregues**. Validar no front e bloquear envio.

## Listar templates

```http
GET https://graph.facebook.com/v23.0/<WABA_ID>/message_templates
  ?fields=id,name,language,status,category,correct_category,sub_category,
          components,quality_score,previous_category,parameter_format,
          message_send_ttl_seconds,rejected_reason
  &limit=200
  &after=<CURSOR>
Authorization: Bearer <TOKEN>
```

Paginação por cursor (`paging.cursors.after`). Para sync incremental, salvar `id` + `updated_at` localmente e fazer GET dirigido por filtro `name=...&language=...` quando precisar atualizar um específico.

## Criar template — texto puro com variáveis nomeadas

```http
POST https://graph.facebook.com/v23.0/<WABA_ID>/message_templates
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "name": "agendamento_confirmacao",
  "category": "UTILITY",
  "language": "pt_BR",
  "parameter_format": "NAMED",
  "components": [
    {
      "type": "HEADER",
      "format": "TEXT",
      "text": "Agendamento confirmado"
    },
    {
      "type": "BODY",
      "text": "Olá {{nome}}, sua consulta com {{profissional}} está confirmada para {{data}} às {{hora}}.",
      "example": {
        "body_text_named_params": [
          { "param_name": "nome", "example": "Felipe" },
          { "param_name": "profissional", "example": "Dra. Ana" },
          { "param_name": "data", "example": "07/05/2026" },
          { "param_name": "hora", "example": "14:30" }
        ]
      }
    },
    { "type": "FOOTER", "text": "Provider One" },
    {
      "type": "BUTTONS",
      "buttons": [
        { "type": "QUICK_REPLY", "text": "Confirmar" },
        { "type": "QUICK_REPLY", "text": "Reagendar" },
        { "type": "PHONE_NUMBER", "text": "Ligar", "phone_number": "+551130000000" }
      ]
    }
  ]
}
```

Resposta:
```json
{
  "id": "1234567890",
  "status": "PENDING",
  "category": "UTILITY"
}
```

> Use `parameter_format: "NAMED"` em vez de `POSITIONAL` sempre que possível — facilita renderização e diminui risco de mismatch quando o time edita o template.

## Criar template com **HEADER de mídia** (imagem, vídeo, documento)

> Este é o caminho que o usuário precisa quando quer template com vídeo. Sem o `header_handle` correto, a Meta rejeita imediatamente.

### Fluxo em 2 etapas

**Etapa A** — Subir o vídeo de exemplo via Resumable Upload API (ver `references/media-resumable-upload.md`). Resultado: `header_handle` (string opaca tipo `4::aW1hZ2UvanBlZw==:ARZ...`).

**Etapa B** — Criar o template referenciando o handle:

```http
POST https://graph.facebook.com/v23.0/<WABA_ID>/message_templates
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "name": "demo_produto_video",
  "category": "MARKETING",
  "language": "pt_BR",
  "parameter_format": "POSITIONAL",
  "components": [
    {
      "type": "HEADER",
      "format": "VIDEO",
      "example": {
        "header_handle": ["4::aW1hZ2UvanBlZw==:ARZ..."]
      }
    },
    {
      "type": "BODY",
      "text": "Olá {{1}}, confira nosso novo produto. Use o cupom {{2}} para 10% off.",
      "example": {
        "body_text": [["Felipe", "MAIO10"]]
      }
    },
    { "type": "FOOTER", "text": "Oferta válida até 31/05" },
    {
      "type": "BUTTONS",
      "buttons": [
        { "type": "URL", "text": "Comprar agora", "url": "https://fgb.com.br/produto?ref={{1}}", "example": ["whatsapp"] },
        { "type": "COPY_CODE", "example": "MAIO10" }
      ]
    }
  ]
}
```

### Especificação de mídia para `header_handle`

| Format | Mime aceitos | Tamanho máx | Notas |
|---|---|---|---|
| `IMAGE` | `image/jpeg`, `image/png` | 5 MB | Aspecto 1.91:1 ideal |
| `VIDEO` | `video/mp4`, `video/3gp` | 16 MB | **Codec H.264 + AAC**. VP8/VP9 não funciona |
| `DOCUMENT` | `application/pdf` | 100 MB | Apenas PDF |

> Frame rate de vídeo: ≤30fps. Se o vídeo do cliente vier em 60fps, recodificar antes do upload.

## Templates de Authentication (com OTP)

```http
POST https://graph.facebook.com/v23.0/<WABA_ID>/message_templates
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "name": "otp_login",
  "category": "AUTHENTICATION",
  "language": "pt_BR",
  "components": [
    {
      "type": "BODY",
      "add_security_recommendation": true
    },
    {
      "type": "FOOTER",
      "code_expiration_minutes": 10
    },
    {
      "type": "BUTTONS",
      "buttons": [
        {
          "type": "OTP",
          "otp_type": "COPY_CODE",
          "text": "Copiar código"
        }
      ]
    }
  ]
}
```

### Modos de OTP

| `otp_type` | UX | Pré-requisitos |
|---|---|---|
| `COPY_CODE` | Botão "copiar" — usuário cola manualmente | Nenhum |
| `ONE_TAP` | App alvo (Android) preenche o campo automaticamente | `package_name` + `signature_hash` do APK |
| `ZERO_TAP` | Código entregue direto ao app, usuário não toca em nada | Habilitação Meta + integração Google Play Services |

### Restrições de Authentication

- `body.text` **não é editável** — sempre é "{{1}} is your verification code." em inglês ou equivalente local. Variantes via `add_security_recommendation` e `code_expiration_minutes`.
- Sem URLs, sem mídia, sem emojis.
- Variável OTP limitada a 15 caracteres.

## Carousel templates (até 10 cards)

```http
POST https://graph.facebook.com/v23.0/<WABA_ID>/message_templates
{
  "name": "produtos_destaque",
  "category": "MARKETING",
  "language": "pt_BR",
  "components": [
    {
      "type": "BODY",
      "text": "Olá {{1}}, confira nossos destaques!",
      "example": { "body_text": [["Felipe"]] }
    },
    {
      "type": "CAROUSEL",
      "cards": [
        {
          "components": [
            { "type": "HEADER", "format": "IMAGE", "example": { "header_handle": ["<HANDLE_1>"] } },
            { "type": "BODY", "text": "Tênis de corrida — {{1}}", "example": { "body_text": [["R$ 299"]] } },
            { "type": "BUTTONS", "buttons": [
              { "type": "QUICK_REPLY", "text": "Quero esse" },
              { "type": "URL", "text": "Ver detalhes", "url": "https://fgb.com.br/p/1" }
            ]}
          ]
        }
        // ... mais cards (até 10)
      ]
    }
  ]
}
```

Cada card pode ter HEADER (imagem ou vídeo), BODY e BUTTONS próprios. Todos os cards precisam ter o **mesmo conjunto de tipos de componentes** — não pode um card ter botão URL e outro só QUICK_REPLY, por exemplo.

## Limited-Time Offer templates

```http
{
  "type": "LIMITED_TIME_OFFER",
  "limited_time_offer": {
    "text": "Oferta termina em",
    "has_expiration": true
  }
}
```

Usado em conjunto com botão `COPY_CODE`. A expiração real vai no envio (`offer_expiration_time_ms`).

## Flow templates

```http
{
  "type": "BUTTONS",
  "buttons": [
    {
      "type": "FLOW",
      "text": "Agendar consulta",
      "flow_id": "<FLOW_ID>",
      "navigate_screen": "WELCOME_SCREEN",
      "flow_action": "navigate"
    }
  ]
}
```

`flow_action` pode ser `navigate` (Flow estático) ou `data_exchange` (Flow dinâmico que chama o endpoint do FGB). Ver `references/flows.md`.

## Catalog / MPM / SPM (commerce)

Pré-requisito: catálogo conectado em `whatsapp_commerce_settings` (`references/qr-codes-and-misc.md`).

```http
# Botão de catálogo geral
{ "type": "BUTTONS", "buttons": [{ "type": "CATALOG", "text": "Ver catálogo" }] }

# Single product message — destaca 1 produto
{ "type": "BUTTONS", "buttons": [{ "type": "SPM", "text": "Comprar" }] }

# Multi-product — exige body especial
# Ver doc oficial de commerce templates
```

## Atualizar template

```http
POST https://graph.facebook.com/v23.0/<TEMPLATE_ID>
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "category": "UTILITY",
  "components": [ /* nova estrutura */ ]
}
```

Restrições:
- **Não dá para mudar `name`, `language`, ou `parameter_format`.** Para isso, criar template novo.
- Edições só funcionam em templates **APPROVED**.
- Limite de **10 edições/mês** por template.
- Edição re-dispara revisão (pode voltar a `PENDING`).

## Apelar de rejeição

Se o status virou `REJECTED` e você acha que foi engano:

```http
POST https://graph.facebook.com/v23.0/<TEMPLATE_ID>/appeal
Authorization: Bearer <TOKEN>
Content-Type: application/json

{ "appeal_reason": "O template é uma confirmação de agendamento médico, não promocional." }
```

Janela de 60 dias após rejeição.

## Deletar template

```http
# Deletar apenas a versão de UM idioma (recomendado)
DELETE https://graph.facebook.com/v23.0/<WABA_ID>/message_templates
  ?hsm_id=<TEMPLATE_ID>&name=<NAME>

# Deletar todas as versões com aquele nome (perigoso)
DELETE https://graph.facebook.com/v23.0/<WABA_ID>/message_templates
  ?name=<NAME>
```

## Library Templates (pré-aprovados pela Meta)

Catálogo curado pela Meta de templates UTILITY e AUTHENTICATION já aprovados — não passam por revisão, basta criar com seus parâmetros.

```http
# Listar disponíveis
GET https://graph.facebook.com/v23.0/<WABA_ID>/message_template_library
  ?industry=HEALTHCARE
  &language=pt_BR
  &topic=APPOINTMENT_REMINDER

# Criar a partir da biblioteca
POST https://graph.facebook.com/v23.0/<WABA_ID>/message_templates
{
  "name": "lembrete_consulta_emnh",
  "language": "pt_BR",
  "library_template_name": "appointment_reminder_2",
  "library_template_button_inputs": [
    {
      "type": "URL",
      "url": { "base_url": "https://fgb.com.br/consulta/{{1}}" }
    }
  ]
}
```

> Library templates **não são editáveis**. Se o cliente quiser personalizar muito, vale criar template próprio.

## Quality score e pausas automáticas

| `quality_score.score` | Comportamento |
|---|---|
| `GREEN` | Saudável |
| `YELLOW` | Recebeu feedback negativo recente — monitore |
| `RED` | Em risco — Meta pode pausar (`status: PAUSED`) por 1h, 6h, 24h, ou desabilitar (`DISABLED`) |
| `UNKNOWN` | Sem dados ainda |

Hierarquia de pausas:
1. Primeira vez `RED` → pausa de 1h.
2. Reincidência → 6h.
3. Reincidência → 24h.
4. Persistência → `DISABLED` (template fica inutilizável, criar novo).

## Template pacing (entrega gradual)

Templates novos sem histórico são entregues a um **grupo pequeno (~1.000)** primeiro. Se a qualidade for boa, escala para todos. Se for ruim, freia.

Implicações:
- Sua primeira campanha massiva pode demorar 24–72h para escalar.
- Avisar isso no painel ao publicar template novo.
- Não interpretar "demorou para entregar todos" como bug.

## Webhooks importantes

- `message_template_status_update` — `event` em `[APPROVED, REJECTED, PENDING_DELETION, DISABLED, PAUSED, IN_APPEAL, FLAGGED, LIMIT_EXCEEDED]`
- `message_template_quality_update` — score mudou
- `template_category_update` — Meta reclassificou (ex.: UTILITY→MARKETING)
- `message_template_components_update` — variáveis foram detectadas/atualizadas

## Validador local antes de submeter (recomendado)

Implemente checks **antes** de chamar a API para falhar rápido:

- [ ] `name` em `[a-z0-9_]{1,512}`.
- [ ] `language` em formato `xx_XX` (`pt_BR`, `en_US`, `es_MX`).
- [ ] BODY ≤ 1024 chars.
- [ ] HEADER text ≤ 60 chars.
- [ ] FOOTER ≤ 60 chars.
- [ ] Variáveis em sequência (`{{1}}, {{2}}, {{3}}`) sem pular números.
- [ ] Toda variável tem `example`.
- [ ] AUTHENTICATION sem URL/mídia/emoji.
- [ ] AUTHENTICATION variável OTP ≤ 15 chars.
- [ ] Botões: máximo 3 QUICK_REPLY, máximo 2 URL, máximo 1 PHONE_NUMBER, máximo 1 COPY_CODE, máximo 1 OTP, mix limitado.
- [ ] Carousel: 1–10 cards, todos com mesma estrutura.
- [ ] Mídia upload com mime/tamanho válidos.

## Limite de criação

**100 templates por hora por WABA.** Se você está migrando muitos templates de uma vez, escalonar com `await sleep(36s)` entre criações.

## Checklist de produção (templates)

- [ ] Editor visual com preview WhatsApp-like (ver `assets/template_examples.json`).
- [ ] Validador local executando antes de cada POST.
- [ ] Resumable Upload integrado para mídia em headers.
- [ ] Listener dos 4 webhooks acima.
- [ ] Histórico de versões/status por template.
- [ ] Botão "duplicar" que cria com novo nome mantendo estrutura.
- [ ] Filtros de listagem por status/categoria/quality_score.
- [ ] Bloqueio de envio MARKETING para `+1`.
- [ ] Aviso de template pacing ao publicar.
- [ ] Throttling de 100 templates/hora/WABA.
