# Comandos por agente

Leia só a seção do CLI que vai usar. Flags conferidas na ajuda local de cada CLI (Claude Code,
Codex 0.165, Grok 1.0.70, cursor-agent 2026.10, ai-memory 3.4.4, Orca). Versões novas mudam flags:
se uma falhar, rode `<cli> --help` antes de improvisar. Itens marcados **(piloto)** não foram
provados ponta a ponta; o passo 6 do `SKILL.md` prova. Piloto sem jail em 10/11/2026: Codex
(default), Claude (auditore) e cursor-agent aprovados (conta certa, escrita só na worktree, gate por
`revezar slot`, relatório no schema); Grok aguarda login (`revezar login grok default`).

`$FICHA` = conteúdo de `templates/ficha.md` preenchida. `$WT` = caminho da worktree do worker.
`$SCHEMA` = `templates/relatorio.schema.json`. `$REL` = `$HOME/.cache/revezar/<slug>-<AAAAMMDD-HHMM>.json`,
um por execução (fora da worktree: não entra em commit, não colide, não se confunde com execução antiga).
Antes do primeiro worker: `mkdir -p "$HOME/.cache/revezar"`.

**Worker sem interface, na conta certa** (os comandos das seções abaixo entram como argumentos
nativos depois do `--`; o `ai-memory run` pode escrever linhas de configuração antes da resposta,
por isso o relatório vai da primeira linha que começa com `{` até o fim, e só aparece como `$REL` quando o worker termina bem;
com argumentos nativos o `revezar` passa `--no-exit-prompt`; `--jail` só com o ai-jail instalado, e
então obrigatório):

```bash
revezar [--jail] <agente> <conta> <workstream> -- <argumentos nativos do CLI> > "$REL.log" \
  && sed -n '/^{/,$p' "$REL.log" > "$REL" || mv "$REL.log" "$REL.falhou"
```

Worker sem interface sempre em linha de trabalho **nova** (`<TASKID>-<slug>-<HHMM>`): numa linha
existente o ai-memory retoma a sessão anterior (o Codex vira `exec resume`, que recusa `-C`,
`--sandbox` e `--add-dir`), e o `revezar` recusa. **(piloto)** argumentos nativos dentro do jail.

## Conta (todos)

Ninguém digita variável de ambiente: `revezar` (`scripts/revezar.sh`) acha as contas pelas pastas
abaixo e passa a certa ao agente.

| Agente | Pasta por conta | Criar e logar |
|---|---|---|
| claude | `~/.claude-accounts/<conta>` (`~/.claude` = default) | `revezar login claude <conta>` |
| codex | `~/.codex-<conta>` (`~/.codex` = default) **(piloto)** | `revezar login codex <conta>` |
| grok | `~/.grok-<conta>` (`~/.grok` = default, ou `GROK_HOME`) **(piloto)** | `revezar login grok <conta>` |
| cursor-agent | uma conta por máquina | `cursor-agent login` |

Todo worker abre num terminal por `revezar [--jail] <agente> <conta> <workstream>` (conta certa;
isolado no ai-jail quando instalado). cursor-agent tem uma conta por máquina, por desenho do CLI: a troca de conta
dele é por `cursor-agent login`.

## Orca (caminho padrão quando o Orca está no ar)

| Item | Valor |
|---|---|
| Worker | `orca terminal create --worktree path:$WT --command "revezar [--jail] <agente> <conta> <workstream>" --json` e, com o handle, `orca orchestration worker-start --terminal <handle> --worktree path:$WT --spec-file <ficha> --name <slug>` **(piloto)** |
| Sessão interativa sua | Claude e Codex pela tela de contas do Orca (`orca account select`) e `orca agent launch`; não é worker, não precisa de jail |
| Falar com worker | `orca orchestration send --to dispatch:<id> --subject "…" --body "…"`; nunca pelo terminal dele |
| Status | `orca worktree ps`, `orca orchestration task-list`, `orca terminal list` |

A supervisão (acordar, `check`, falhas, retomada) segue a skill `orchestration`. O `worker-start`
não recebe flag de schema: o schema vai sempre no fim da ficha.

## Degrau pago por token (último recurso, piloto obrigatório)

