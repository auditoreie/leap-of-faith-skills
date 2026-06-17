---
name: reportar-task
description: Posta um report (comentário) numa work item do Plane, opcionalmente com link de PR, worklog de tempo, custo de tokens (via ccusage) e/ou mudança de estado — mas NÃO encerra a task e não depende do cronômetro de /iniciar-task. Resolve o projeto pelo prefixo do ID, então funciona em qualquer projeto do workspace (ATLASEDUCA-1, VEGA-12, SINTE-25, etc.). Use quando o usuário disser "reportar na task", "comentar na task X", "registrar o PR na task", "logar tempo na task sem fechar", "atualizar a task no Plane sem fechar", "report on task", "add a comment to the Plane issue". NÃO use para iniciar trabalho (isso é /iniciar-task) nem para o encerramento formal da task com mudança pra concluída (isso é /fechar-task).
---

# reportar-task

Posta um **comentário de report** numa work item do Plane via REST API. É a operação leve do meio do fluxo: registrar progresso, anexar um PR, opcionalmente **logar tempo (worklog) e custo de tokens** — tudo **sem encerrar** a task e sem depender do cronômetro de `/iniciar-task`.

**Task ID:** `$ARGUMENTS` (ex: `ATLASEDUCA-1`). Pode vir seguido de flags/intenção (ver Opções).

## Token discipline

- **Não** leia o repositório nem rode subagentes. Esta skill é só chamadas à API do Plane.
- Liste projetos **uma vez** por execução (pra resolver o Project ID) e só os campos `identifier`/`id`.
- Ao buscar a issue, traga `per_page=100` e filtre pelo `sequence_id` localmente; não baixe descrição completa a menos que precise montar o report.
- Não leia `conventions.md`/templates a menos que o usuário peça formato específico.

## Safe-mode

- **Nunca** poste comentário, mude estado ou faça qualquer escrita sem o conteúdo do report definido e confirmado com o usuário. Mostre o `comment_html` que vai enviar antes de postar.
- Mudança de estado é **opt-in** (só com `--state` ou pedido explícito). Por padrão, NÃO altera o estado da issue.
- Nunca faça git, nunca delete nada.

## Passos

1. **API Key** (nunca hardcode):
   ```bash
   API_KEY=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/plane_config.json')))['api_key'])")
   ```

2. **Resolver o projeto pelo prefixo do ID.** Separe `$ARGUMENTS` em `PREFIX-SEQ` (ex: `ATLASEDUCA-1` → prefixo `ATLASEDUCA`, seq `1`). Busque o Project ID cujo `identifier == PREFIX`:
   ```bash
   PROJECT_ID=$(curl -s -H "X-API-Key: $API_KEY" \
     "https://api.plane.so/api/v1/workspaces/sintetizaai/projects/" \
     | python3 -c "import sys,json;d=json.load(sys.stdin);r=d.get('results',d) if isinstance(d,dict) else d;print(next((p['id'] for p in r if p.get('identifier')=='$PREFIX'),''))")
   ```
   Se vier vazio, pare e mostre os identifiers disponíveis — não chute.

3. **Achar a issue pelo `sequence_id`:**
   ```bash
   ISSUE_ID=$(curl -s -H "X-API-Key: $API_KEY" \
     "https://api.plane.so/api/v1/workspaces/sintetizaai/projects/$PROJECT_ID/issues/?per_page=100" \
     | python3 -c "import sys,json;d=json.load(sys.stdin);r=d.get('results',d) if isinstance(d,dict) else d;print(next((i['id'] for i in r if i.get('sequence_id')==$SEQ),''))")
   ```
   Vazio → a issue não está na primeira página (pagine com `?cursor=`) ou o ID está errado. Avise.

4. **Montar o report.** Se o usuário deu o texto, use-o. Senão, gere um resumo técnico curto do que foi feito nesta sessão (mudanças + link do PR, se houver). O campo obrigatório é `comment_html` (HTML simples: `<p>`, `<ul><li>`, `<a href>`). **Mostre ao usuário e confirme antes de postar.**

