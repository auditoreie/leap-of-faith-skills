# WhatsApp Flows — formulários multi-tela dentro do chat

Flows são experiências interativas declaradas em JSON que rodam dentro do WhatsApp — booking, lead capture, surveys, checkout. Substituem em muitos casos a necessidade de mandar o usuário para uma landing externa.

## Tipos de Flow

- **Estático** — todas as telas e dados estão no JSON. Funciona como Google Forms. Sem callback.
- **Dinâmico** — o JSON declara as telas, mas em momentos chave o WhatsApp chama um endpoint seu (`endpoint_uri`) com payload criptografado. Você responde com a próxima tela ou ação. Necessário para qualquer Flow que dependa de lógica do servidor (validação contra DB, busca de slots de agenda, etc.).

## CRUD de Flow

```http
# Criar (metadata)
POST https://graph.facebook.com/v23.0/<WABA_ID>/flows
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "name": "Agendamento clínica",
  "categories": ["APPOINTMENT_BOOKING"],
  "endpoint_uri": "https://app.fgbconsultoria.com.br/flows/endpoint"
}
# → { "id": "<FLOW_ID>" }

# Listar
GET /<WABA_ID>/flows?fields=id,name,status,categories,validation_errors,endpoint_uri,preview

# Atualizar metadata
POST /<FLOW_ID>
{ "name": "Novo nome", "endpoint_uri": "..." }

# Deletar (só se DRAFT)
DELETE /<FLOW_ID>
```

### Categorias disponíveis

`SIGN_UP`, `SIGN_IN`, `APPOINTMENT_BOOKING`, `LEAD_GENERATION`, `CONTACT_US`, `CUSTOMER_SUPPORT`, `SURVEY`, `OTHER`. Pode passar múltiplas.

## Subir o JSON do Flow (estrutura de telas)

```http
POST https://graph.facebook.com/v23.0/<FLOW_ID>/assets
Authorization: Bearer <TOKEN>
Content-Type: multipart/form-data

asset_type=FLOW_JSON
name=flow.json
file=@/path/to/flow.json
```

O JSON segue o **Flow JSON Schema** da Meta (versão atual `7.0`). Estrutura mínima:

```json
{
  "version": "7.0",
  "data_api_version": "3.0",
  "routing_model": {
    "WELCOME": ["DETAILS"],
    "DETAILS": ["CONFIRM"],
    "CONFIRM": []
  },
  "screens": [
    {
      "id": "WELCOME",
      "title": "Olá",
      "data": {},
      "layout": {
        "type": "SingleColumnLayout",
        "children": [
          { "type": "TextHeading", "text": "Vamos agendar sua consulta?" },
          {
            "type": "Footer",
            "label": "Continuar",
            "on-click-action": { "name": "navigate", "next": { "type": "screen", "name": "DETAILS" } }
          }
        ]
      }
    }
    /* ... DETAILS, CONFIRM ... */
  ]
}
```

> Componentes disponíveis: `TextHeading`, `TextSubheading`, `TextBody`, `TextCaption`, `TextInput`, `TextArea`, `Dropdown`, `RadioButtonsGroup`, `CheckboxGroup`, `OptIn`, `DatePicker`, `Image`, `EmbeddedLink`, `Footer`. Ver schema oficial.

## Validar e publicar

```http
# Ler validação atual
GET /<FLOW_ID>?fields=validation_errors

# Forçar revalidação
GET /<FLOW_ID>?fields=preview.invalidate(false),validation_errors

# Publicar (de DRAFT para PUBLISHED)
POST /<FLOW_ID>/publish

# Deprecar (PUBLISHED → DEPRECATED — não pode mais ser enviado)
POST /<FLOW_ID>/deprecate
```

Status possíveis: `DRAFT`, `PUBLISHED`, `DEPRECATED`, `BLOCKED`, `THROTTLED`.

## Endpoint dinâmico — criptografia obrigatória

Para Flows com `endpoint_uri`, a Meta exige que o tráfego seja criptografado com **RSA + AES-128-GCM**:

1. Você gera um par RSA 2048 bits (chave pública e privada).
2. Sobe a chave pública para a Meta:
   ```http
   POST /<PHONE_NUMBER_ID>/whatsapp_business_encryption
   { "business_public_key": "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----" }
   ```
3. Quando o WhatsApp chama seu `endpoint_uri`, o body vem com:
   ```json
   {
     "encrypted_aes_key": "<base64>",
     "encrypted_flow_data": "<base64>",
     "initial_vector": "<base64>"
   }
   ```
4. Você:
   - Decripta `encrypted_aes_key` usando sua chave privada RSA → obtém AES key.
   - Usa AES key + IV para decriptar `encrypted_flow_data` → JSON do request.
   - Processa.
   - Cria response JSON.
   - Criptografa response com a mesma AES key + IV invertido (cada byte XOR `0xFF`).
   - Retorna como `body` plain text do response HTTP.

Implementação completa de referência (Node.js):

