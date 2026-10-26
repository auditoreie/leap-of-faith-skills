# Discovery — o que perguntar, quando não perguntar, quando a task está pronta

## Quando NÃO perguntar

A resposta já existe; perguntar é ruído:

- A demanda cita arquivo, endpoint, tela ou ID de task/PR — vá ler.
- É bug com reprodução clara (passos, esperado × obtido) — confirme no código, não com o usuário.
- O `CLAUDE.md` ou um ADR já decidiu (toggle default-OFF, PR por package, `/v1` aditivo…) — aplique e cite.
- A resposta não muda a task (curiosidade; detalhe que o dev decide na hora).

Sobrou dúvida que muda escopo, contrato, risco ou critério de aceite → pergunte.

## Formato

`AskUserQuestion`, 2-3 perguntas por rodada, cada uma com 2-4 opções concretas. A opção nasce da evidência, não do vácuo:

> Hoje o reenvio (`packages/api/src/reservation/reservation.service.ts:412`) só dispara e-mail. A demanda quer:
> (a) WhatsApp **além** do e-mail · (b) WhatsApp **no lugar** do e-mail quando o cliente tiver número · (c) o hoteleiro escolhe na tela

"(Recomendado)" na primeira opção só quando há motivo no código ou no ADR para recomendar. Máximo 3 rodadas; o resto vira "Decisões pendentes" com dono.

## Banco por tipo

**Erro (bug)**
1. Quem sente e onde (produção? todos os clientes? um só?) — define urgência.
2. Esperado × obtido, com o ponto do código onde diverge (você localiza; o usuário confirma).
3. Corrigir a causa ou só o sintoma (ex.: status travado em `PENDING`: reconciliar ou só destravar?).
4. Precisa de backfill ou correção de dados já gravados? Quem executa e como reverte? (plano via `/migracao-segura-prisma-mongo`)
5. Impacto no usuário pela rubrica de `references/qa-impacto.md` (Blocks-Completion … Cosmetic) — obrigatório no "Problema" de task de Erro; dinheiro é Data-Loss no mínimo.

**Melhoria / feature**
1. Efeito observável para quem usa (usuário final, operador, integrador, financeiro), em uma frase — vira a base do título.
2. Fronteira: o que fica **fora** (a lista de não-objetivos é o que mais evita inflar).
3. Contrato tocado: tela, endpoint interno, `/v1` público, webhook, schema Prisma. Cada um puxa uma regra do harness (aditivo, 2 aprovações, `db push`/backfill).
4. Toggle: nome sugerido, onde liga (env do serviço, config por cliente/tenant, `environment.ts`), comportamento com flag OFF idêntico ao atual.
5. Rollout e rollback: ordem de merge se depende de outro PR, env a criar, o que ligar depois.

**Refactor / dívida / ADR**
1. Que decisão ou dor motiva (ADR ou incidente). Sem motivo citável, é candidato a "não fazer agora".
2. Puramente aditivo ou muda comportamento? Se muda, é feature (toggle).
3. Qual ADR precisa ser aceito ou escrito antes — ADR "Proposto" bloqueia merge de implementação.

**Sempre**
- Assignee (nome; "pra mim" vale) — a task nasce atribuída.
- Prioridade e prazo só se o usuário mencionar; não invente urgência.
- Demanda nos dois produtos: quem é o dono e em que ordem os PRs entram.

## Rubrica de prontidão (veredito)

Marque cada item como **evidência** (código/ADR/doc aberto nesta sessão), **decisão do usuário** (resposta literal) ou **pendente**.

| # | Marcador | Checagem |
|---|---|---|
| 1 | Problema | Quem não estava na conversa entende quem sente o quê, e como sabemos? |
| 2 | Fronteira | Há lista explícita de fora de escopo? |
| 3 | Contrato | Sabemos quais interfaces mudam (tela, endpoint, `/v1`, webhook, schema) e a regra do harness para cada? |
| 4 | Decisões a preservar | ADRs e toggles da área citados pelo nome, com status? |
| 5 | Segurança / dinheiro | Se toca auth, credencial, webhook, saque, split, estorno ou taxa: está marcado como classe de risco? |
| 6 | Aceite verificável | Cada critério tem comando de teste ou passo de reprodução, não "deve funcionar"? Há critério de estado final por caminho independente (`qa-impacto.md`)? |
| 7 | Dono | Assignee e repo definidos? |

- Tudo evidência/decisão → **PRONTA**.
- 1-3 pendentes fora de #1 e #7 → **PRECISA DECISÃO** (liste com dono; a task pode nascer).
- #1 ou #7 pendente, ou dependência dura (ADR Proposto, PR aberto do mesmo tema, contrato do outro lado inexistente) → **BLOQUEADA**: registre em "Bloqueio"; a task nasce em `backlog` apontando o desbloqueio.

## Título — checagem final

Fórmula: **ação + objeto específico + resultado/critério**. Efeito observável primeiro, jargão depois. Quem lê o board sem abrir a task entende o que será feito e por quê.

| Rejeitar | Aceitar |
|---|---|
| `Ajuste no reenvio` | `Reenviar link de pagamento também por WhatsApp quando o cliente usa o gateway X, para o comprador não depender do e-mail cair no spam` |
| `Investigar PIX pendente` | `Reconciliar cobranças PIX pagas no gateway que ficaram PENDING no sistema e disparar o webhook payment.confirmed atrasado` |
| `ADR design system` | `Registrar em ADR a política de enforcement do design system e o breakpoint canônico de 1355px já em produção` |
