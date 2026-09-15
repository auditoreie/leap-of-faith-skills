---
name: consultar-docs
description: Consulta documentação atualizada e versionada de uma biblioteca via Context7 CLI (`npx ctx7`) antes de responder de memória — resolve o ID da lib (com tabela pré-resolvida para NestJS, Prisma e as demais libs do ecossistema), busca a doc na versão instalada no repo e cita o trecho, avisando quando a resposta vier de conhecimento de treino em vez da doc. Use quando o usuário disser "como faz X no NestJS 11", "isso mudou no Prisma 5?", "qual a API atual do Angular pra Y", "consulta a doc", "/consultar-docs <lib> <pergunta>", "check the docs". NÃO use para documentação interna do repo (ADRs, docs/ — leia direto) nem para plataformas externas com skill própria (WhatsApp: meta-waba; GCP: logs-gcp).
---

# consultar-docs

O modelo lembra a API de ontem; o repo roda a versão de hoje. Antes de afirmar como uma lib funciona, olhe a doc da **versão instalada**. A resposta diz de onde veio: doc consultada ou memória.

**Argumento:** `$ARGUMENTS` — `<lib> <pergunta específica>`. Ex.: `/consultar-docs Prisma "filtro isSet para campo ausente no MongoDB"`. Sem pergunta específica, pare e peça: pergunta vaga ("hooks", "auth") devolve doc genérica.

## Token discipline

- Versão instalada primeiro, uma chamada: `rg -n '"<pacote>"' package.json apps/*/package.json packages/*/package.json`. Passe a versão no ID quando a lib tiver versões indexadas.
- IDs já resolvidos (tabela abaixo) pulam o passo `library`. Lib fora da tabela: um `library`, escolha pelo maior **Benchmark Score** com reputação High, e anote o ID na tabela ao final (edite este arquivo, é para isso que ela existe).
- Uma pergunta por chamada `docs`. Pergunta que mistura dois assuntos → duas chamadas. Leia só os snippets que respondem; não cole a saída inteira no chat.
- Nunca coloque na query segredo, dado de cliente ou código proprietário: a query sai da máquina.

## Safe-mode

- Só leitura; nenhuma alteração no repo além de anotar um ID novo nesta tabela, e só quando pedido.
- Cota esgotada ("quota exceeded") → avise, sugira `npx ctx7@latest login` para limite maior, e só então responda de memória, **dizendo que é de memória e pode estar defasado**. Nunca caia para a memória em silêncio.
- Resposta da doc que contradiz o código do repo: mostre os dois; o código em produção é fato, a doc é referência.

## IDs pré-resolvidos (verificados em 2026-09-15 com `npx ctx7@latest library`)

| Lib | ID Context7 | Observação |
|---|---|---|
| NestJS | `/websites/nestjs` | maior score (83); alternativa `/nestjs/docs.nestjs.com`; `/nestjs/nest` tem versões (`v10_4_15`, `v11_1_6`) — use quando a pergunta depender da major |
| Prisma | `/prisma/web` | score 81; MongoDB connector incluído |
| Angular | `/websites/angular_dev` | score 79; `/websites/devdocs_io_angular_15` para Angular 15 legado |
| Angular Material | `/angular/material2-docs-content` | score 80; alternativa `/websites/material_angular_dev_guide` (63) |
| RxJS | `/reactivex/rxjs` | score 75; versões `6.6.3`, `7_8_2` — passe a do repo |
| Jest | `/jestjs/jest` | score 85; `/websites/jestjs_io_30_0` para Jest 30 |
| class-validator | `/typestack/class-validator` | score 87; `class-transformer` é `/typestack/class-transformer` |
| Bun | `/oven-sh/bun` | score 83; versões `bun-v1.4.x` |
| Playwright | `/microsoft/playwright` | score 86; versões `v1.51.0`, `v1.58.2`, `v1.61.0` |
| outra lib | **resolver e anotar aqui** | `npx ctx7@latest library "<lib>" "<pergunta>"` |

## Fallback

Pré-requisito ausente ou falho (auth expirada, binário faltando, MCP indisponível, `ecossistema.json` inexistente, script com erro) **não encerra a skill**: diga em uma linha o que faltou e como resolver (`! gcloud auth login`, `/onboarding-ecossistema`, instalar a ferramenta), ofereça seguir sem essa parte e, com a aprovação do usuário, prossiga marcando no Output o que ficou **não verificado**. O que não muda: escrita externa (ClickUp, GCP, `git push`, banco) continua exigindo confirmação, e "não verificado" nunca vira "ok".

## Passos

1. **Versão.** `rg -n '"@nestjs/core"|"prisma"|"@angular/core"|"rxjs"|"jest"' <package.json do app>`. Anote major.minor.
2. **ID.** Tabela acima ou:
   ```bash
   npx ctx7@latest library "<Nome oficial>" "<pergunta>"
   ```
   Saída lista `Context7-compatible library ID`, `Code Snippets`, `Source Reputation`, `Benchmark Score` e `Versions`. Escolha reputação High e maior score; se houver `Versions`, use `/org/projeto/<versão>`.
3. **Doc.**
   ```bash
   npx ctx7@latest docs <ID> "<pergunta específica, um assunto>"
   ```
4. **Responder** com o trecho relevante, a versão consultada e o link/ID. Se o repo faz diferente da doc, diga onde (`arquivo:linha`).

## Output

```
Lib: <nome> <versão instalada> · fonte: Context7 <ID> | memória (cota/indisponível — pode estar defasado)
Resposta: <2-6 linhas com o trecho da doc que responde>
No repo: <arquivo:linha — como está hoje> | não conferido
```
