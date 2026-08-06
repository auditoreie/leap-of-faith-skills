---
name: iniciar-task
description: Inicia uma task no Plane — move pra In Progress, inicia o cronômetro, lê os insumos (objetivo, definition of done) e começa a executar. Use quando o usuário disser "iniciar task", "começar a task X", "/iniciar-task SINTE-25", "start task". NÃO use para só comentar/reportar (isso é /reportar-task) nem para encerrar (isso é /fechar-task).
---

# iniciar-task

Inicia uma task no Plane, lê os insumos e começa a executar.

**Task ID:** `$ARGUMENTS`

> ⚠️ **Multi-projeto:** hoje os IDs de projeto/estado abaixo são do piloto SINTE. Para outros projetos (ATLASEDUCA, VEGA, etc.) o Project ID e os state IDs mudam — resolva o projeto pelo prefixo do ID (como faz `reportar-task`) e busque o estado "In Progress" via `.../projects/<PID>/states/`. TODO: generalizar igual à `reportar-task`.

Siga estes passos na ordem:

1. Leia sua API Key pessoal de `~/.claude/plane_config.json` (nunca hardcode a chave):

```bash
API_KEY=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/plane_config.json')))['api_key'])")
```

2. Use a REST API do Plane via Bash para buscar o work item `$ARGUMENTS`:

```bash
curl -s -H "X-API-Key: $API_KEY" \
  "https://api.plane.so/api/v1/workspaces/sintetizaai/projects/1fd6fb19-159b-4945-90fb-ffaa24c2d37c/issues/?per_page=100"
```

Filtre pelo `sequence_id` correspondente ao número de `$ARGUMENTS` (ex: SINTE-25 → sequence_id 25). Guarde o id e leia o `name`, `description_html` e `priority`.

Atualize o estado do work item para "In Progress" (state: `e1e0bea1-cc55-4d42-a58c-7d710b0a2955`) via PATCH na API do Plane.

Salve o horário de início em `/tmp/plane_task_atual.json`:

```json
{
  "task_id": "$ARGUMENTS",
  "issue_id": "<id do work item>",
  "start_time": "<ISO 8601 timestamp atual>"
}
```

Apresente ao usuário um resumo da task:

```
✓ Task $ARGUMENTS movida para In Progress
✓ Cronômetro iniciado
📋 Nome:
🎯 Objetivo: <extraído da description_html>
✅ Definition of Done: <extraído da description_html>
```

Analise o repositório atual (arquivos presentes, estrutura, stack) e execute o que a task pede — crie arquivos, edite código, etc. — seguindo exatamente os critérios de pronto descritos na task.

Ao terminar a implementação, lembre o usuário:

- Criar branch: `feature/$ARGUMENTS-descricao`
- Abrir PR com título: `$ARGUMENTS: descrição`
- Rodar `/fechar-task $ARGUMENTS` para gravar tempo e tokens no Plane

> Para reportar progresso sem fechar use `/reportar-task`. Para encerrar use `/fechar-task`.