```typescript
import { createDecipheriv, createCipheriv, privateDecrypt, constants } from 'node:crypto';

interface FlowRequestEncrypted {
  encrypted_aes_key: string;
  encrypted_flow_data: string;
  initial_vector: string;
}

export function decryptFlowRequest(
  encrypted: FlowRequestEncrypted,
  privateKeyPem: string,
  passphrase?: string,
): { request: any; aesKey: Buffer; iv: Buffer } {
  // 1. Decripta a chave AES com RSA-OAEP-SHA256
  const aesKey = privateDecrypt(
    {
      key: privateKeyPem,
      passphrase,
      padding: constants.RSA_PKCS1_OAEP_PADDING,
      oaepHash: 'sha256',
    },
    Buffer.from(encrypted.encrypted_aes_key, 'base64'),
  );

  // 2. Separa ciphertext e tag (últimos 16 bytes)
  const flowDataBuffer = Buffer.from(encrypted.encrypted_flow_data, 'base64');
  const ciphertext = flowDataBuffer.subarray(0, -16);
  const authTag = flowDataBuffer.subarray(-16);
  const iv = Buffer.from(encrypted.initial_vector, 'base64');

  // 3. Decripta com AES-128-GCM
  const decipher = createDecipheriv('aes-128-gcm', aesKey, iv);
  decipher.setAuthTag(authTag);
  const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);

  return { request: JSON.parse(plaintext.toString('utf8')), aesKey, iv };
}

export function encryptFlowResponse(response: any, aesKey: Buffer, iv: Buffer): string {
  // IV invertido bit-a-bit
  const flippedIv = Buffer.from(iv.map((b) => b ^ 0xff));
  const cipher = createCipheriv('aes-128-gcm', aesKey, flippedIv);
  const ciphertext = Buffer.concat([
    cipher.update(JSON.stringify(response), 'utf8'),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();
  return Buffer.concat([ciphertext, authTag]).toString('base64');
}
```

Endpoint Express:

```typescript
app.post('/flows/endpoint', async (req, res) => {
  try {
    const { request, aesKey, iv } = decryptFlowRequest(req.body, PRIVATE_KEY_PEM);
    
    // request: { version, action, screen, data, flow_token }
    const response = await handleFlowAction(request);
    
    const encryptedBody = encryptFlowResponse(response, aesKey, iv);
    res.status(200).type('text/plain').send(encryptedBody);
  } catch (err) {
    logger.error({ err }, 'Flow endpoint failed');
    res.sendStatus(421);  // Sinaliza para Meta refresh chave pública
  }
});
```

## Ações do request dinâmico

`request.action` pode ser:

- `INIT` — primeira tela do Flow. Responder com tela inicial e dados.
- `data_exchange` — usuário interagiu, você processa e responde com próxima tela ou ação.
- `BACK` — usuário voltou.
- `ping` — health check da Meta. Responder `{ "data": { "status": "active" } }`.

Estrutura típica de resposta:

```json
{
  "version": "7.0",
  "screen": "DETAILS",
  "data": {
    "available_slots": [
      { "id": "1", "title": "07/05 14:30" },
      { "id": "2", "title": "07/05 16:00" }
    ]
  }
}
```

Ou ação terminal:

```json
{
  "version": "7.0",
  "screen": "SUCCESS",
  "data": {
    "extension_message_response": {
      "params": {
        "flow_token": "<TOKEN_DO_REQUEST>",
        "appointment_id": "abc123"
      }
    }
  }
}
```

## Enviar Flow ao usuário

Como mensagem direta (durante janela de 24h):

```http
POST /<PHONE_NUMBER_ID>/messages
{
  "messaging_product": "whatsapp",
  "to": "5511999998888",
  "type": "interactive",
  "interactive": {
    "type": "flow",
    "header": { "type": "text", "text": "Agende sua consulta" },
    "body": { "text": "Selecione um horário" },
    "footer": { "text": "Powered by FGB" },
    "action": {
      "name": "flow",
      "parameters": {
        "flow_message_version": "3",
        "flow_id": "<FLOW_ID>",
        "flow_cta": "Agendar",
        "flow_action": "navigate",
        "flow_action_payload": {
          "screen": "WELCOME",
          "data": { "user_name": "Felipe" }
        }
      }
    }
  }
}
```

Como botão dentro de **template** — ver `references/templates.md` (seção Flow templates).

## Webhook `flows`

Mudanças de status do Flow (publicação aprovada/rejeitada, throttle, block):

```json
{
  "field": "flows",
  "value": {
    "event": "PUBLISHED",
    "flow_id": "<FLOW_ID>",
    "name": "...",
    "old_status": "DRAFT",
    "new_status": "PUBLISHED"
  }
}
```

## Erros comuns

| Sintoma | Causa |
|---|---|
| Flow JSON inválido na publicação | `version` errada ou screens com `id` duplicado |
| Endpoint dinâmico recebe 421 da Meta | Decriptação falhou (chave pública desatualizada) → Meta pede refresh |
| `Flow not published` no envio | Publicar antes de enviar |
| Flow chega "quebrado" no celular do usuário | Versão WhatsApp do usuário antiga — `flow_message_version: "3"` exige WhatsApp recente |
| Validação local diz OK mas Meta rejeita | Schema da Meta tem validações além do JSON Schema (ex.: routing model precisa ser DAG conexo) |

## Checklist de produção (Flows)

- [ ] Importador de JSON com validação de schema local (Ajv contra schema oficial Meta).
- [ ] Editor JSON com autocomplete dos componentes válidos.
- [ ] Botões: salvar rascunho, validar, publicar, deprecar.
- [ ] Endpoint dinâmico criptografado com RSA-OAEP-SHA256 + AES-128-GCM.
- [ ] Chave privada RSA em KMS, **nunca** no código.
- [ ] Endpoint `ping` respondendo health check.
- [ ] Logs estruturados de cada `data_exchange` (sem dados PII em claro).
- [ ] Listener `flows` webhook.
- [ ] Versionamento de Flow JSON local (cada upload = nova versão arquivada).
