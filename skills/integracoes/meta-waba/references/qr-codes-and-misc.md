# QR Codes, Conversational Components, Block User, Business Profile, Commerce

Endpoints menores agrupados num só reference. Use o índice abaixo para pular direto.

- [QR Codes (`message_qrdls`)](#qr-codes-message_qrdls)
- [Conversational Components (welcome / ice breakers / commands)](#conversational-components)
- [Block User API](#block-user-api)
- [Business Profile](#business-profile)
- [Commerce Settings (catálogo)](#commerce-settings-catálogo)

---

## QR Codes (`message_qrdls`)

QR codes pré-preenchem mensagem e, ao ser escaneados, abrem chat com o número da empresa. Cada QR tem um `code` único usado no deep link `wa.me/message/<CODE>`.

### Criar

```http
POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/message_qrdls
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "prefilled_message": "Olá, vim pelo flyer da campanha de Maio!",
  "generate_qr_image": "PNG"
}
```

`generate_qr_image`: `PNG` ou `SVG`. Se omitido, retorna só o `code` sem imagem renderizada.

Resposta:
```json
{
  "code": "4O4YGZEG3RIVE1",
  "prefilled_message": "Olá, vim pelo flyer da campanha de Maio!",
  "deep_link_url": "https://wa.me/message/4O4YGZEG3RIVE1",
  "qr_image_url": "https://scontent.xx.fbcdn.net/..."
}
```

> O `qr_image_url` é uma CDN da Meta com expiração curta (horas). Para uso em material impresso, **baixe e armazene** no S3/blob do FGB.

### Listar

```http
GET /<PHONE_NUMBER_ID>/message_qrdls
```

### Atualizar (mudar mensagem pré-preenchida)

```http
POST /<PHONE_NUMBER_ID>/message_qrdls
{
  "code": "4O4YGZEG3RIVE1",
  "prefilled_message": "Nova mensagem"
}
```

> Mudar a mensagem **mantém o mesmo `code`** — útil para QR codes impressos. Se você gerar QR de novo, é outro código, outro material a imprimir.

### Detalhe

```http
GET /<PHONE_NUMBER_ID>/message_qrdls/<CODE>
```

### Deletar

```http
DELETE /<PHONE_NUMBER_ID>/message_qrdls/<CODE>
```

### Boas práticas

- **Tagging interno** — adicionar campo `tag` ou `campaign_name` no FGB (não persistido na Meta) para atribuir scans a campanhas.
- **Sem analytics nativos** — a Meta não conta scans. Para tracking, usar UTM param no `prefilled_message` ou redirector intermediário (e.g., gerar QR para `https://fgb.com.br/wa/<short>` que redireciona para `wa.me/message/<CODE>` registrando o hit).
- **Rotação dinâmica** — para campanhas de longa duração, tem QR genérico que aponta para uma URL FGB que decide para qual número/mensagem mandar (A/B test, geo-routing).

---

## Conversational Components

Recurso 2024+ que aparece quando o usuário abre o chat sem ter conversado antes — Welcome message, Ice Breakers (prompts sugeridos) e Commands (lista tipo `/`).

### Configurar

```http
POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/conversational_automation
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "enable_welcome_message": true,
  "prompts": [
    "Quero agendar uma consulta",
    "Quero remarcar",
    "Falar com atendente"
  ],
  "commands": [
    { "command_name": "agendar", "command_description": "Iniciar novo agendamento" },
    { "command_name": "cancelar", "command_description": "Cancelar consulta" },
    { "command_name": "ajuda", "command_description": "Ver opções" }
  ]
}
```

### Limites

| Campo | Limite |
|---|---|
| `prompts` (ice breakers) | até 4, cada um ≤ 80 chars |
| `commands` | até 30 |
| `command_name` | ≤ 32 chars, sem espaços, lowercase recomendado |
| `command_description` | ≤ 256 chars |

### Ler config atual

```http
GET /<PHONE_NUMBER_ID>?fields=conversational_automation
```

### Welcome message

Quando `enable_welcome_message: true`, ao usuário enviar a primeira mensagem você recebe um webhook `messages` com `referral.welcome_message: true`. Você responde com a mensagem de boas-vindas (livre, dentro da janela de 24h).

### Quando o usuário clica num ice breaker

Chega webhook `messages` normal, mas com `text.body` igual ao texto do prompt. Você reconhece e roteia para o flow correspondente.

### Quando o usuário usa um command

Chega webhook `messages` com `text.body: "/agendar"` (com a barra). Roteador interno deve identificar comandos.

---

## Block User API

Bloqueia usuários abusivos. Lista de bloqueio é por **número de telefone do negócio** (não por WABA).

### Bloquear

```http
POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/block_users
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "block_users": [
    { "user": "5511999998888" },
    { "user": "5511999997777" }
  ]
}
```

`user` é o `wa_id` (número sem `+`).

### Listar

```http
GET /<PHONE_NUMBER_ID>/block_users
```

Retorna paginado.

### Desbloquear

```http
DELETE /<PHONE_NUMBER_ID>/block_users
Authorization: Bearer <TOKEN>
Content-Type: application/json

{ "block_users": [{ "user": "5511999998888" }] }
```

### Comportamento

- Quando bloqueado, **mensagens recebidas desse usuário são descartadas pela Meta** — não chegam como webhook.
- Tentativas de envio para o usuário bloqueado retornam erro.
- O usuário **não é notificado** de que foi bloqueado.

---

## Business Profile

Informações exibidas no perfil do número no WhatsApp (visível ao tocar no nome no chat).

### Ler

```http
GET https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/whatsapp_business_profile
  ?fields=about,address,description,email,profile_picture_url,websites,vertical
Authorization: Bearer <TOKEN>
```

### Atualizar

```http
POST /<PHONE_NUMBER_ID>/whatsapp_business_profile
Content-Type: application/json

{
  "messaging_product": "whatsapp",
  "about": "Texto curto sobre o negócio",
  "address": "Endereço completo",
  "description": "Descrição mais longa do negócio",
  "email": "contato@empresa.com.br",
  "websites": ["https://empresa.com.br", "https://fgb.com.br"],
  "vertical": "PROFESSIONAL_SERVICES",
  "profile_picture_handle": "<HANDLE_DO_RESUMABLE_UPLOAD>"
}
```

### Limites

| Campo | Limite |
|---|---|
| `about` | 139 chars |
| `description` | 512 chars |
| `address` | 256 chars |
| `email` | 128 chars |
| `websites` | até 2 URLs, cada ≤ 256 chars |

### Verticals válidas

```
OTHER, AUTO, BEAUTY, APPAREL, EDU, ENTERTAIN, EVENT_PLAN, FINANCE,
GROCERY, GOVT, HOTEL, HEALTH, NONPROFIT, PROF_SERVICES, RETAIL,
TRAVEL, RESTAURANT, NOT_A_BIZ
```

### Foto de perfil

A foto **só** pode ser definida via `profile_picture_handle` obtido pela Resumable Upload API (`references/media-resumable-upload.md`). Não há suporte a URL direta. Imagem JPG ou PNG, ≤ 5MB.

> Para mostrar a foto atual no painel, usar `profile_picture_url` que vem do GET — é uma URL CDN da Meta com expiração de horas. Cachear baixando para S3/blob.

---

## Commerce Settings (catálogo)

Controla se o número tem catálogo de produtos visível e se o carrinho está habilitado. Pré-requisito para templates `CATALOG`, `MPM`, `SPM`.

### Ler

```http
GET /<PHONE_NUMBER_ID>/whatsapp_commerce_settings
Authorization: Bearer <TOKEN>
```

### Atualizar

```http
POST /<PHONE_NUMBER_ID>/whatsapp_commerce_settings
  ?is_cart_enabled=true
  &is_catalog_visible=true
Authorization: Bearer <TOKEN>
```

### Vincular catálogo do Commerce Manager

O catálogo precisa existir no Commerce Manager primeiro (criação manual no `business.facebook.com/commerce`). Depois:

```http
POST /<WABA_ID>/product_catalogs
Authorization: Bearer <TOKEN>
Content-Type: application/json

{ "catalog_id": "<META_CATALOG_ID>" }
```

### Listar produtos do catálogo (via Catalog API, não WhatsApp)

```http
GET https://graph.facebook.com/v23.0/<CATALOG_ID>/products
Authorization: Bearer <TOKEN>
```

> Ingestão de produtos é via Catalog Feed (CSV/XML/Google Sheets) ou Catalog API — fora do escopo do `whatsapp_business_management`.

### Enviar Single Product Message

```http
POST /<PHONE_NUMBER_ID>/messages
{
  "messaging_product": "whatsapp",
  "recipient_type": "individual",
  "to": "5511999998888",
  "type": "interactive",
  "interactive": {
    "type": "product",
    "body": { "text": "Confira este produto:" },
    "footer": { "text": "Frete grátis acima de R$199" },
    "action": {
      "catalog_id": "<CATALOG_ID>",
      "product_retailer_id": "SKU-12345"
    }
  }
}
```

### Enviar Multi-Product Message

```http
POST /<PHONE_NUMBER_ID>/messages
{
  "type": "interactive",
  "interactive": {
    "type": "product_list",
    "header": { "type": "text", "text": "Destaques de Maio" },
    "body": { "text": "Veja nossas ofertas:" },
    "action": {
      "catalog_id": "<CATALOG_ID>",
      "sections": [
        {
          "title": "Tênis",
          "product_items": [
            { "product_retailer_id": "SKU-1" },
            { "product_retailer_id": "SKU-2" }
          ]
        }
      ]
    }
  }
}
```

---

## Checklist de produção (este reference)

- [ ] CRUD de QR codes com download direto de PNG/SVG e cache em S3.
- [ ] Tela de Conversational Components com toggle welcome + editor de prompts/commands.
- [ ] Tela de Block User com tabela paginada e atalho "bloquear remetente" no inbox.
- [ ] Tela de Business Profile com upload de foto via Resumable Upload e validação de limites por campo.
- [ ] Tela de Commerce Settings (toggle cart/catalog) e vinculação de Catalog ID.
- [ ] Para cada um, listener dos webhooks relevantes (`messages` para detectar bloqueio efetivo, `flows` para Flow templates).
