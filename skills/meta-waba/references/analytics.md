# Analytics — Account, Conversation, Template, Pricing

> Quatro endpoints distintos que respondem perguntas diferentes. Cada um tem padrões de chamada via `fields` com modificadores (`.start()`, `.end()`, `.granularity()`, `.dimensions()`) — sintaxe peculiar que confunde quem está acostumado com REST normal.

## Visão geral dos 4 endpoints

| Endpoint | Pergunta que responde | Pré-requisito |
|---|---|---|
| **Account analytics** (`analytics`) | "Quantas mensagens enviei e foram entregues?" | Habilitado por padrão |
| **Conversation analytics** (`conversation_analytics`) | "Qual meu custo por categoria de conversa?" | Habilitado por padrão |
| **Template analytics** (`template_analytics`) | "Qual o desempenho de cada template (sent/delivered/read/clicked/cost)?" | Setar `is_enabled_for_insights=true` |
| **Pricing analytics** (`pricing_analytics`) | "Quanto custou por país × categoria × tipo de pricing?" | Habilitado por padrão |

## Habilitar Template Analytics (passo único, mas obrigatório)

```http
POST https://graph.facebook.com/v23.0/<WABA_ID>
Authorization: Bearer <TOKEN>
Content-Type: application/json

{ "is_enabled_for_insights": true }
```

Sem isso, `template_analytics` retorna vazio. Fazer no onboarding de cada WABA.

## Account Analytics — volume agregado

```http
GET https://graph.facebook.com/v23.0/<WABA_ID>
  ?fields=analytics.start(<UNIX_TS>).end(<UNIX_TS>).granularity(<G>).phone_numbers(<P>).country_codes(<C>)
Authorization: Bearer <TOKEN>
```

Modificadores:
- `start`/`end`: timestamps Unix em segundos.
- `granularity`: `HALF_HOUR` | `DAY` | `MONTH`.
- `phone_numbers`: array opcional de display phone numbers (com `+`), ex: `["+551130000000"]`.
- `country_codes`: array opcional de códigos ISO-2, ex: `["BR","AR"]`.

Resposta:
```json
{
  "id": "<WABA_ID>",
  "analytics": {
    "phone_numbers": ["+551130000000"],
    "country_codes": ["BR"],
    "granularity": "DAY",
    "data_points": [
      { "start": 1714867200, "end": 1714953600, "sent": 1234, "delivered": 1230 }
    ]
  }
}
```

## Conversation Analytics — custo e tipo

```http
GET https://graph.facebook.com/v23.0/<WABA_ID>
  ?fields=conversation_analytics
    .start(<UNIX>)
    .end(<UNIX>)
    .granularity(DAILY)
    .phone_numbers(["+551130000000"])
    .metric_types(["COST","CONVERSATION"])
    .conversation_categories(["MARKETING","UTILITY","AUTHENTICATION","SERVICE"])
    .conversation_types(["FREE_ENTRY_POINT","FREE_TIER","REGULAR"])
    .dimensions(["CONVERSATION_CATEGORY","COUNTRY","PHONE","CONVERSATION_TYPE"])
Authorization: Bearer <TOKEN>
```

Granularidades aceitas aqui: `HALF_HOUR` | `DAILY` | `MONTHLY` (atenção, `DAILY` aqui, `DAY` no account analytics — inconsistência da API).

Resposta agrupa por dimensions escolhidas:
```json
{
  "conversation_analytics": {
    "data": [
      {
        "data_points": [
          {
            "start": 1714867200,
            "end": 1714953600,
            "conversation": 350,
            "phone_number": "+551130000000",
            "country": "BR",
            "conversation_category": "MARKETING",
            "conversation_type": "REGULAR",
            "cost": 84.5
          }
        ]
      }
    ]
  }
}
```

Campos:
- `conversation_category`: `MARKETING` | `UTILITY` | `AUTHENTICATION` | `SERVICE`
- `conversation_type`:
  - `FREE_ENTRY_POINT` — usuário entrou via CTA ad ou QR (até 72h grátis após CTWA)
  - `FREE_TIER` — primeiras N conversas gratuitas no tier
  - `REGULAR` — paga
- `cost`: em moeda da WABA (`BRL` se WABA brasileira; ainda em `USD` para muitas em 2026).

> **Atenção temporal:** desde julho/2025, a Meta cobra **per-message** para templates marketing/utility (não mais por conversa de 24h). `conversation_analytics` continua agregando, mas o que aparece em `cost` reflete o novo modelo.

## Template Analytics — desempenho por template

```http
GET https://graph.facebook.com/v23.0/<WABA_ID>/template_analytics
  ?start=<UNIX>
  &end=<UNIX>
  &granularity=DAILY
  &metric_types=["SENT","DELIVERED","READ","CLICKED","COST"]
  &template_ids=["<TEMPLATE_ID_1>","<TEMPLATE_ID_2>"]
Authorization: Bearer <TOKEN>
```

