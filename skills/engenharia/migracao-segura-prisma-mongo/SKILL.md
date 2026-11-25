---
name: migracao-segura-prisma-mongo
description: Planeja e conduz mudança de schema e de dados em Prisma sobre MongoDB de forma segura — classifica a mudança (só-schema ou dados+schema), aplica expand/contract (campo nasce opcional → dual-write atrás de toggle → backfill idempotente com dry-run → apertar → remover depois), ordena deploy × db push × backfill, exige backup e verificação por contagem, e entrega o plano pronto para as seções "schema" e "Rollout" do PR. Use quando o usuário disser "mudar o schema.prisma", "campo obrigatório novo", "renomear campo", "índice único", "backfill", "db push em produção", "migração de dados no Mongo", "/migracao-segura-prisma-mongo <mudança>". NÃO use para bancos relacionais com Prisma Migrate, para decidir modelagem de domínio (isso é ADR via project-ledger) nem para otimizar query.
---

# migracao-segura-prisma-mongo

No MongoDB o Prisma **não tem Migrate**: `prisma db push` sincroniza schema e índices (`@unique`, `@@index`) e não transforma documento nenhum. Documento antigo que não bate com o schema novo quebra na **leitura**, não no deploy. Por isso a regra é expand/contract: expandir compatível, migrar dados com script idempotente, e só então apertar. Fonte: <https://www.prisma.io/docs/orm/overview/databases/mongodb> (verificado em 2026-09-15: "there are no plans to add support for Prisma Migrate", "any new fields added are explicitly defined as optional", transações exigem replica set).

**Argumento:** `$ARGUMENTS` — a mudança pretendida (ex.: "tornar `Payment.number` obrigatório e único") ou vazio para classificar o diff atual do `schema.prisma`.

`<skill-dir>` é a pasta desta `SKILL.md`.

## Token discipline

- `bash <skill-dir>/scripts/diff-schema.sh <repo>` acha o schema, compara com `origin/<integração>` e com o working tree, e classifica a mudança. Não leia o `schema.prisma` inteiro; leia só os models que o diff toca.
- Molde de backfill: o repo já tem scripts (`rg -l 'PrismaClient' scripts prisma src --glob '*backfill*' --glob '*migrate*'`). Leia **um**, o mais recente, e siga o padrão dele (conexão, dry-run, logs). Se houver ecossistema configurado (`<raiz>/.claude/ecossistema/produtos.md`), a linha "Schema / backfill" do repo aponta o caminho.
- Leia `templates/plano-migracao.md` só no passo 6.
- Onde o `db push` roda no deploy (CI, cloudbuild, skill de deploy, manual): `rg -n 'db push|prisma:deploy|prisma:push' package.json .github cloudbuild*.yaml .claude/skills` — uma chamada, não leitura de workflow inteiro.

## Safe-mode

- **Nunca roda `db push` nem backfill contra banco que não seja local sem: confirmação explícita, backup recente comprovado (script do repo ou snapshot) e dry-run mostrado antes.** `--accept-data-loss` só com confirmação nominal do que será perdido.
- Backfill sempre nasce com `DRY_RUN` ligado por padrão: imprime contagens e amostra, não escreve. Modo real é opt-in por variável.
- Um PR não remove o campo antigo que ele mesmo deixa de escrever. Contract é PR separado, depois de dias sem leitura do campo (`rg` confirma).
- Nunca edita client gerado. Nunca mistura backfill com mudança de comportamento no mesmo script. Nunca "corrige na mão" no Compass/Atlas: dado corrigido fora de script não tem rastro nem reprodução.
- Toggle default-OFF para dual-write e para leitura do campo novo. Classe de risco `schema` no PR: 2 aprovações e seção Rollout preenchida.

## Fallback

Pré-requisito ausente ou falho (auth expirada, binário faltando, MCP indisponível, `ecossistema.json` inexistente, script com erro) **não encerra a skill**: diga em uma linha o que faltou e como resolver (`! gcloud auth login`, `/onboarding-ecossistema`, instalar a ferramenta), ofereça seguir sem essa parte e, com a aprovação do usuário, prossiga marcando no Output o que ficou **não verificado**. O que não muda: escrita externa (ClickUp, GCP, `git push`, banco) continua exigindo confirmação, e "não verificado" nunca vira "ok".

