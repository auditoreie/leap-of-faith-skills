---
name: reportar-task
description: Posta um report (comentário) numa work item do Plane, opcionalmente com link de PR, worklog de tempo, custo de tokens (via ccusage) e/ou mudança de estado — mas NÃO encerra a task e não depende do cronômetro de /iniciar-task. Resolve o projeto pelo prefixo do ID, então funciona em qualquer projeto do workspace (PROJ-1, ACME-12, etc.). Use quando o usuário disser "reportar na task", "comentar na task X", "registrar o PR na task", "logar tempo na task sem fechar", "atualizar a task no Plane sem fechar", "report on task", "add a comment to the Plane issue". NÃO use para iniciar trabalho (isso é /iniciar-task) nem para o encerramento formal da task com mudança pra concluída (isso é /fechar-task).
---

# reportar-task

Posta um **comentário de report** numa work item do Plane via REST API. É a operação leve do meio do fluxo: registrar progresso, anexar um PR, opcionalmente **logar tempo (worklog) e custo de tokens** — tudo **sem encerrar** a task e sem depender do cronômetro de `/iniciar-task`.

**Task ID:** `$ARGUMENTS` (ex: `PROJ-1`). Pode vir seguido de flags/intenção (ver Opções).

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

1. **Config** — key e workspace vêm de `~/.claude/plane_config.json` (nunca hardcode):
   ```bash
   CFG=~/.claude/plane_config.json
   API_KEY=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('$CFG')))['api_key'])")
   WORKSPACE=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('$CFG')))['workspace'])")
   ```
   Se o arquivo não existir, pare e aponte a skill `plane-onboarding`.

2. **Resolver o projeto pelo prefixo do ID.** Separe `$ARGUMENTS` em `PREFIX-SEQ` (ex: `PROJ-1` → prefixo `PROJ`, seq `1`). Busque o Project ID cujo `identifier == PREFIX`:
   ```bash
   PROJECT_ID=$(curl -s -H "X-API-Key: $API_KEY" \
     "https://api.plane.so/api/v1/workspaces/$WORKSPACE/projects/" \
     | python3 -c "import sys,json;d=json.load(sys.stdin);r=d.get('results',d) if isinstance(d,dict) else d;print(next((p['id'] for p in r if p.get('identifier')=='$PREFIX'),''))")
   ```
   Se vier vazio, pare e mostre os identifiers disponíveis — não chute.

3. **Achar a issue pelo `sequence_id`:**
   ```bash
   ISSUE_ID=$(curl -s -H "X-API-Key: $API_KEY" \
     "https://api.plane.so/api/v1/workspaces/$WORKSPACE/projects/$PROJECT_ID/issues/?per_page=100" \
     | python3 -c "import sys,json;d=json.load(sys.stdin);r=d.get('results',d) if isinstance(d,dict) else d;print(next((i['id'] for i in r if i.get('sequence_id')==$SEQ),''))")
   ```
   Vazio → a issue não está na primeira página (pagine com `?cursor=`) ou o ID está errado. Avise.

4. **Montar o report.** Se o usuário deu o texto, use-o. Senão, gere um resumo técnico curto do que foi feito nesta sessão (mudanças + link do PR, se houver). O campo obrigatório é `comment_html` (HTML simples: `<p>`, `<ul><li>`, `<a href>`). **Mostre ao usuário e confirme antes de postar.**

5. **Postar o comentário:**
   ```bash
   curl -s -X POST -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
     -d "{\"comment_html\": \"<HTML>\"}" \
     "https://api.plane.so/api/v1/workspaces/$WORKSPACE/projects/$PROJECT_ID/issues/$ISSUE_ID/comments/"
   ```

