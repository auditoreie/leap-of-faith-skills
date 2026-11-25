---
name: criar-task
description: Faz o discovery, valida e cria uma task no ClickUp do ecossistema configurado — enquadra em qual repo/produto a demanda nasce (pergunta quando há dúvida), lê o harness do repo (CLAUDE.md, ADRs, docs) em vez de inferir, faz pré-triagem no código atualizado (PR aberto, branch, task duplicada), esclarece ambiguidades com perguntas objetivas ancoradas em evidência, projeta a task localmente e só então cria na lista configurada, com assignee, devolvendo o link. IDs, repos e campos vêm de `<raiz>/.claude/ecossistema.json` (gerado por /onboarding-ecossistema); sem config, pergunta o mínimo e segue com aprovação. Use quando o usuário disser "criar task", "abrir task no ClickUp", "task pro <produto>", "/criar-task <demanda>", "create a ClickUp task". NÃO use para task local sem ClickUp (isso é project-ledger `task new`), para escrever spec longa (/spec), para tasks do Plane (/iniciar-task) nem para PR de release (/gerar-release).
---

# criar-task

Transforma uma demanda em uma task **validada contra o código e o harness** do repo certo, e a cria na lista configurada do ecossistema. A skill pergunta antes de inferir: o contexto está no `CLAUDE.md`, nos ADRs e nos docs do repo, não na cabeça do modelo.

**Argumento:** `$ARGUMENTS` — a demanda em texto livre, um link (PR, task, tópico) ou os dois. Vazio → pergunte o que precisa mudar e para quem (efeito observável) antes de qualquer leitura.

`<skill-dir>` é a pasta desta `SKILL.md`.

## Ecossistema (passo 0)

```bash
bash <skill-dir>/scripts/ecossistema.sh            # sobe a partir do cwd até achar <raiz>/.claude/ecossistema.json
```
Saída: `RAIZ`, IDs do tracker (workspace, space, folder, lista, prefixo de task, status inicial), campos personalizados com opções, caminho de `produtos.md` e a lista de repos (caminho, nome, branch de integração, opções de campo por repo). Tudo que os passos abaixo chamam de "config" vem daqui. Exit 3 → ver Fallback.

## Token discipline

- Leia `<RAIZ>/.claude/ecossistema/produtos.md` **sempre**, no passo 1 (roteamento entre repos e caminhos do harness). `references/clickup.md` só nos passos 3 e 6. `references/perguntas.md` só no passo 4. `templates/task.md` só no passo 5.
- IDs do ClickUp vêm da config. Não chame `clickup_get_workspace_hierarchy`, `clickup_get_list` nem `clickup_get_custom_fields` quando a config existir; isso é trabalho do onboarding.
- Harness: `CLAUDE.md` do repo via `grep -n` nas seções que a demanda toca; índice de ADRs e no máximo **3 ADRs** por palavra-chave. Nunca varra a codebase "pra entender o contexto".
- Código: `git grep -n` com 2-3 palavras-chave, depois `sed -n` no entorno. Mais de 3 módulos: `Explore` com `model: haiku` (só leitura, sem testes, sem build, sem background), síntese inline.
- Git/GitHub: `scripts/pre-triagem.sh` faz a varredura (`TASK_PREFIX=<prefixo>` estreita o regex de IDs); não leia `git log` nem `gh pr list` à mão.
- ClickUp: `clickup_search` com `count ≤ 8` e filtro de folder; `clickup_get_task` só em candidata a duplicata, sem `include`. Nunca `clickup_filter_tasks` sem `list_ids`.

## Safe-mode

- **Nunca cria a task sem mostrar o rascunho completo (título, descrição, campos, assignee) e receber "ok"/"pode criar"**, salvo autorização explícita dada antes na mesma conversa.
- Git é somente leitura: o script faz `fetch`; nunca `checkout`, `pull`, branch, commit ou push. Checkout atrás de `origin/<integração>` → leia via `git show origin/<int>:<arquivo>` e `git grep <padrão> origin/<int> -- <path>`.
- ClickUp: o único write é `clickup_create_task` (mais `clickup_add_task_link` quando o usuário confirmar relação). Sem comentário, sem mudança de status, sem mover, sem deletar.
- Toda referência na descrição (arquivo:linha, ADR, PR, task) foi **aberta nesta sessão**. Se o script ou a busca falhou, a descrição diz "não verificado", nunca "não há".
- Assignee sempre nomeado pelo usuário ou confirmado; nunca por dedução.

## Fallback

Pré-requisito ausente ou falho **não encerra a skill**: diga em uma linha o que faltou e como resolver, ofereça seguir sem essa parte e, com a aprovação do usuário, prossiga marcando no Output o que ficou **não verificado**.

