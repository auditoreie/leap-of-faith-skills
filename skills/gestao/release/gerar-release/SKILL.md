---
name: gerar-release
description: Gera o PR de release entre duas branches com changelog preciso — lista os PRs mergeados, cruza cada um com a task do ClickUp (descrição e comentários de ambos), e valida no diff quais feature toggles a release introduz, remove ou exige ligar, porque a declaração dos devs nem sempre bate com o código. Use quando o usuário disser "gerar release", "PR de release", "/gerar-release staging main", "release notes", "o que vai nessa release", "changelog da release". NÃO use para editar o changelog público de um PR isolado (isso se faz no próprio PR) nem para fechar ou reportar uma task (isso é /fechar-task e /reportar-task).
---

# gerar-release

Monta o **PR de release** de `<head>` para `<base>`: o que muda, o changelog e a lista de feature toggles com o estado que cada uma precisa ter. A fonte de verdade do changelog são os PRs e as tasks; a fonte de verdade dos toggles é o **diff**, não o que o PR diz.

**Argumento:** `$ARGUMENTS` = `<base> <head>` — ex: `main staging` gera o PR `staging → main`. Se vier só uma branch, pare e peça a outra.

## Token discipline

- **Scripts antes de leitura.** `scripts/prs-entre-branches.sh` e `scripts/scan-toggles.sh` fazem a varredura; não leia diff nem log à mão.
- **ClickUp: `clickup_get_task` sem `include`** — o default já é resumo (campos grandes vêm como contagem). Só passe `include: ['description']` se o PR tiver corpo vazio ou não explicar o que mudou. `clickup_get_task_comments` devolve todos os comentários sem paginar; o filtro do que importa é de leitura (passo 4), não de API. Não peça `custom_fields`, `attachments` nem `subtasks`.
- **PR:** `gh pr view N --json title,body,headRefName,comments,mergedAt` — não abra o diff do PR; o `scan-toggles.sh` já cobre o que importa dele.
- Leia `conventions.md` **sempre** antes de escrever o changelog — é curto e é onde mora o critério de qualidade.
- Leia `templates/release-pr.md` só na hora de montar o corpo.
- Mais de 15 PRs na release: delegue a coleta de PR+task para um `Explore` com `model: haiku`, um lote por agente, retornando só os campos do passo 4. A síntese fica inline.

## Safe-mode

- **Nunca cria o PR sem mostrar o corpo completo e receber confirmação.** O rascunho aparece no terminal primeiro.
- Nunca faz merge, nunca faz push para `<base>`, nunca reescreve histórico. O único push é o `gh pr create`, e só após confirmação.
- ClickUp é **somente leitura** aqui. Não comenta, não muda status, não registra tempo.
- Se `<base>` for a branch de produção e o diff tocar `prisma/schema.prisma`, o rascunho ganha um aviso destacado de `prisma:gen`/`db push` no deploy — não é bloqueio, é sinalização.

## Passos

1. **Refs e escopo.**
   ```bash
   bash scripts/prs-entre-branches.sh <base> <head>
   ```
   Saída: números de PR mergeados em `<head>` e ausentes em `<base>`, mais commits diretos sem PR (ex.: hotfix). Se vier vazio, pare: "nada a liberar entre `<head>` e `<base>`".

2. **Toggles no código — antes de ler qualquer PR**, para não ser influenciado pelo que o dev declarou:
   ```bash
   bash scripts/scan-toggles.sh <base> <head>
   ```
   Guarde a lista: env vars novas/removidas, padrões `Enabled()`/`=== 'true'`, mudanças em `.env.example`, campos novos de config por tenant no schema. Cada item vira uma linha na seção de toggles, **mesmo que nenhum PR o mencione**.

3. **Por PR:** `gh pr view N --json title,body,headRefName,comments,mergedAt`. Extraia:
   - IDs de task no título, branch e corpo: regex `[A-Z]{2,6}-[0-9]{2,5}` (ex.: `HMAXX-4281`).
   - Seção de toggles do corpo, se houver (`## Feature toggle`, `toggle`, `flag`, `env`).
   - Comentários: só os que mudam escopo ou decisão ("descartado", "fora deste PR", "breaking", "vai em PR próprio"). Ignore aprovação e ruído de CI.

4. **Por task do ClickUp** (`clickup_get_task` sem `include`, depois `clickup_get_task_comments`): nome, status, e nos comentários o que **mudou o escopo** em relação à descrição original — é ali que decisões como "não fazer backfill" ou "só um cliente afetado" ficam registradas, e é isso que decide se algo entra no changelog público. Leia também a **data** dos comentários: um reporte de bug em produção *depois* do merge do PR é o item mais importante da release e só aparece aqui. Se a task não existir ou o ID não resolver, registre "sem task" e siga; não invente.

5. **Cruzamento de toggles.** Para cada toggle do passo 2, procure declaração em algum PR do passo 3. Marque:
   - `declarado` — PR explica o que faz e o estado esperado;
   - `NÃO DECLARADO` — está no código e nenhum PR menciona. Vai para o topo da seção, em destaque;
   - `declarado sem código` — PR **ou task** menciona toggle que o diff não tem. Também em destaque: ou o dev errou o nome, ou ficou de fora do merge, ou a task ficou desatualizada em relação ao que foi implementado (comum quando o desenho muda durante a execução).
   Para cada um, o que faz e o default vêm do **código** (`.env.example` + o `if` que o lê), não do PR.
   Nem toda `process.env` nova é toggle: `TZ`, `DATABASE_URL`, `JWT_SECRET`, `API_PORT`, chaves de serviço externo são **configuração**, não ramificação de comportamento. Só é toggle o que aparece num `if`/ternário que escolhe entre dois caminhos. Liste as demais numa linha "não são toggles, mas o scan os lista" com o motivo — o leitor precisa saber que foram vistas e descartadas.

6. **Changelog.** Leia `conventions.md` e escreva. Agrupe por área, Breaking primeiro. Uma entrada por mudança de comportamento observável — não por PR, não por commit.

7. **Rascunho.** Preencha `templates/release-pr.md`, imprima no terminal e **pare**. Só continue com "ok"/"pode abrir".

8. **Abrir.**
   ```bash
   gh pr create --base <base> --head <head> --title "release: <head> → <base> (<data>)" --body-file <arquivo>
   ```
   Retorne a URL.

## Output

```
PR de release: <url>
<N> PRs, <M> tasks vinculadas, <K> sem task
Toggles: <a> declarados · <b> NÃO DECLARADOS · <c> declarados sem código
Breaking: <lista curta ou "nenhum">
Schema alterado: sim/não
```

Se houver toggle `NÃO DECLARADO`, repita a lista logo abaixo — é a informação que o release manager mais precisa e a que mais se perde.
