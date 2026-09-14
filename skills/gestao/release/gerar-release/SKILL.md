---
name: gerar-release
description: Gera ou preenche o PR de release entre duas branches com changelog preciso — lista os PRs mergeados (inclusive empilhados, squash e rebase, que não têm merge commit próprio), cruza cada um com a task do ClickUp (descrição e comentários de ambos), e valida no diff quais feature toggles a release introduz, remove ou exige ligar, porque a declaração dos devs nem sempre bate com o código. Use quando o usuário disser "gerar release", "PR de release", "/gerar-release staging main", "release notes", "o que vai nessa release", "changelog da release", "o que está indo pra produção", ou mandar a URL/número de um PR de release já aberto pedindo para "preencher esse PR" (modo preencher: escreve título e corpo direto no PR, sem confirmação). NÃO use para editar o changelog público de um PR isolado (isso se faz no próprio PR) nem para fechar ou reportar uma task (isso é /fechar-task e /reportar-task).
---

# gerar-release

Monta o **PR de release** de `<head>` para `<base>`: o que muda, o changelog e a lista de feature toggles com o estado que cada uma precisa ter. A fonte de verdade do changelog são os PRs e as tasks; a fonte de verdade dos toggles é o **diff**, não o que o PR diz.

**Argumento:** `$ARGUMENTS`, em uma de duas formas:

- `<base> <head>` — ex: `main staging` gera o PR `staging → main`. Se vier só uma branch, pare e peça a outra. **Modo criar.**
- URL ou número de um PR já aberto entre as duas branches (ex.: `https://github.com/org/repo/pull/515`). `gh pr view N --json baseRefName,headRefName,title,body,url,state` dá base, head e o destino do corpo. **Modo preencher.** Se o PR não estiver `OPEN`, avise e vá só até o rascunho.

## Token discipline

- **Scripts antes de leitura.** `scripts/prs-entre-branches.sh` e `scripts/scan-toggles.sh` fazem a varredura; não leia diff nem log à mão.
- **ClickUp: `clickup_get_task` sem `include`** — o default já é resumo (campos grandes vêm como contagem). Só passe `include: ['description']` se o PR tiver corpo vazio ou não explicar o que mudou. `clickup_get_task_comments` devolve todos os comentários sem paginar; o filtro do que importa é de leitura (passo 4), não de API. Não peça `custom_fields`, `attachments` nem `subtasks`.
- **PR:** `gh pr view N --json title,body,headRefName,comments,mergedAt` — não abra o diff do PR; o `scan-toggles.sh` já cobre o que importa dele. Exceção: quando um PR afirma "removi o toggle X" ou "nenhuma tela muda", confira o ponto exato com `git diff <base>...<head> -- <arquivo> | grep`, não lendo o arquivo.
- Leia `conventions.md` **sempre** antes de escrever o changelog — é curto e é onde mora o critério de qualidade.
- Leia `templates/release-pr.md` só na hora de montar o corpo.
- Mais de 15 PRs na release: delegue a coleta de PR+task para um `Explore` com `model: haiku`, um lote por agente, retornando só os campos do passo 4. A síntese fica inline.

## Safe-mode

- **Modo criar: nunca cria o PR sem mostrar o corpo completo e receber confirmação.** O rascunho aparece no terminal primeiro.
- **Modo preencher: autorizado a escrever direto.** Quando o PR de release já existe, aplique com `gh pr edit N --title … --body-file …` sem pedir confirmação (autorização do dono em 14/09/2026). Título genérico ("Release", "Deploy", nome da branch) vira `release: <head> → <base> (<AAAA-MM-DD>) — <resumo em uma linha do que vai>`. No terminal sai só o bloco **Output**, não o corpo.
- Nunca faz merge, nunca faz push para `<base>`, nunca reescreve histórico. Os únicos escritos são `gh pr create` (após confirmação) e `gh pr edit` (modo preencher).
- ClickUp é **somente leitura** aqui. Não comenta, não muda status, não registra tempo.
- Se `<base>` for a branch de produção e o diff tocar `schema.prisma`, o rascunho ganha um aviso destacado de `prisma:gen`/`db push` no deploy — não é bloqueio, é sinalização.

## Passos

1. **Refs e escopo.**
   ```bash
   bash scripts/prs-entre-branches.sh <base> <head>
   ```
   Saída: números de PR mergeados em `<head>` e ausentes em `<base>`, mais commits diretos sem PR (ex.: hotfix). O script une três fontes: merge commits, `gh pr list` casado por SHA (pega **PR empilhado**, que não tem merge commit próprio, e squash) e a API commit→PR (rebase). A seção **"PRs sem merge commit próprio"** vai como nota na tabela de PRs — é o PR que o revisor não vê no `git log --merges`. Se vier vazio, pare: "nada a liberar entre `<head>` e `<base>`". Se o script avisar que `gh` não estava autenticado, confira `git log --oneline <base>..<head>` contra a lista antes de seguir.

2. **Toggles no código — antes de ler qualquer PR**, para não ser influenciado pelo que o dev declarou:
   ```bash
   bash scripts/scan-toggles.sh <base> <head>
   ```
   Guarde a lista: env vars novas e **removidas**, padrões `xEnabled`/`=== 'true'`/`!== 'false'`, mudanças em `.env*` versionados, campos novos de config por tenant no schema. Cobre monorepo (`apps/*/src`). `!== 'false'` é default **ligado** (kill-switch); `=== 'true'` é default desligado. Leitura **removida** (`-`) é toggle removido: entra na tabela como "removido", com o que passa a valer sempre. Cada item vira uma linha na seção de toggles, **mesmo que nenhum PR o mencione**.

