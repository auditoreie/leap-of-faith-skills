# Resumable Upload API — Mídia para templates e perfil

> Pré-requisito para qualquer header de mídia (`IMAGE`/`VIDEO`/`DOCUMENT`) em template e para foto de perfil comercial. Fluxo de **3 chamadas** sequenciais. Falha mais comum: usar token errado na etapa 2 ou esquecer que o `Authorization` ali é `OAuth`, não `Bearer`.

## Quando usar (e quando NÃO usar)

| Cenário | Use Resumable Upload? | Alternativa |
|---|---|---|
| `header_handle` em template (criação) | **Sim** | Não há outro caminho |
| `profile_picture_handle` em business profile | **Sim** | Não há outro caminho |
| Enviar mídia como mensagem para usuário | **Não** | Use `POST /<PHONE_NUMBER_ID>/media` (Cloud API Media), não a Resumable |
| Mídia em mensagem como `link` URL | **Não** | Apenas passar a URL na hora do envio |

A Cloud API tem **dois sistemas de mídia distintos** que confundem todo mundo:

- **Resumable Upload (Graph API)** → produz `header_handle` para templates e perfil. URL: `graph.facebook.com/<APP_ID>/uploads`.
- **Cloud API Media** → produz `media_id` para enviar como mensagem. URL: `graph.facebook.com/<PHONE_NUMBER_ID>/media`.

São incompatíveis: `media_id` não funciona em template, `header_handle` não funciona em mensagem.

## Especificação de mídia (limites estritos)

| Tipo | MIME aceitos | Tamanho máx | Notas |
|---|---|---|---|
| Imagem | `image/jpeg`, `image/png` | 5 MB | Aspect ratio 1.91:1 ideal para preview |
| Vídeo | `video/mp4`, `video/3gp` | 16 MB | H.264 + AAC. ≤30fps. **VP8/VP9 não funciona** |
| Documento | `application/pdf` | 100 MB | Apenas PDF |

Se o cliente subir vídeo em outro formato/codec, **transcodificar antes** (ffmpeg). Vídeo errado é a causa #1 de rejeição silenciosa.

## Etapa 1 — Iniciar sessão de upload

```http
POST https://graph.facebook.com/v23.0/<APP_ID>/uploads
  ?file_name=video_demo.mp4
  &file_length=8388608
  &file_type=video/mp4
  &access_token=<APP_ACCESS_TOKEN_OU_USER_TOKEN>
```

`file_length` é o tamanho **em bytes**.

`<APP_ACCESS_TOKEN>` é montado como `<APP_ID>|<APP_SECRET>` (note o pipe). Alternativamente, um System User Token com `whatsapp_business_management` também funciona. **Não use o BISU do cliente aqui** — esse upload é a nível de app, não de WABA.

Resposta:
```json
{ "id": "upload:MDk0YzlmNTAtNjBkOC00NjM4..." }
```

Esse `id` é a **upload session ID** — guardar para a próxima etapa.

## Etapa 2 — Enviar os bytes

```http
POST https://graph.facebook.com/v23.0/<UPLOAD_SESSION_ID>
Authorization: OAuth <ACCESS_TOKEN>
file_offset: 0
Content-Type: application/octet-stream

<binary data...>
```

> **Atenção crítica:** o header `Authorization` aqui é `OAuth <TOKEN>`, **não `Bearer <TOKEN>`**. Esta é a única exceção em toda a Cloud API. Errar aqui gera `OAuthException` confuso. Anotar.

> O body é os bytes brutos do arquivo. **Não usar multipart/form-data, não JSON, não base64.** É upload raw.

Resposta:
```json
{ "h": "4::aW1hZ2UvanBlZw==:ARZ..." }
```

O valor de `h` é o **`header_handle`** (ou `profile_picture_handle`). É o que vai dentro de `example.header_handle` no template ou direto no body do business profile.

## Etapa 3 — Usar o handle

```http
# Em template
POST /<WABA_ID>/message_templates
{
  "components": [
    {
      "type": "HEADER",
      "format": "VIDEO",
      "example": { "header_handle": ["4::aW1hZ2UvanBlZw==:ARZ..."] }
    }
  ]
}

# Em business profile
POST /<PHONE_NUMBER_ID>/whatsapp_business_profile
{
  "messaging_product": "whatsapp",
  "profile_picture_handle": "4::aW1hZ2UvanBlZw==:ARZ..."
}
```

