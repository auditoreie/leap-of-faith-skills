---
name: logs-gcp
description: Observabilidade somente leitura no Google Cloud para os serviços do ecossistema (Cloud Run, Cloud Build, Error Reporting, Firebase Hosting) enquanto não há Sentry — lê logs por serviço, severidade, janela e texto, lista revisões e tráfego, deploys recentes e grupos de erro, correlaciona com o horário do sintoma e devolve evidência com timestamp, revisão e status HTTP para o diagnóstico. Use quando o usuário disser "vê os logs do Cloud Run", "o que aconteceu em produção às X", "erro 500 na API", "qual revisão está no ar", "último deploy", "/logs-gcp <serviço> [janela] [texto]", "check GCP logs". NÃO use para fazer deploy, mudar tráfego ou env (isso é a skill de deploy de cada repo), para Sentry (isso é sentry-cli) nem para achar a causa no código (isso é /debug-causa-raiz, que chama esta).
---

# logs-gcp

Responde "o que o serviço fez, quando, em qual revisão" com evidência do GCP, sem tocar em nada. É a fonte de dados do `/debug-causa-raiz` e do "Acompanhar prd" das tasks.

**Argumento:** `$ARGUMENTS` — serviço ou produto (ex.: `api-pagamentos-prod`, "API do produto X em produção"), janela (`2h`, `1d`, ou `2026-09-15T10:00..11:00`), e opcionalmente texto a procurar, `--status 5xx` ou `--severity ERROR`. Vazio → pergunte serviço e horário aproximado do sintoma.

`<skill-dir>` é a pasta desta `SKILL.md`.

## Token discipline

- **Mapa de serviços primeiro.** Localize a raiz subindo até achar `.claude/ecossistema.json` (`criar-task/scripts/ecossistema.sh` faz isso, se instalada). Se houver ecossistema configurado (`<raiz>/.claude/ecossistema/gcp-servicos.md` e `gcp.projeto` em `ecossistema.json`, via `/onboarding-ecossistema`), leia o mapa (é curto) e não redescubra. Senão, derive do repo em uma chamada: `rg -n 'run services|run deploy|_SERVICE_NAME|SERVICE:|--region' .claude/skills .github cloudbuild*.yaml apps/*/cloudbuild.yaml packages/*/cloudbuild.yaml 2>/dev/null | head -20` e `cat **/.firebaserc`. Dois candidatos para o mesmo ambiente → pergunte, não chute.
- `bash <skill-dir>/scripts/gcp.sh <sub> …` faz as chamadas com formato compacto (`--limit 30` default, uma linha por evento, mensagem cortada em 220 colunas). Nunca `--format json` bruto de log.
- Ordem barata → cara: `erros` (grupos agregados) → `logs --severity ERROR` → `requests --status 5xx` → `logs --grep <texto>`. Segunda leitura só com filtro mais estreito (request id, revisão, minuto).
- `builds` e `revisoes` são uma chamada cada e respondem "mudou algo perto do sintoma?" antes de qualquer leitura de log.

## Safe-mode

- **Só leitura.** O script só chama `logging read`, `run services describe|list`, `run revisions list`, `builds list`, Error Reporting `groupStats` (GET) e `firebase hosting:channel:list`. Nunca `run deploy`, `update-traffic`, `services update`, `set-env-vars`, `builds submit`, `firebase deploy`. Mudança de tráfego e rollback pertencem à skill de deploy do repo.
- Env vars aparecem só por **nome** (`revisoes` lista `env[].name`); nunca imprime valor.
- Auth expirada (`Reauthentication failed`) → o script para com código 4; peça ao usuário `! gcloud auth login` (ou `! gcloud config set account <conta>`). O agente não renova credencial.
- Linha de log pode conter PII (e-mail, CPF, telefone do cliente final). Ao levar evidência para task, PR ou comentário, redija esses campos.
- Janela default curta (`2h`); `30d` só com pedido explícito.

## Fallback