| Caminho | Quando | Limites |
|---|---|---|
| Claude Code via OpenRouter (`ANTHROPIC_BASE_URL=https://openrouter.ai/api`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY=""`, numa conta `~/.claude-accounts/openrouter` separada) | todas as assinaturas Claude no limite e a tarefa exige Claude | só modelos Claude: a Anthropic não suporta o Claude Code com modelo não-Claude por gateway ([llm-gateway](https://code.claude.com/docs/en/llm-gateway)); cobrança por token, sem a assinatura ([guia OpenRouter](https://openrouter.ai/docs/guides/guides/claude-code-integration)) |
| Harness aberto (opencode, Codex com provider custom, Hermes) via OpenRouter | modelo não-Claude barato para tarefa leve/média | perde skills, hooks e CLAUDE.md do Claude Code; captura no ai-memory só se o harness tiver hooks |

Em todos: ZDR ligado em [settings/privacy](https://openrouter.ai/settings/privacy) ou
`"provider": {"zdr": true}`, teto de gasto definido, chave fora da ficha e do histórico do shell.
Cache: o OpenRouter fixa o provedor por sessão (sticky routing); `provider.order` desliga isso e
reduz acertos de cache ([prompt caching](https://openrouter.ai/docs/guides/best-practices/prompt-caching)).

## Segredos (todos)

- Bloqueio de leitura por regra do CLI (`--disallowedTools "Read(./.env*)"`, `--deny`) não cobre
  subprocesso: `cat .env` por Bash passa.
- A sandbox dos CLIs limita escrita, não leitura: no Codex, `workspace-write` lê fora da worktree,
  inclusive o `.env` do checkout original.
- Por isso: worktree de worker sem segredo (`git worktree add` não copia arquivo ignorado) e, quando
  instalado, worker isolado no ai-jail (`revezar --jail`; home privado, `sandbox-exec` no macOS;
  [ai-jail](https://github.com/akitaonrails/ai-jail), GPL-3.0, "not 100% secure"). Instalar:
  `brew tap akitaonrails/tap && brew install ai-jail`.
- Sem ai-jail (adiado, risco aceito): o worker lê qualquer arquivo do seu usuário. Vale o limite de
  tarefa do safe-mode do `SKILL.md`.
- Com ai-jail, o piloto prova com uma isca fora da worktree: a leitura tem que ser negada.

## Sem Orca: acompanhar e recolher

- `$REL.log` sem `$REL` = em andamento; `$REL` = terminou bem; `$REL.falhou` = saiu com erro.
  `ls -t $HOME/.cache/revezar/` mostra o estado de cada execução.
- Em andamento: `ai-memory recent` (sessões capturadas) e o terminal do próprio worker.
- Recolher = ler o `$REL`, validar contra o schema e seguir o passo 5.4 do `SKILL.md`. Worker sem
  relatório e sem atividade no `ai-memory recent` há mais de 30 min: olhe o terminal dele antes de
  relançar.

## Claude Code

| Item | Valor |
|---|---|
| Argumentos nativos | `-p "$FICHA" --output-format json --model <modelo> --permission-mode acceptEdits --allowedTools "Bash(revezar slot:*)" --disallowedTools "Bash(git push:*)" "Bash(gh pr:*)"` (rodar de dentro de `$WT`; sem o `--allowedTools` o `-p` nega o gate) |
| Relatório | a saída JSON do `-p` embrulha a resposta: o relatório é o texto do campo `result`. Extraia (`jq -r '.result \| .[index("{"):rindex("}")+1]' "$REL"`: tira texto e bloco de código em volta) e só então valide contra o schema |
| Retomar | `claude --resume <session_id>` (o `session_id` está na mesma saída JSON); `--continue` pega a sessão mais recente da pasta e pode ser outra |
| Sinal de limite | `You've hit your … limit · resets <quando>` |
| Nunca | `--dangerously-skip-permissions`, `--permission-mode bypassPermissions` |

`--permission-mode acceptEdits` aceita edição de arquivo e mantém o pedido de aprovação para o
resto. O Claude não tem flag de schema no `-p`; o schema vai no fim da ficha.

## Codex

| Item | Valor |
|---|---|
| Argumentos nativos | `exec -C "$WT" --sandbox workspace-write --add-dir "$HOME/.cache/revezar/slots" --output-schema "$SCHEMA" -m <modelo> "$FICHA"` (a mensagem final, já no schema, sai no stdout, às vezes em várias linhas; sem `--add-dir` o `slot.sh` não grava a vaga) |
| Retomar | `codex resume <id>` (ou `--last` se só houver uma sessão na pasta) |
| Login | `revezar status` (usa o código de saída de `codex login status`) |
| Nunca | `--dangerously-bypass-approvals-and-sandbox`, `--sandbox danger-full-access` |

`workspace-write` lê qualquer arquivo da worktree: por isso a worktree não tem segredo.

## Grok

| Item | Valor |
|---|---|
| Argumentos nativos | `-p "$FICHA" --cwd "$WT" --output-format json --json-schema "$(cat "$SCHEMA")" -m <modelo> --deny "Bash(git push:*)"` **(piloto)** |
| Retomar | `revezar grok <conta> <workstream>` |
| Nunca | `--always-approve` |

## cursor-agent

| Item | Valor |
|---|---|
| Argumentos nativos | `-p --output-format json --trust --workspace "$WT" --sandbox enabled --model <modelo> "$FICHA"` (`--trust` só confia na worktree; sem ele o `-p` para pedindo confirmação) |
| Relatório | igual ao Claude: o JSON vem dentro de `.result`, às vezes depois de texto; mesmo `jq` |
| ai-memory | o `ai-memory run` não tem harness cursor: o `revezar` abre o cursor-agent direto, sem linha de trabalho e sem `--jail`; captura só com `ai-memory install-hooks --agent cursor --apply` |
| Modelos | `cursor-agent --list-models` |
| Retomar | `cursor-agent --resume <id>`, ou `revezar cursor-agent default` (sessão nova) |
| Login | `cursor-agent status` |
| Nunca | `--force`, `--yolo`, `--approve-mcps` |

## ai-memory (todos)

| Item | Valor |
|---|---|
| Abrir na conta e linha certas | `revezar` (menu) ou `revezar <agente> <conta> <workstream>`; por baixo: `ai-memory run --env <PASTA>=… --workstream <ws> <harness> "<ler o bastão>"` |
| Listar linhas | `ai-memory workstreams` (do checkout atual; `--json` para script) |
| Buscar no histórico da linha | `ai-memory workstream-search --workstream-id <id> "<termo>"` |
| Recado entre projetos | `ai-memory message send --to-workspace <ws> --to-project <proj> --subject "…"` |
| Nunca | `--yolo`, `--true-yolo`, `--force-unlock` sem confirmar que o lançador anterior morreu |

Sessões sem interface (`-p`, `exec`) passam pelos hooks do ai-memory só se o harness estiver com
hooks instalados (`ai-memory install-hooks --agent <agente>`). Confira no piloto com
`ai-memory recent`.
