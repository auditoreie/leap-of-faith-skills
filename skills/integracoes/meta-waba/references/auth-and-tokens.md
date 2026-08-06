# Auth & Tokens — Embedded Signup, BISU, System User

## Tipos de token e quando usar cada um

| Tipo | Para quê serve | Como obtém | Expira? |
|---|---|---|---|
| **User Access Token** | Apenas dev local, Graph API Explorer, primeiro hello world | App Dashboard → API Setup gera 24h, ou Graph Explorer | Sim, ~1h ou 24h |
| **System User Token (admin)** | App opera **sobre os próprios assets** do Business Manager (ex.: você é o dono final, não BSP) | Business Settings → Users → System Users → Generate token, escolhe permissões | Configurável (60d, never) |
| **Business Integration System User Token (BISU)** | App opera **sobre WABAs de clientes** (Tech Provider / Solution Provider) | **Embedded Signup** — usuário completa o flow, retorna `code`, você troca por token | Long-lived (sem expiração padrão) |
| **App Access Token** | Resumable Upload (etapa 1) e algumas chamadas de configuração | `<APP_ID>|<APP_SECRET>` montado direto | N/A |

> **Para o caso "FGB Consultoria virar parceira Meta":** o token alvo é o **BISU**. Sem ele, nada de Tech Provider Program. Embedded Signup é o único caminho oficial.

## Permissões necessárias na revisão de App

Em `App → App Review → Permissions and features`, pedir Advanced Access para:

- `whatsapp_business_management` — gerencia WABA, templates, números
- `whatsapp_business_messaging` — envia/recebe mensagens (Cloud API)
- `business_management` — necessário para listar WABAs/business portfolios do cliente
- `public_profile` — exigência do Embedded Signup (login do usuário)

Sem Advanced Access aprovado, só dá pra onboarding de contas de teste, nunca de cliente real.

## Fluxo Embedded Signup completo

### Pré-requisitos no app Meta

1. App Meta com produto **WhatsApp** adicionado.
2. **Business Manager verificado** (1–3 dias úteis a partir do envio de documentos).
3. **Solution ID (Partner Solution ID)** criado em `Business Settings → Partner Solutions`.
4. **Facebook Login for Business → Configuration** criada com:
   - Login variation: `WhatsApp Embedded Signup`
   - Token type: `System-user access token` (60 dias)
   - Asset: `WhatsApp accounts`
   - Permissions: as três acima
   - Salvar o `config_id` gerado — vai no front.

### Frontend (React/Next.js)

```javascript
// 1) Carregar SDK do Facebook
window.fbAsyncInit = function () {
  FB.init({
    appId: process.env.NEXT_PUBLIC_FB_APP_ID,
    cookie: true,
    xfbml: true,
    version: 'v23.0',
  });
};

(function (d, s, id) {
  if (d.getElementById(id)) return;
  const js = d.createElement(s);
  js.id = id;
  js.src = 'https://connect.facebook.net/en_US/sdk.js';
  d.getElementsByTagName(s)[0].parentNode.insertBefore(js, d.getElementsByTagName(s)[0]);
})(document, 'script', 'facebook-jssdk');

// 2) Capturar dados da janela do Embedded Signup
let sessionInfo = null;
window.addEventListener('message', (event) => {
  if (event.origin !== 'https://www.facebook.com' && event.origin !== 'https://web.facebook.com') return;
  try {
    const data = JSON.parse(event.data);
    if (data.type === 'WA_EMBEDDED_SIGNUP') {
      // data.event: 'FINISH' | 'CANCEL' | 'ERROR'
      if (data.event === 'FINISH') {
        sessionInfo = data.data;
        // sessionInfo: { phone_number_id, waba_id, business_id }
      } else if (data.event === 'CANCEL') {
        console.warn('Embedded Signup cancelled at step:', data.data?.current_step);
      } else if (data.event === 'ERROR') {
        console.error('Embedded Signup error:', data.data);
      }
    }
  } catch (_) { /* ignore non-JSON messages */ }
});

// 3) Disparar o flow ao clicar em "Conectar WhatsApp Business"
function launchEmbeddedSignup() {
  FB.login(
    (response) => {
      if (response.authResponse?.code) {
        // Mandar code + sessionInfo para o backend trocar por BISU
        fetch('/api/whatsapp/connect', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            code: response.authResponse.code,
            ...sessionInfo,
          }),
        });
      }
    },
    {
      config_id: process.env.NEXT_PUBLIC_FB_CONFIG_ID,
      response_type: 'code',
      override_default_response_type: true,
      extras: {
        setup: {},
        featureType: '',
        sessionInfoVersion: '3',
      },
    }
  );
}
```