## Passos

1. **Classificar.**
   ```bash
   bash <skill-dir>/scripts/diff-schema.sh <repo>
   ```
   Saída: campos adicionados (obrigatório × opcional × com default), removidos, renomeados, índices e `@unique` novos ou removidos, enums que perderam valor, models novos. Veredito: `só-schema` (nada de documento existente muda: model novo, campo opcional, índice não único) ou `dados+schema` (algum documento existente precisa mudar antes do schema valer).

2. **Mapear risco por tipo de mudança.**

   | Mudança | Risco no Mongo + Prisma | Caminho seguro |
   |---|---|---|
   | Campo novo obrigatório | documento antigo sem o campo falha ao ser lido pelo client | nasce `?` ou com `@default`; vira obrigatório só quando `count(ausente) = 0` |
   | Enum perde valor | documento com o valor antigo falha ao ser lido | backfill para o valor novo **antes** de mergear o enum estreito |
   | Tipo muda (String → Int, etc.) | idem; `db push` não converte | campo novo com o tipo novo + backfill + troca de leitura + remoção do antigo |
   | Renomear campo | dado não se renomeia sozinho | prefira renomear só no código com `@map("nomeAntigo")`; zero migração de dados |
   | `@unique` em coleção existente | `db push` falha se houver duplicata | conte duplicatas antes (aggregate `$group` + `count > 1`), deduplique por script, depois o índice |
   | Remover campo/model | dado fica órfão mas não quebra leitura | só depois de parar de escrever e de ler (`rg`); PR separado |
   | `null` × ausente | Prisma distingue os dois; filtro por igualdade não pega ausente | no backfill filtre ausente com `isSet: false` (ou `$exists: false` em raw) e `null` separadamente |
   | Transação no backfill | exige replica set; compose local pode ser standalone | não dependa de `$transaction` no script; faça lotes idempotentes |

3. **Expand.** Schema com o campo novo **opcional** (ou `@default`), índice não único se precisar, código escrevendo nos dois lugares atrás de toggle OFF, e o script de backfill commitado no mesmo PR. `prisma generate` + `/rodar-testes` do repositório afetado. Se o repo tiver smoke de módulo, roda.

4. **Backfill.** Escreva o script no molde do repo com estas propriedades, todas verificáveis no código:
   - filtro restritivo: só documentos que ainda precisam mudar (idempotente por construção);
   - lotes por `_id` (500 a 1000), log de contagem por lote, sem carregar a coleção inteira;
   - `DRY_RUN` default: imprime `total a migrar`, amostra de 5 e sai sem escrever;
   - ao final, reconta `restantes` e falha (exit ≠ 0) se não for zero;
   - conexão vinda de env do ambiente alvo, nunca hardcoded; script registrado em `package.json` (`prisma:backfill-<nome>`).
   Execução: local → staging (dry-run, real, recontagem) → produção (backup, dry-run, real, recontagem), cada passo mostrado antes.

5. **Ordem de deploy.** Escreva a sequência explícita, porque é onde se erra:
   1. merge do PR expand → deploy → `db push` (onde o repo o roda; se for manual, é passo nomeado) → toggle de dual-write ON;
   2. backfill em staging, depois produção; recontagem zero;
   3. PR de leitura do campo novo (toggle) → observar;
   4. PR contract: tornar obrigatório / estreitar enum / `@unique` / remover antigo → `db push` de novo (índice). Rollback de código é sempre possível porque o dado continua compatível; rollback de índice único é `db push` do schema anterior.

6. **Plano.** Preencha `templates/plano-migracao.md`. Ele é o texto da classe de risco `schema` e da seção Rollout do PR, e do comentário na task.

## Output

```
Mudança: <o que muda> · veredito: só-schema | dados+schema
Risco: <linha da tabela que se aplica> · documentos afetados: <n (contado em <ambiente>)> | não contado ainda
Expand: <campo/índice + toggle> · Backfill: <script> (dry-run: <n> a migrar) · Contract: <PR futuro>
Ordem: <1→2→3→4 em uma linha>
db push: roda em <CI | cloudbuild | manual: comando> · backup: <script/snapshot> | pendente
Plano: <caminho do arquivo gerado> — pronto para PR (Classe de risco: schema) e para a task
```
