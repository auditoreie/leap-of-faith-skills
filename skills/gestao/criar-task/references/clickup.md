# ClickUp — de onde vêm os IDs e como chamar

Nenhum ID mora aqui. Tudo vem de `<raiz>/.claude/ecossistema.json` → `tracker`, impresso por `scripts/ecossistema.sh`:

| Campo da config | Uso |
|---|---|
| `workspace_id` | vai em **toda** chamada `clickup_*` (contas com mais de um workspace recebem "Multiple workspaces available" sem ele) |
| `list_id`, `list_nome` | destino fixo da criação |
| `folder_id` (ou `space_id`) | escopo da busca de duplicata: o folder inteiro, porque duplicata de outro time também conta |
| `prefixo_task` | custom ID (`PREFIXO-NNNN`); alimenta `TASK_PREFIX` do `pre-triagem.sh` |
| `status_inicial` | normalmente o default da lista; só passe `status` se o usuário pedir outro |
| `campos.<nome>.id/tipo/opcoes` | campos personalizados que a skill preenche; `repos[].campos.<nome>` diz a opção de cada repo |

Formato de valor por tipo (`clickup_create_task.custom_fields[].value` é sempre string): `labels` → `"[\"<uuid>\"]"`; `drop_down` → `"<uuid>"`; `text`/`url` → o valor.

## Buscar duplicata (passo 3)

```
clickup_search
  workspace_id: "<workspace_id>"
  keywords: "<2-3 palavras-chave da demanda>"
  count: 8
  filters: { asset_types: ["task"], location: { categories: ["<folder_id>"] }, task_statuses: ["unstarted", "active"] }
  sort: [{ field: "updated_at", direction: "desc" }]
```
≈ 250 tokens por resultado. Vazio e nome de negócio ≠ nome técnico → repita uma vez com o sinônimo. Candidata: `clickup_get_task task_id` **sem `include`** (≈ 1k tokens); `include: ["description"]` só se o nome não bastar. Cruze o `custom_id` com os IDs que o `pre-triagem.sh` achou nos PRs.

## Resolver assignee (passo 6)

```
clickup_resolve_assignees   workspace_id: "<workspace_id>"   assignees: ["me"]               # "pra mim"
clickup_resolve_assignees   workspace_id: "<workspace_id>"   assignees: ["<nome ou e-mail>"]
```
Vazio → pare e peça o nome exato. Se a busca de duplicata já trouxe o id numérico da pessoa (campo `assignees[].id`), reutilize.

## Criar (passo 6)

```
clickup_create_task
  workspace_id: "<workspace_id>"
  list_id: "<list_id>"
  name: "<título: ação + objeto específico + resultado>"
  markdown_description: "<corpo de templates/task.md preenchido, sem o cabeçalho local>"
  assignees: ["<id numérico>"]
  custom_fields: [ { id: "<campos.produto.id>", value: "[\"<opção do repo>\"]" }, { id: "<campos.escopo_deploy.id>", value: "<opção do repo>" }, { id: "<campos.tipo_report.id>", value: "<Erro|Melhoria|Suporte → uuid>" } ]
  priority: "<só se o usuário disser: urgent | high | normal | low>"
  parent: "<id da task pai, só em subtask>"
```
Resposta: `task_id` (curto), `custom_id`, `task_url`. Devolva como link markdown com o título como texto, nunca URL solta. Relação confirmada com task existente → `clickup_add_task_link` com os dois ids.

## Sem config (fallback)

`clickup_get_list list_name: "<nome que o usuário deu>"` devolve id, statuses e space (1 chamada). Folder para busca: use `space_id` em `location.projects` se não souber o folder. Campos personalizados: não preencha; registre no Output "campos não preenchidos (sem config)" e sugira `/onboarding-ecossistema`.