5. **Postar o comentário:**
   ```bash
   curl -s -X POST -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
     -d "{\"comment_html\": \"<HTML>\"}" \
     "https://api.plane.so/api/v1/workspaces/sintetizaai/projects/$PROJECT_ID/issues/$ISSUE_ID/comments/"
   ```

6. **(Opcional, opt-in) Worklog de tempo.** Só com `--time <min>`. Cria um worklog no **timesheet nativo** da issue — **não** fecha a task, e os worklogs **somam** (pode haver vários por issue). `duration` é um **inteiro em minutos** (não use `"87m"` — a API rejeita com `A valid integer is required`):
   ```bash
   curl -s -X POST -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
     -d "{\"description\": \"Sessão Claude Code\", \"logged_by\": \"claude-code\", \"duration\": <MIN>}" \
     "https://api.plane.so/api/v1/workspaces/sintetizaai/projects/$PROJECT_ID/issues/$ISSUE_ID/worklogs/"
   ```

7. **(Opcional, opt-in) Mudar estado.** Só se pedido (`--state "<nome>"`): liste estados (`.../projects/$PROJECT_ID/states/`), case o nome, e faça `PATCH .../issues/$ISSUE_ID/ {"state":"<state_id>"}`.

## Tempo e custo de tokens

O Plane **não tem** campo nativo de tokens/custo — eles entram **no corpo do comentário** (passo 4). Tempo é separado e nativo (worklog, passo 6).

- **Custo via `ccusage` (NÃO use taxa fixa por token).** A tarifa varia por modelo (Opus ≫ Sonnet) e por input/output/cache. Rode no terminal e leia o custo em USD já calculado:
  ```bash
  ccusage   # ou: npx ccusage@latest
  ```
  Pegue tokens + custo USD da sessão/dia correspondente. **Confirme o valor com o usuário** antes de escrever no comentário (não invente número, não estime de memória).
- Inclua no `comment_html` algo como: `<p>⏱ Tempo: <N>min · 🪙 Tokens: <X> · 💰 Custo IA: US$ <Y> (Opus 4.8, via ccusage)</p>`.
- Tempo informado em `--time` vira worklog (passo 6) **e** é citado no comentário pra ficar legível.

## Notas de API

- **Use `curl` pras chamadas, não `python urllib`.** A API do Plane fica atrás de Cloudflare, que bloqueia o User-Agent padrão do urllib com `403 error code: 1010`. `curl` passa. Para montar JSON com acentos/HTML, gere o payload com `python -c json.dump(...)` num arquivo e poste com `curl --data @arquivo`.

## Opções

| Flag / intenção | Efeito |
|---|---|
| (texto livre após o ID) | Usa como corpo do report. |
| `--pr <url>` | Anexa o link do PR no comentário. |
| `--time <min>` | Cria worklog de `<min>` minutos (opt-in). Não fecha a task. |
| `--cost <usd>` / `--tokens <n>` | Inclui custo/tokens no comentário. Se ausente e o usuário quiser custo, rode `ccusage` e confirme. |
| `--state "<nome>"` | Também move a issue pra esse estado (opt-in). |
| sem texto | Você gera o resumo da sessão e confirma antes de postar. |

## Output

Termine com um resumo curto:

```
✓ Report postado em <TASK_ID> (projeto <PREFIX>)
🔗 <link do PR, se houver>
⏱ Worklog: <N>min  (ou: nenhum)
💰 Custo: US$ <Y> · <X> tokens  (ou: não informado)
↪ Estado: <inalterado | novo estado>
```

> Para **iniciar** trabalho numa task use `/iniciar-task`. Para o **encerramento formal** (mover pra concluída fechando o ciclo) use `/fechar-task`. Esta skill reporta — e opcionalmente loga tempo/custo — sem fechar a task.
