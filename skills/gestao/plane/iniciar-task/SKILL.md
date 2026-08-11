---
name: iniciar-task
description: Inicia uma task no Plane — move pra In Progress, inicia o cronômetro, lê os insumos (objetivo, definition of done) e começa a executar. Resolve o projeto pelo prefixo do ID, então funciona em qualquer projeto do workspace (PROJ-25, ACME-12, etc.). Use quando o usuário disser "iniciar task", "começar a task X", "/iniciar-task PROJ-25", "start task". NÃO use para só comentar/reportar (isso é /reportar-task) nem para encerrar (isso é /fechar-task).
---

# iniciar-task

Inicia uma task no Plane, lê os insumos e começa a executar.

**Task ID:** `$ARGUMENTS` (ex: `PROJ-25`)

## Token discipline

- Resolva projeto e issue com o mínimo de chamadas: uma listagem de projetos + uma de issues.
- Só leia o repositório **depois** de ter o objetivo da task em mãos — e apenas os arquivos que a
  task indica. Não varra a codebase inteira "pra entender o contexto".

## Safe-mode

- Nunca faça git (branch/commit/push) sem pedido explícito — a skill sugere, não executa.
- A mudança de estado pra "In Progress" é o **único** write automático. Qualquer outro write na task
  é opt-in.

## Passos

1. **Config** — key e workspace vêm de `~/.claude/plane_config.json` (nunca hardcode):

   ```bash
   CFG=~/.claude/plane_config.json
   API_KEY=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('$CFG')))['api_key'])")
   WORKSPACE=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('$CFG')))['workspace'])")
   ```

   Se o arquivo não existir, pare e aponte a skill `plane-onboarding`.

2. **Resolver o projeto pelo prefixo do ID.** Separe `$ARGUMENTS` em `PREFIX-SEQ` (ex: `PROJ-25` →
   prefixo `PROJ`, seq `25`) e busque o Project ID cujo `identifier == PREFIX`:

   ```bash
   PROJECT_ID=$(curl -s -H "X-API-Key: $API_KEY" \
     "https://api.plane.so/api/v1/workspaces/$WORKSPACE/projects/" \
     | python3 -c "import sys,json;d=json.load(sys.stdin);r=d.get('results',d) if isinstance(d,dict) else d;print(next((p['id'] for p in r if p.get('identifier')=='$PREFIX'),''))")
   ```

   Vazio → pare e mostre os identifiers disponíveis. Não chute Project ID.

3. **Achar a issue pelo `sequence_id`** e ler `name`, `description_html` e `priority`:

   ```bash
   curl -s -H "X-API-Key: $API_KEY" \
     "https://api.plane.so/api/v1/workspaces/$WORKSPACE/projects/$PROJECT_ID/issues/?per_page=100"
   ```

4. **Resolver o state "In Progress" do projeto** (os IDs de estado mudam por projeto — nunca
   hardcode):

   ```bash
   STATE_ID=$(curl -s -H "X-API-Key: $API_KEY" \
     "https://api.plane.so/api/v1/workspaces/$WORKSPACE/projects/$PROJECT_ID/states/" \
     | python3 -c "import sys,json;d=json.load(sys.stdin);r=d.get('results',d) if isinstance(d,dict) else d;print(next((s['id'] for s in r if s.get('name','').lower()=='in progress'),''))")
   ```

   Depois faça `PATCH .../issues/$ISSUE_ID/` com `{"state": "$STATE_ID"}`.

5. **Iniciar o cronômetro** — salve o horário de início em `/tmp/plane_task_atual.json`:

   ```json
   {
     "task_id": "$ARGUMENTS",
     "project_id": "<PROJECT_ID>",
     "issue_id": "<id do work item>",
     "start_time": "<ISO 8601 timestamp atual>"
   }
   ```

6. **Apresentar o resumo da task ao usuário:**

   ```
   ✓ Task $ARGUMENTS movida para In Progress
   ✓ Cronômetro iniciado
   📋 Nome: <name>
   🎯 Objetivo: <extraído da description_html>
   ✅ Definition of Done: <extraído da description_html>
   ```

7. **Executar.** Analise o repositório atual (estrutura, stack) e faça o que a task pede — criando e
   editando arquivos — seguindo exatamente os critérios de pronto descritos na task.

Ao terminar a implementação, lembre o usuário:

- Criar branch: `feature/$ARGUMENTS-descricao`
- Abrir PR com título: `$ARGUMENTS: descrição`
- Rodar `/fechar-task $ARGUMENTS` para gravar tempo e tokens no Plane

## Notas de API

- **Use `curl`, não `python urllib`.** A API do Plane fica atrás de Cloudflare, que bloqueia o
  User-Agent padrão do urllib com `403 error code: 1010`.

> Para reportar progresso sem fechar use `/reportar-task`. Para encerrar use `/fechar-task`.
