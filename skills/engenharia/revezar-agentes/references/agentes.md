# Comandos por agente

Leia só a seção do CLI que vai usar. Flags conferidas na ajuda local de cada CLI (Claude Code,
Codex 0.165, Grok 1.0.70, cursor-agent 2026.10). Versões novas mudam flags: se uma falhar, rode
`<cli> --help` antes de improvisar. Itens marcados **(piloto)** não foram provados ponta a ponta;
o passo 5 do `SKILL.md` prova.

`$FICHA` = conteúdo de `templates/ficha.md` preenchida. `$WT` = caminho da worktree do worker.
`$SCHEMA` = `templates/relatorio.schema.json`.

## Orca (caminho padrão quando o Orca está no ar)

| Item | Valor |
|---|---|
| Contas gerenciadas | `orca account list`; `orca account add --agent claude\|codex`; `orca account select --agent <x> --account <email\|rótulo\|system>` (vale para os próximos lançamentos) |
| Sem conta gerenciada | Grok e cursor-agent: `orca terminal create` na worktree e o comando sem interface da seção do CLI, com a conta por variável de ambiente; ou `worker-start --terminal <handle>` |
| Worker | `orca orchestration worker-start --spec-file <ficha> --agent <x> --model <id> --effort <nível> --worktree new-top-level --repo id:<repoId> --name <slug>` (`orca repo list --json` dá o id) |
| Falar com worker | `orca orchestration send --to dispatch:<id> --subject "…" --body "…"`; nunca pelo terminal dele |
| Status | `orca worktree ps`, `orca orchestration task-list`, `orca terminal list` |
| Sessão interativa avulsa | `orca agent launch --agent <x> --model <id> --prompt "…"` |

A supervisão (acordar, `check`, falhas, retomada) segue a skill `orchestration`.

## Degrau pago por token (último recurso, piloto obrigatório)

| Caminho | Quando | Limites |
|---|---|---|
| Claude Code via OpenRouter (`ANTHROPIC_BASE_URL=https://openrouter.ai/api`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY=""`, numa conta `CLAUDE_CONFIG_DIR` separada) | todas as assinaturas Claude no limite e a tarefa exige Claude | só modelos Claude: a Anthropic não suporta o Claude Code com modelo não-Claude por gateway ([llm-gateway](https://code.claude.com/docs/en/llm-gateway)); cobrança por token, sem a assinatura ([guia OpenRouter](https://openrouter.ai/docs/guides/guides/claude-code-integration)) |
| Harness aberto (opencode, Codex com provider custom, Hermes) via OpenRouter | modelo não-Claude barato para tarefa leve/média | perde skills, hooks e CLAUDE.md do Claude Code; captura no ai-memory só se o harness tiver hooks |

Em todos: ZDR ligado em [settings/privacy](https://openrouter.ai/settings/privacy) ou
`"provider": {"zdr": true}`, teto de gasto definido, chave fora da ficha e do histórico do shell.
Cache: o OpenRouter fixa o provedor por sessão (sticky routing); `provider.order` desliga isso e
reduz acertos de cache ([prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching)).

## Claude Code

| Item | Valor |
|---|---|
| Conta | `CLAUDE_CONFIG_DIR=$HOME/.claude-accounts/<conta>` (uma pasta por login) |
| Sem interface | `cd "$WT" && CLAUDE_CONFIG_DIR=… claude -p "$FICHA" --output-format json --model <modelo> --permission-mode acceptEdits --disallowedTools "Bash(git push:*)" "Bash(gh pr:*)" "Read(./.env*)"` |
| Retomar | `claude --continue` na mesma pasta, ou `ai-memory run … claude` |
| Sinal de limite | `You've hit your … limit · resets <hora>` |
| Nunca | `--dangerously-skip-permissions`, `--permission-mode bypassPermissions` |

`--permission-mode acceptEdits` aceita edição de arquivo e mantém o pedido de aprovação para o
resto. O schema do relatório vai no fim da ficha; o Claude não tem flag de schema no `-p`.

## Codex

| Item | Valor |
|---|---|
| Conta | `CODEX_HOME=$HOME/.codex-<conta>` (uma pasta por login; `~/.codex` é a padrão) **(piloto)** |
| Sem interface | `codex exec -C "$WT" --sandbox workspace-write --json --output-schema "$SCHEMA" -o relatorio.json -m <modelo> "$FICHA"` |
| Retomar | `codex resume --last`, ou `ai-memory run … codex` |
| Login | `CODEX_HOME=… codex login status` |
| Nunca | `--dangerously-bypass-approvals-and-sandbox`, `--sandbox danger-full-access` |

## Grok

| Item | Valor |
|---|---|
| Conta | `GROK_HOME=$HOME/.grok-<conta>` **(piloto)** |
| Sem interface | `grok -p "$FICHA" --cwd "$WT" --output-format json --json-schema "$(cat "$SCHEMA")" -m <modelo> --deny "Bash(git push:*)"` |
| Retomar | `grok --continue` na mesma pasta, ou `ai-memory run … grok` |
| Nunca | `--always-approve` |

## cursor-agent

| Item | Valor |
|---|---|
| Conta | `CURSOR_API_KEY` por conta, lido de cofre local; nunca na ficha nem no histórico do shell **(piloto)** |
| Sem interface | `cursor-agent -p --output-format json --workspace "$WT" --sandbox enabled --model <modelo> "$FICHA"` |
| Modelos | `cursor-agent --list-models` |
| Retomar | `cursor-agent --resume`, ou `ai-memory run … cursor` |
| Login | `cursor-agent status` |
| Nunca | `--force`, `--yolo`, `--approve-mcps` |

## ai-memory (todos)

| Item | Valor |
|---|---|
| Linha de trabalho | `ai-memory run --new <workstream> <harness>` (1ª vez), `--workstream <workstream>` (demais) |
| Listar linhas | `ai-memory workstreams` (do checkout atual) |
| Buscar no histórico da linha | `ai-memory workstream-search --workstream-id <id> "<termo>"` |
| Conta fixa | `[run.profiles.<conta>.env]` no `config.toml` + `ai-memory run --profile <conta> <harness>` |
| Recado entre projetos | `ai-memory message send --to-workspace <ws> --to-project <proj> --subject "…"` |
| Nunca | `--yolo`, `--true-yolo`, `--force-unlock` sem confirmar que o lançador anterior morreu |

Sessões sem interface (`-p`, `exec`) passam pelos hooks do ai-memory só se o harness estiver com
hooks instalados (`ai-memory install-hooks --agent <agente>`). Confira no piloto com
`ai-memory recent`.