Resposta:
```json
{
  "data": [
    {
      "data_points": [
        {
          "template_id": "1234567890",
          "start": 1714867200,
          "end": 1714953600,
          "sent": 5000,
          "delivered": 4850,
          "read": 3200,
          "clicked": [
            { "type": "url", "button_content": "Comprar agora", "count": 412 },
            { "type": "quick_reply", "button_content": "Confirmar", "count": 287 }
          ],
          "cost": 350.50
        }
      ]
    }
  ]
}
```

Casos onde isto é gold:
- Identificar templates com baixo `read/sent` (texto fraco, mau timing).
- Calcular CTR por botão — `clicked.count / delivered`.
- Comparar campanhas A/B (templates com mesmo body e variações sutis).

## Pricing Analytics — custo por país × categoria

```http
GET https://graph.facebook.com/v23.0/<WABA_ID>/pricing_analytics
  ?start=<UNIX>
  &end=<UNIX>
  &granularity=DAILY
  &country_codes=["BR","AR"]
  &pricing_types=["REGULAR","FREE_ENTRY","FREE_CUSTOMER_SERVICE"]
  &pricing_categories=["MARKETING","UTILITY","AUTHENTICATION","SERVICE"]
  &phone_numbers=["+551130000000"]
Authorization: Bearer <TOKEN>
```

`pricing_types`:
- `REGULAR` — pago
- `FREE_ENTRY` — janela de 72h pós-CTWA ad / Free Entry Point
- `FREE_CUSTOMER_SERVICE` — janela de 24h iniciada pelo cliente (mensagens de serviço)

Mais granular que `conversation_analytics` para fins financeiros.

## Estratégia recomendada de coleta

Em vez de bater na API toda vez que o usuário abre o dashboard:

1. **Job diário às 03:00** (timezone do cliente) que busca os últimos 35 dias com granularidade `DAILY`.
2. Persistir em `analytics_snapshots` (`waba_id`, `metric_type`, `bucket_start`, `bucket_end`, `dimensions_json`, `value_numeric`, `value_money`, `currency`).
3. Dashboard lê do banco — instantâneo.
4. Botão "Atualizar agora" para forçar refresh ad-hoc (com rate limit por usuário).

## Schema sugerido para snapshots

```sql
CREATE TABLE analytics_snapshots (
  id            BIGSERIAL PRIMARY KEY,
  waba_id       VARCHAR(50) NOT NULL,
  source        VARCHAR(30) NOT NULL,  -- 'account' | 'conversation' | 'template' | 'pricing'
  bucket_start  TIMESTAMPTZ NOT NULL,
  bucket_end    TIMESTAMPTZ NOT NULL,
  dimensions    JSONB NOT NULL,        -- { country: 'BR', category: 'MARKETING', phone: '+5511...' }
  metrics       JSONB NOT NULL,        -- { sent: 1234, delivered: 1230, cost: 84.5 }
  currency      CHAR(3),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (waba_id, source, bucket_start, dimensions)
);
CREATE INDEX ON analytics_snapshots (waba_id, source, bucket_start DESC);
```

## Métricas chave para o dashboard

Painéis que clientes acham úteis em produção:

1. **Top-line cards** — total enviado, entregue, lido (D/M/W), com delta vs período anterior.
2. **Custo por categoria** — gráfico de barras empilhadas marketing/utility/auth/service no tempo.
3. **Top templates** — tabela com nome, sent, delivered, read rate, click rate, cost.
4. **Distribuição por país** (clientes com WABA multi-país) — heatmap ou treemap.
5. **Quality timeline** — `quality_rating` por número ao longo do tempo (vem de webhooks, não dos analytics — mas faz sentido juntar).
6. **Conversões por categoria** — apenas via Pricing Analytics, mostra free vs regular.

## Limites de janela

- `start`/`end` máximo: **90 dias** de range em uma única chamada.
- Granularidade `HALF_HOUR` só aceita `start`/`end` dentro de 7 dias.
- Templates antes de `is_enabled_for_insights=true` não retornam dados — só após habilitar.
- Em períodos sem atividade, `data_points` vem vazio ou ausente — não é erro.

## Erros comuns

| Sintoma | Causa |
|---|---|
| `template_analytics` vazio | Esqueceu `is_enabled_for_insights=true` |
| `Permission denied` (200) | System User sem `VIEW_COST` na WABA |
| Range > 90 dias rejeitado | Quebrar em múltiplas chamadas |
| Diferença entre `conversation_analytics.cost` e o billing real | Per-message pricing (jul/2025+) — confiar no billing portal para fechamento |
| Sem `pricing_analytics` em algumas WABAs antigas | Pode precisar de upgrade da WABA — abrir ticket Meta |

## Export e reporting

Implementar export CSV/XLSX do dashboard. Headers que clientes pedem em ordem:

```
date, phone_number, country, conversation_category, conversation_type,
sent, delivered, read, clicked, conversations, cost, currency
```

Com filtro de range customizado e quebra por dimensão escolhida.