Pré-requisito ausente ou falho (auth expirada, binário faltando, MCP indisponível, `ecossistema.json` inexistente, script com erro) **não encerra a skill**: diga em uma linha o que faltou e como resolver (`! gcloud auth login`, `/onboarding-ecossistema`, instalar a ferramenta), ofereça seguir sem essa parte e, com a aprovação do usuário, prossiga marcando no Output o que ficou **não verificado**. O que não muda: escrita externa (ClickUp, GCP, `git push`, banco) continua exigindo confirmação, e "não verificado" nunca vira "ok".

## Passos

1. **Resolver** projeto, serviço, região e ambiente pelo mapa. Diga qual serviço vai consultar e por quê, em uma linha.

2. **Mudou algo?**
   ```bash
   bash <skill-dir>/scripts/gcp.sh revisoes --project <p> --service <s> --region <r>
   bash <skill-dir>/scripts/gcp.sh builds    --project <p> [--region <r>] [--limit 8]
   ```
   Anote a revisão que serve o tráfego, quando foi criada e a imagem. Deploy dentro da janela do sintoma é a primeira hipótese do `/debug-causa-raiz`.

3. **O que está errando?**
   ```bash
   bash <skill-dir>/scripts/gcp.sh erros    --project <p> --service <s> --since 1d          # grupos do Error Reporting
   bash <skill-dir>/scripts/gcp.sh logs     --project <p> --service <s> --since 2h --severity ERROR
   bash <skill-dir>/scripts/gcp.sh requests --project <p> --service <s> --since 2h --status 5xx
   bash <skill-dir>/scripts/gcp.sh logs     --project <p> --service <s> --from 2026-09-15T13:00:00Z --to 2026-09-15T13:30:00Z --grep "payment.confirmed"
   ```
   `erros` vazio com 403 significa API do Error Reporting desabilitada ou sem permissão; siga com `logs`. Horários são UTC no GCP; o time trabalha em UTC-3 — converta ao reportar.

4. **Front (Firebase Hosting)** só se o sintoma for de tela: `gcp.sh hosting --project <p> --site <site>` lista canais e a versão ativa; release/rollback é pelo console ou pela skill de deploy.

5. **Correlacionar.** Primeira ocorrência do erro × horário do último deploy × revisão nas linhas de log. Mesma revisão antes e depois do erro → causa não é deploy (dado, terceiro, horário). Revisão nova coincide → candidato.

## Fontes (verificadas em 2026-09-15)

- `gcloud logging read`, flags `--freshness` (default `1d`), `--limit`, `--order`, `--format`: <https://docs.cloud.google.com/sdk/gcloud/reference/logging/read>
- Logs do Cloud Run: `resource.type="cloud_run_revision"`, labels `service_name`, `revision_name`, `location`; `httpRequest.status`/`latency` nos logs de requisição: <https://docs.cloud.google.com/run/docs/logging>
- Error Reporting `GET https://clouderrorreporting.googleapis.com/v1beta1/projects/<p>/groupStats` com `serviceFilter.service`, `timeRange.period`, `order`, `pageSize`: <https://docs.cloud.google.com/error-reporting/reference/rest/v1beta1/projects.groupStats/list> · valores de `period`: <https://docs.cloud.google.com/error-reporting/reference/rest/v1beta1/QueryTimeRange>

## Output

```
Serviço: <nome> (<projeto>/<região>, <ambiente>) · revisão no ar: <rev> desde <data hora UTC-3> · imagem: <tag>
Deploys na janela: <build id, hora, status> | nenhum
Erros (<janela>): <grupo — n ocorrências — primeira/última — mensagem curta> | nenhum | não verificado (<motivo>)
Requests 5xx: <n> · exemplo: <hora> <status> <método path> <latência> rev <rev>
Linhas relevantes: <hora UTC-3> [<sev>] <rev> <mensagem cortada>
Leitura: <deploy coincide | não coincide | dado externo | sem evidência suficiente — próximo filtro sugerido>
```

Sem linhas na janela, diga isso e sugira a próxima janela ou filtro. Nunca conclua "sem erro" a partir de uma consulta que falhou.