3. **Por PR:** `gh pr view N --json title,body,headRefName,comments,mergedAt`. Extraia:
   - IDs de task no título, branch e corpo: regex `[A-Z]{2,6}-[0-9]{2,5}` (ex.: `PROJ-4281`).
   - Seção de toggles do corpo, se houver (`## Feature toggle`, `toggle`, `flag`, `env`).
   - Comentários: só os que mudam escopo ou decisão ("descartado", "fora deste PR", "breaking", "vai em PR próprio"). Ignore aprovação e ruído de CI.
   - PR sem merge commit próprio: confirme o empilhamento no corpo ("empilhado sobre #N", "base = …") e registre na nota da tabela.

   **Checks do PR de release (modo preencher):** `gh pr checks N`. Check vermelho é informação de release: `gh run view <id> --log-failed | tail -60` dá a causa; `git show <base>:<arquivo> | grep <símbolo>` diz se é pré-existente na base (o gate só a expôs) ou regressão desta release. Entra na seção **Deploy** com causa, se bloqueia o merge (o check é obrigatório? `gh api repos/{owner}/{repo}/branches/<base>/protection/required_status_checks`) e o conserto.

4. **Por task do ClickUp** (`clickup_get_task` sem `include`, depois `clickup_get_task_comments`): nome, status, e nos comentários o que **mudou o escopo** em relação à descrição original — é ali que decisões como "não fazer backfill", "remover o toggle em vez de ligar" ou "só um cliente afetado" ficam registradas, e é isso que decide se algo entra no changelog público. Leia também a **data** dos comentários: um reporte de bug em produção *depois* do merge do PR é o item mais importante da release e só aparece aqui. Registre status da task vs. merge (task em "backlog" com PR mergeado é nota na tabela) e pedido de teste em STG por QA. Se a task não existir ou o ID não resolver, registre "sem task" e siga; não invente.

5. **Cruzamento de toggles.** Para cada toggle do passo 2, procure declaração em algum PR do passo 3. Marque:
   - `declarado` — PR explica o que faz e o estado esperado;
   - `NÃO DECLARADO` — está no código e nenhum PR menciona. Vai para o topo da seção, em destaque;
   - `declarado sem código` — PR **ou task** menciona toggle que o diff não tem. Também em destaque: ou o dev errou o nome, ou ficou de fora do merge, ou a task ficou desatualizada em relação ao que foi implementado (comum quando o desenho muda durante a execução);
   - `removido` — a leitura saiu do código; a linha diz o que valia antes e o que vale sempre agora.
   Para cada um, o que faz e o default vêm do **código** (`.env*` de exemplo + o `if` que o lê), não do PR.
   Nem toda `process.env` nova é toggle: `TZ`, `NODE_ENV`, `DATABASE_URL`, `JWT_SECRET`, `API_PORT`, senha de serviço externo são **configuração**, não ramificação de comportamento. Só é toggle o que aparece num `if`/ternário que escolhe entre dois caminhos. Liste as demais numa linha "não são toggles, mas o scan os lista" com o motivo — o leitor precisa saber que foram vistas e descartadas.

6. **Changelog.** Leia `conventions.md` e escreva. Agrupe por área, Breaking primeiro. Uma entrada por mudança de comportamento observável — não por PR, não por commit.

   **Changelog do produto.** Se o repo tem changelog voltado ao usuário (`docs/product/CHANGELOG.md` ou equivalente: `find . -maxdepth 3 -iname 'CHANGELOG*' -not -path '*/node_modules/*'`), veja se `<head>` já tem entrada para esta release. Se não, o PR de release ganha um bloco **pronto para colar**, na voz do arquivo (leia as duas últimas entradas para copiar o tom), e sinaliza que publicar item de segurança é decisão do time. Não edite o arquivo aqui: ele entra por PR próprio em `<head>`.

7. **Rascunho.** Preencha `templates/release-pr.md`.
   - **Modo criar:** imprima no terminal e **pare**. Só continue com "ok"/"pode abrir".
   - **Modo preencher:** grave no scratchpad e aplique de imediato:
     ```bash
     gh pr edit N --title "release: <head> → <base> (<AAAA-MM-DD>) — <resumo>" --body-file <arquivo>
     ```

8. **Abrir (só modo criar).**
   ```bash
   gh pr create --base <base> --head <head> --title "release: <head> → <base> (<data>) — <resumo>" --body-file <arquivo>
   ```
   Retorne a URL.

## Output

```
PR de release: <url> (aberto | preenchido)
<N> PRs, <M> tasks vinculadas, <K> sem task · <J> sem merge commit próprio
Toggles: <a> declarados · <b> NÃO DECLARADOS · <c> declarados sem código · <d> removidos
Breaking: <lista curta ou "nenhum">
Schema alterado: sim/não
Checks do PR: verde | vermelho (<causa em 1 linha; pré-existente na base ou regressão>)
Deploy: <o que sobe sozinho no merge> · <o que é manual>
Ação fora do código: <rotação de credencial, env a criar, check a tornar obrigatório… ou "nenhuma">
```

Se houver toggle `NÃO DECLARADO`, repita a lista logo abaixo — é a informação que o release manager mais precisa e a que mais se perde. Se houver "ação fora do código", repita também: é o que o deploy não resolve.
