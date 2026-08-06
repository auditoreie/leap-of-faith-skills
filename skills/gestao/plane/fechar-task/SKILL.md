---
name: fechar-task
description: Fecha uma task no Plane — grava tempo (worklog), tokens, custo de IA e um comentário de resumo, encerrando o ciclo. Use quando o usuário disser "fechar task", "encerrar a task X", "/fechar-task PROJ-25", "close task". NÃO use para só comentar/reportar sem encerrar (isso é /reportar-task) nem para iniciar (isso é /iniciar-task).
---

# fechar-task

Fecha uma task no Plane: grava tempo, tokens, custo e comentário de resumo.

**Task ID:** `$ARGUMENTS` (ex: `PROJ-25`)

> **Multi-projeto:** nada de ID hardcoded. Resolva o Project ID pelo **prefixo do task ID** (como faz
> `reportar-task`) ou reaproveite o `project_id` já gravado em `/tmp/plane_task_atual.json` pelo
> `/iniciar-task`. **Custo via `ccusage`** (não use taxa fixa por token — varia por
> modelo/input/output/cache). Tempo e custo também podem ir nos campos personalizados nativos
> `Custo IA (US$)` / `Tokens IA` (ver `reportar-task`, passo 7).

## Token discipline

- Só chamadas à API do Plane. **Não** leia o repositório nem rode subagentes pra montar o resumo —
  use o que já está no contexto da sessão.
- Uma listagem de projetos e uma de issues por execução. Não baixe descrição completa a menos que o
  resumo dependa dela.
- Não leia `reportar-task`/`conventions.md` a menos que precise do detalhe de custom fields.

## Safe-mode

- **Confirme o `comment_html` com o usuário antes de postar.** Fechar task é escrita visível pro time.
- Nunca invente tokens nem custo: o número vem do `ccusage`, e você confirma com o usuário antes de
  gravar.
- Nunca faça git (branch/commit/push) — a skill lembra o padrão do PR, não o executa.
- Só apague `/tmp/plane_task_atual.json` depois que as escritas na API tiverem retornado sucesso.

Siga estes passos na ordem:

1. Leia o arquivo `/tmp/plane_task_atual.json` para pegar o horário de início, o `project_id` e
   confirmar o task ID.

2. Leia config e API Key pessoal de `~/.claude/plane_config.json` (nunca hardcode):

```bash
CFG=~/.claude/plane_config.json
API_KEY=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('$CFG')))['api_key'])")
WORKSPACE=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('$CFG')))['workspace'])")
```

3. Calcule o tempo decorrido em minutos (do `start_time` até agora).

4. Pergunte ao usuário:
   - "Quantos tokens Claude foram usados nesta sessão? (rode `ccusage` no terminal — ele já dá o custo em USD por modelo)"
   - "Qual o link do PR no GitHub? (opcional)"
   - "Resumo rápido do que foi feito: (opcional, senão eu gero)"

5. Com os dados coletados, use a REST API do Plane (via Bash com `curl`) para:

   **a. Criar Work Log (tempo)** — `duration` é **inteiro em minutos** (não use `"90m"`):

   ```bash
   curl -s -X POST -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
     -d "{\"description\": \"Sessão Claude Code\", \"logged_by\": \"claude-code\", \"duration\": <MINUTOS>}" \
     "https://api.plane.so/api/v1/workspaces/$WORKSPACE/projects/<PROJECT_ID>/issues/<ISSUE_ID>/worklogs/"
   ```

   **b. Custo e tokens** — pegue o custo USD já calculado do `ccusage` (não multiplique por taxa fixa). Registre no comentário e, se quiser, nos campos `Custo IA (US$)` / `Tokens IA`.

   **c. Adicionar comentário com resumo** — campo obrigatório `comment_html`:

   ```
   POST https://api.plane.so/api/v1/workspaces/$WORKSPACE/projects/<PROJECT_ID>/issues/<ISSUE_ID>/comments/
   ```
   Corpo: resumo técnico + link do PR + tokens + custo IA.

6. Apague o arquivo `/tmp/plane_task_atual.json`.

Confirme para o usuário:

```
✓ Work Log gravado: <X> minutos
✓ Tokens Claude: <tokens>
✓ Custo IA: US$ <valor>
✓ Comentário adicionado com resumo
```

Lembre de abrir o PR com o padrão no título: `$ARGUMENTS: descrição`.

> **Notas de API:** use `curl` (não `python urllib` — Cloudflare bloqueia com `403 error code: 1010`).
> Workspace e API Key saem de `~/.claude/plane_config.json` (cada dev usa a própria); Project ID e
> Issue ID são resolvidos em runtime. **Nunca** commite chave nem cole ID de workspace de cliente aqui.