## Retomar upload após falha (chunking)

Se a etapa 2 falhar no meio (rede, timeout), **não recomeçar do zero**. Consultar offset atual:

```http
GET https://graph.facebook.com/v23.0/<UPLOAD_SESSION_ID>
Authorization: OAuth <ACCESS_TOKEN>
```

Resposta:
```json
{ "id": "upload:...", "file_offset": 4194304 }
```

Recomeçar a etapa 2 com `file_offset` apontando para esse valor, enviando apenas os bytes restantes a partir dele:

```http
POST https://graph.facebook.com/v23.0/<UPLOAD_SESSION_ID>
Authorization: OAuth <ACCESS_TOKEN>
file_offset: 4194304
Content-Type: application/octet-stream

<binary a partir do byte 4194304>
```

Útil quando arquivos grandes (vídeo 16MB, PDF 100MB) caem em conexão móvel.

## Cache por SHA-256 (recomendado)

Vídeos de exemplo de templates raramente mudam. Cachear no banco:

```sql
CREATE TABLE template_media_handles (
  sha256        CHAR(64) PRIMARY KEY,
  mime          VARCHAR(50) NOT NULL,
  file_name     VARCHAR(255),
  header_handle TEXT NOT NULL,
  size_bytes    BIGINT NOT NULL,
  created_at    TIMESTAMP DEFAULT NOW()
);
```

Antes de subir, calcular `sha256` do arquivo. Se já existir, reutilizar o handle. Economiza tempo e quota.

> **Atenção:** o handle não tem TTL documentado, mas há relatos de expiração após semanas/meses. Se um POST de template falhar com erro `Invalid header_handle`, invalidar o cache e re-uploadar.

## Implementação TypeScript de referência

Já existe pronta em `scripts/resumable_upload.ts` desta skill. Encapsula:

- Cálculo automático de SHA-256 + cache em memória.
- Chunking automático para arquivos > 4MB.
- Retry com leitura de `file_offset` após falha.
- Header `Authorization: OAuth` correto.
- Tipagem do retorno como `{ handle: string }`.

Use direto no projeto do usuário. Adapte apenas o `cache` (Redis em produção, em memória em dev).

## Erros comuns

| Sintoma | Causa | Solução |
|---|---|---|
| `OAuthException` na etapa 2 | Header é `Bearer` em vez de `OAuth` | Trocar para `OAuth <TOKEN>` |
| `100 Invalid parameter` na etapa 1 | `file_length` em bits ou KB | Converter para bytes |
| `190 access token expired` | App token montado errado | Conferir `<APP_ID>|<APP_SECRET>` (com pipe) |
| Template criado mas vídeo não aparece | Codec errado (VP9, AV1) | Recodificar para H.264 |
| `Invalid header_handle` ao criar template | Handle expirou | Invalidar cache, re-uploadar |
| Upload trava em ~50% | Chunk grande demais para a rede | Implementar chunking 1–2 MB |

## Diferença com Cloud API Media (para evitar confusão)

```http
# Cloud API Media — para enviar como MENSAGEM, retorna media_id
POST https://graph.facebook.com/v23.0/<PHONE_NUMBER_ID>/media
Authorization: Bearer <BISU>
Content-Type: multipart/form-data

messaging_product=whatsapp
file=@arquivo.mp4
type=video/mp4
```

Resposta: `{ "id": "<MEDIA_ID>" }`. Esse `media_id` é usado no envio:

```http
POST /<PHONE_NUMBER_ID>/messages
{
  "messaging_product": "whatsapp",
  "to": "5511999998888",
  "type": "video",
  "video": { "id": "<MEDIA_ID>", "caption": "..." }
}
```

Limites diferentes (vídeo 16MB no media, 100MB no document, etc.) e a media expira em **30 dias**.

| Aspecto | Resumable Upload | Cloud API Media |
|---|---|---|
| URL | `/<APP_ID>/uploads` | `/<PHONE_NUMBER_ID>/media` |
| Token | App token / System User | BISU da WABA |
| Auth header | `OAuth` | `Bearer` |
| Body | Raw bytes | `multipart/form-data` |
| Resultado | `header_handle` (string opaca) | `media_id` (numérico) |
| Uso | Template HEADER, profile picture | Envio de mensagem |
| TTL | Não documentado (semanas+) | 30 dias |