6. **(Opcional, opt-in) Worklog de tempo.** Só com `--time <min>`. Cria um worklog no **timesheet nativo** da issue — **não** fecha a task, e os worklogs **somam** (pode haver vários por issue). `duration` é um **inteiro em minutos** (não use `"87m"` — a API rejeita com `A valid integer is required`):
   ```bash
   curl -s -X POST -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
     -d "{\"description\": \"Sessão Claude Code\", \"logged_by\": \"claude-code\", \"duration\": <MIN>}" \
     "https://api.plane.so/api/v1/workspaces/$WORKSPACE/projects/$PROJECT_ID/issues/$ISSUE_ID/worklogs/"
   ```

7. **(Opcional) Gravar nos campos personalizados Custo IA / Tokens IA.** Com `--cost`/`--tokens`, além de citar no comentário, grave nos custom fields nativos (DECIMAL) que existem em **todos os projetos** no tipo Task default: `Custo IA (US$)` e `Tokens IA`.
   - Pegue os IDs das propriedades no tipo da issue:
     ```bash
     curl -s -H "X-API-Key: $API_KEY" \
       "https://api.plane.so/api/v1/workspaces/$WORKSPACE/projects/$PROJECT_ID/issue-types/$TYPE_ID/issue-properties/"
     ```
     (`$TYPE_ID` = o `issue_type` da issue, ou o tipo com `is_default:true`.) Mapeie `display_name → id`. Se os campos não existirem nesse projeto, pule e avise.
   - Grave o valor (POST cria, **valor numérico**, não string; se já existe, use PATCH no mesmo path):
     ```bash
     curl -s -X POST -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
       -d "{\"value\": <NUMERO>}" \
       "https://api.plane.so/api/v1/workspaces/$WORKSPACE/projects/$PROJECT_ID/work-items/$ISSUE_ID/work-item-properties/$PROP_ID/values/"
     ```
     ⚠️ Use o path `work-items/.../work-item-properties/.../values/` (o alias `issues/.../issue-properties/.../values/` rejeita com 405/500). `value` é número (ex: `9.32`), não `"9.32"`.

8. **(Opcional, opt-in) Mudar estado.** Só se pedido (`--state "<nome>"`): liste estados (`.../projects/$PROJECT_ID/states/`), case o nome, e faça `PATCH .../issues/$ISSUE_ID/ {"state":"<state_id>"}`.

## Tempo e custo de tokens

Tempo → worklog nativo (passo 6). Custo/tokens → campos personalizados nativos `Custo IA (US$)` e `Tokens IA` (passo 7) **e** citados no corpo do comentário pra leitura rápida.

- **Custo via `ccusage` (NÃO use taxa fixa por token).** A tarifa varia por modelo (Opus ≫ Sonnet) e por input/output/cache. Rode no terminal e leia o custo USD já calculado:
  ```bash
  ccusage   # ou: npx ccusage@latest
  ```
  Pegue tokens + custo USD da sessão/dia correspondente. **Confirme o valor com o usuário** antes de gravar (não invente número, não estime de memória).
- Inclua no `comment_html` algo como: `<p>⏱ Tempo: <N>min · 🪙 Tokens: <X> · 💰 Custo IA: US$ <Y> (Opus 4.8, via ccusage)</p>`.
- `Tokens IA` é um único número — use o **total** (input + output) salvo no campo, mesmo que o comentário detalhe in/out.

## Notas de API

- **Use `curl` pras chamadas, não `python urllib`.** A API do Plane fica atrás de Cloudflare, que bloqueia o User-Agent padrão do urllib com `403 error code: 1010`. `curl` passa. Para montar JSON com acentos/HTML, gere o payload com `python -c json.dump(...)` num arquivo e poste com `curl --data @arquivo`.

## Opções

| Flag / intenção | Efeito |
|---|---|
| (texto livre após o ID) | Usa como corpo do report. |
| `--pr <url>` | Anexa o link do PR no comentário. |
| `--time <min>` | Cria worklog de `<min>` minutos (opt-in). Não fecha a task. |
| `--cost <usd>` / `--tokens <n>` | Grava nos campos `Custo IA (US$)` / `Tokens IA` (passo 7) **e** cita no comentário. Se ausente e o usuário quiser custo, rode `ccusage` e confirme. |
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