### Backend — troca do `code` por token de longa duração

```http
GET https://graph.facebook.com/v23.0/oauth/access_token
  ?client_id=<APP_ID>
  &client_secret=<APP_SECRET>
  &code=<CODE_FROM_FRONTEND>
```

Resposta:
```json
{ "access_token": "EAAJB...", "token_type": "bearer" }
```

Esse `access_token` é o **BISU**. **Persistir criptografado** (AES-256-GCM com chave em KMS), associado a `(cliente_id, waba_id, phone_number_id)`. Não tem expiração natural — só é invalidado se o cliente revogar a permissão ou se o app do Business Manager for removido.

### Subscribe automático após onboarding (esquecer disso = nenhum webhook chega)

```http
POST https://graph.facebook.com/v23.0/<WABA_ID>/subscribed_apps
Authorization: Bearer <BISU>
```

Sem body. Faz seu app receber webhooks daquela WABA específica. Repetir essa chamada se o cliente desconectar e reconectar.

### Health check de token (job semanal)

```http
GET https://graph.facebook.com/v23.0/me?fields=id,name
Authorization: Bearer <TOKEN>
```

Se voltar `OAuthException` (code `190`), marcar token como expirado e pedir re-auth ao cliente.

## System User Token (caminho alternativo, para WABAs próprias)

Quando você é o dono final do Business Manager (não está intermediando para cliente):

1. `Business Settings → System Users → +Add` — criar com role `Admin`.
2. No usuário, `Assign assets`:
   - App: `Manage app`
   - WABA: `Full control`
3. `Generate token` → escolher app + permissões (`whatsapp_business_management`, `whatsapp_business_messaging`, `business_management`) + expiração (`Never` para produção).
4. Copiar **uma única vez**. Persistir criptografado.

> System User Token **não funciona** para Tech Provider de cliente externo — você precisa do BISU via Embedded Signup. Mesmo erro: tentar usar System Token em WABA compartilhada quando o System User não tem `Partial`/`Full` access — retorna `code 200: Permission denied`.

## Business Asset Access (essencial e mal documentado)

System Users têm dois perfis:

- **Admin system user** — acesso automático a todas as WABAs do business. Bom para apps internos.
- **Employee system user** — precisa receber acesso explícito por WABA (`Partial` ou `Full`).

Para conceder acesso programaticamente:

```http
POST https://graph.facebook.com/v23.0/<WABA_ID>/assigned_users
  ?user=<SYSTEM_USER_ID>
  &tasks=["MANAGE","DEVELOP","MESSAGING","VIEW_COST","MANAGE_TEMPLATES"]
Authorization: Bearer <BUSINESS_ADMIN_TOKEN>
```

Tasks disponíveis variam por contexto. Ler https://developers.facebook.com/docs/whatsapp/business-management-api/access-controls

## Disconnect / offboarding

```http
DELETE https://graph.facebook.com/v23.0/<WABA_ID>/subscribed_apps
Authorization: Bearer <BISU>
```

Após isso:
1. Marcar token como revogado no banco.
2. Limpar caches que dependiam dessa WABA.
3. Tratar webhook `account_update` com `event: PARTNER_REMOVED` que pode chegar.

## Erros comuns de auth

| Sintoma | Causa provável | Solução |
|---|---|---|
| `code 190 OAuthException` | Token expirou ou cliente revogou | Re-auth via Embedded Signup |
| `code 200 Permission denied` | System User sem acesso à WABA | Conceder access via UI ou API `assigned_users` |
| `code 100 Param invalid` no Embedded Signup callback | `config_id` errado ou versão API divergente | Conferir config_id e `version: 'v23.0'` no FB.init |
| `code 4 App rate limit` | Volume alto de chamadas em token novo | Backoff exponencial; capacidade aumenta com uso |
| `code 80007 Business rate limit` | Muitas chamadas BMAPI por WABA inativa (200/h) | Esperar ou registrar número (eleva para 5000/h) |

## Checklist de produção (auth)

- [ ] Tokens criptografados em repouso com chave em KMS/secret manager.
- [ ] Tokens **nunca** logados em claro (redaction explícita no logger).
- [ ] Job de health check semanal por cliente.
- [ ] Tela "Conexões" listando WABAs com status (saudável / expirado / sem números / sem subscribe).
- [ ] Re-auth assistido quando token expira (notificar cliente via e-mail/painel).
- [ ] Audit log de toda emissão e revogação de token.
- [ ] App Review submetido com Advanced Access (sem isso, só conta de teste).
