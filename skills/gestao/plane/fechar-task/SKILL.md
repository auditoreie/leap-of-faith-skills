---
name: fechar-task
description: Fecha uma task no Plane — grava tempo (worklog), tokens, custo de IA e um comentário de resumo, encerrando o ciclo. Use quando o usuário disser "fechar task", "encerrar a task X", "/fechar-task SINTE-25", "close task". NÃO use para só comentar/reportar sem encerrar (isso é /reportar-task) nem para iniciar (isso é /iniciar-task).
---

# fechar-task

Fecha uma task no Plane: grava tempo, tokens, custo e comentário de resumo.

**Task ID:** `$ARGUMENTS`

> ⚠️ **Multi-projeto:** os IDs fixos abaixo são do piloto SINTE. Para outros projetos resolva o Project ID pelo prefixo do ID (como `reportar-task`). **Custo via `ccusage`** (não use taxa fixa por token — varia por modelo/input/output/cache). Tempo e custo também podem ir nos campos personalizados nativos `Custo IA (US$)` / `Tokens IA` (ver `reportar-task`, passo 7).

Siga estes passos na ordem:

1. Leia o arquivo `/tmp/plane_task_atual.json` para pegar o horário de início e confirmar o task ID.

2. Leia sua API Key pessoal de `~/.claude/plane_config.json` (nunca hardcode):

```bash
API_KEY=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/plane_config.json')))['api_key'])")
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
     "https://api.plane.so/api/v1/workspaces/sintetizaai/projects/<PROJECT_ID>/issues/<ISSUE_ID>/worklogs/"
   ```

   **b. Custo e tokens** — pegue o custo USD já calculado do `ccusage` (não multiplique por taxa fixa). Registre no comentário e, se quiser, nos campos `Custo IA (US$)` / `Tokens IA`.

   **c. Adicionar comentário com resumo** — campo obrigatório `comment_html`:

   ```
   POST https://api.plane.so/api/v1/workspaces/sintetizaai/projects/<PROJECT_ID>/issues/<ISSUE_ID>/comments/
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

> **Notas de API:** use `curl` (não `python urllib` — Cloudflare bloqueia com 403/1010). IDs do piloto SINTE: Project `1fd6fb19-159b-4945-90fb-ffaa24c2d37c`, Workspace `sintetizaai`. API Key lida de `~/.claude/plane_config.json` (cada dev usa a própria).