| Faltou | Diga e ofereça |
|---|---|
| `ecossistema.json` (exit 3) | "Sem config do ecossistema. Rodo `/onboarding-ecossistema` agora, ou você me passa a lista do ClickUp (nome ou id) e o repo?" Com o nome, `clickup_get_list list_name` resolve o id (1 chamada, permitida só neste caso). |
| `gh` sem auth ou ausente | Pré-triagem de PR "não verificada"; segue com branches e commits locais. |
| MCP do ClickUp indisponível | Projeta e salva o rascunho local com o payload de `clickup_create_task` pronto; criação fica para quando o MCP voltar. |
| Repo sem `CLAUDE.md`/ADRs | Registra "harness ausente" na descrição e pergunta as convenções mínimas (branch, testes). |

Escrita externa continua exigindo confirmação. "Não verificado" nunca vira "ok".

## Passos

1. **Enquadrar produto e repo.** Leia `produtos.md` e classifique a demanda pela tabela de roteamento dele.
   - Sinais para **um** repo → siga e diga qual e por quê, em uma linha.
   - Sinais para **dois** repos, nenhum, ou a demanda atravessa um contrato entre produtos (webhook, DTO de API, toggle compartilhado, conforme `produtos.md`) → **pergunte** com `AskUserQuestion` (opções: cada repo; "duas tasks coordenadas, uma por repo").
   - `$ARGUMENTS` com `<PREFIXO>-NNNN` ou URL de task é **refinamento**: `clickup_get_task` (sem `include`) e pergunte se atualiza aquela task, vira subtask (`parent`) ou task nova.

2. **Contexto do harness** do repo escolhido: `CLAUDE.md` (grep das seções relevantes), índice de ADRs e até 3 ADRs por palavra-chave, docs de domínio listados em `produtos.md`. Anote **status do ADR** (implementar sobre "Proposto" é bloqueio a registrar) e toggles existentes na área.

3. **Pré-triagem no código e no board.**
   ```bash
   TASK_PREFIX=<prefixo> bash <skill-dir>/scripts/pre-triagem.sh <RAIZ>/<repo> "<kw negócio>" "<kw técnica>" ["<kw3>"]
   ```
   Em paralelo, `clickup_search` (`references/clickup.md`, "Buscar duplicata") pelas mesmas palavras no folder da config, status `unstarted`/`active`.
   - Tudo zerado → registre "sem PR/task/branch relacionada em <data>" e siga.
   - Achou algo → mostre (número, título, autor, estado) e **pergunte**: já resolve (parar), resolve parte (referenciar), ou é a mesma coisa (atualizar a existente). PR aberto do mesmo tema por outro autor não se sobrepõe sem confirmação.
   - Localize no código o ponto que a demanda toca (`git grep`) e leia o entorno.

4. **Discovery.** Leia `references/perguntas.md`. Só pergunte o que código, harness e `$ARGUMENTS` **não** respondem. `AskUserQuestion` com 2-3 perguntas por rodada, opções ancoradas em evidência, máximo 3 rodadas; o resto vira "Decisões pendentes" com dono. Separe decisão do usuário, sugestão sua e pendência.

5. **Projetar localmente.** Preencha `templates/task.md`, salve em `<repo>/.claude/tasks/open/<AAAA-MM-DD>-<slug>.md` (confirme que a pasta está no `.gitignore`; senão use o scratchpad). Rubrica de `perguntas.md` → veredito **PRONTA** · **PRECISA DECISÃO** · **BLOQUEADA**. Task de tipo Erro leva **Impacto (usuário)** (`references/qa-impacto.md`). Título: **ação + objeto específico + resultado/critério**. Mostre e **pare**, salvo autorização prévia.

6. **Criar no ClickUp** (`references/clickup.md`, "Criar"): assignee resolvido (`clickup_resolve_assignees`; "pra mim" = `me`; sem nome, pergunte), `list_id` da config, `markdown_description` do rascunho, `custom_fields` conforme o mapeamento do repo na config, status default salvo pedido. Relação confirmada → `clickup_add_task_link`. Grave URL e `custom_id` no rascunho local.

## Output

```
Task criada: [<PREFIXO>-NNNN — <título>](<url>)
Lista: <list_nome> · Status: <status> · Assignee: <nome> · Campos: <produto> · <escopo> · <tipo>
Repo: <caminho> · base analisada: origin/<int> @ <sha curto> (<data>) · rascunho: <arquivo>
Pré-triagem: PRs abertos: <#N título | nenhum | não verificado> · tasks: <IDs | nenhuma> · branches: <… | nenhuma>
Veredito: PRONTA | PRECISA DECISÃO (<itens com dono>) | BLOQUEADA (<motivo>)
Próximo passo: git worktree add ../wt-<slug> -b <feat|fix>/<slug>_<PREFIXO>-NNNN origin/<int>
```

Com **BLOQUEADA** ou **PRECISA DECISÃO**, repita os itens logo abaixo.
