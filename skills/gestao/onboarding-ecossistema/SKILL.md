---
name: onboarding-ecossistema
description: Configura um ecossistema de trabalho (pasta raiz com vários repos de um cliente ou produto) para as skills do time — detecta os repositórios e o harness de cada um (branch de integração, CLAUDE.md, ADRs, testes, schema), pergunta o que não dá para detectar (quais repos entram, nome do produto, lista do ClickUp onde as tasks nascem, campos a preencher, serviços GCP por ambiente) e grava tudo em `<raiz>/.claude/ecossistema.json`, `ecossistema/produtos.md` e `ecossistema/gcp-servicos.md`, fora de qualquer repositório público. Use quando o usuário disser "configurar ecossistema", "onboarding do ecossistema", "/onboarding-ecossistema [raiz]", "setup deste cliente pras skills", ou quando criar-task, logs-gcp ou rodar-testes avisarem que não há ecossistema.json. NÃO use para configurar o Plane (isso é plane-onboarding) nem para criar tasks (isso é criar-task).
---

# onboarding-ecossistema

Uma vez por cliente: transforma "essa pasta tem os repos que usamos" em config que as outras skills leem sem gastar tokens redescobrindo. Detecta o que dá, pergunta o resto, grava local. Idempotente: com config existente, entra em modo **atualizar** (repo novo, lista nova, campo novo).

**Argumento:** `$ARGUMENTS` — a raiz (default: diretório atual). A raiz não precisa ser repo git.

`<skill-dir>` é a pasta desta `SKILL.md`.

## Token discipline

- Detecção por script (`scripts/detectar-repos.sh`), não por leitura de arquivos. Leia um `CLAUDE.md` só para extrair a linha de testes e de branch quando o script não achar script de teste.
- ClickUp é a parte cara e roda **uma vez**: hierarquia `max_depth 0` (workspaces) → `max_depth 2` filtrada por **um** `space_ids` → `clickup_get_list` → `clickup_get_custom_fields list_id`. Estimativa: 10-20k tokens no total; avise antes.
- GCP só se o usuário quiser e o `gcloud` estiver autenticado: `gcloud run services list` e `firebase hosting:sites:list`, uma vez cada.
- Perguntas com `AskUserQuestion`, até 4 por chamada, com opções vindas da detecção (nunca lista vazia).

## Safe-mode

- Escreve **só** em `<raiz>/.claude/ecossistema.json`, `<raiz>/.claude/ecossistema/produtos.md` e `<raiz>/.claude/ecossistema/gcp-servicos.md`. Mostra o conteúdo antes de gravar; em modo atualizar, mostra a diferença.
- Não cria task, não muda nada no ClickUp, não faz git nos repos. Se a raiz for um repo git público, avisa que `.claude/ecossistema*` precisa ir para o `.gitignore` (e oferece a linha).
- Não grava credencial: IDs de lista e campo não são segredo, mas ficam fora de repositório público por serem dados do cliente.

## Fallback

Provedor indisponível (sem MCP do ClickUp, `gcloud` sem auth, `gh` ausente) **não encerra o onboarding**: grave a seção com o que se sabe, registre em `"pendente"` o que faltou e diga o comando para completar depois (`! gcloud auth login`; "conecte o MCP do ClickUp e rode `/onboarding-ecossistema` em modo atualizar"). As skills consumidoras tratam `pendente` como "perguntar ao usuário".

## Passos

1. **Raiz e modo.** Resolva a raiz; se `<raiz>/.claude/ecossistema.json` existe, modo atualizar (leia e mostre o resumo). Pergunte o slug do ecossistema (ex.: nome do cliente) se novo.

2. **Repos.**
   ```bash
   bash <skill-dir>/scripts/detectar-repos.sh <raiz> 3
   ```
   Mostre a tabela e pergunte (multiSelect) **quais entram** e, por repo escolhido, o **nome do produto** e, se não detectado, a **branch de integração** (onde os PRs entram) e a de **produção**. Repos fora da seleção vão para "Outros repos na raiz" do `produtos.md`.

3. **Tracker (ClickUp).** Avise o custo e confirme. Então: `clickup_get_workspace_hierarchy max_depth 0` → pergunte o workspace se houver mais de um; `max_depth 2` com `space_ids` do space escolhido → pergunte **a lista onde as tasks nascem** e o folder de alocação; `clickup_get_list` para statuses (status inicial = o de menor `orderindex`); `clickup_get_custom_fields list_id` → pergunte quais campos a `criar-task` preenche (sugira os que parecem "produto", "escopo/deploy", "tipo") e, por repo, a opção de cada campo. Prefixo: `clickup_search count 1` na lista mostra um `custom_id`; confirme.

4. **GCP (opcional).** `gcloud config get-value project`; se autenticado, `gcloud run services list --project <p>` e `firebase hosting:sites:list --project <p>`; pergunte, por serviço listado, produto e ambiente. Sem auth → grave o esqueleto com **confirmar** e `"pendente": ["gcp"]`.

5. **Gravar.** Preencha `templates/ecossistema.template.json`, `templates/produtos.template.md` (uma seção por repo, tabela de roteamento com os sinais que o usuário der; deixe `**Perguntar**` onde não houver sinal) e `templates/gcp-servicos.template.md`. Mostre, confirme, grave.

6. **Verificar.** Se `criar-task` estiver instalada: `bash ~/.claude/skills/criar-task/scripts/ecossistema.sh <raiz>` deve imprimir `RAIZ`, `TRACKER` e os `REPO`. Sugira versionar `<raiz>/.claude/` num repo **privado**.

## Output

```
Ecossistema: <nome> · raiz: <caminho> · modo: novo | atualizar
Repos: <n> mapeados (<nomes>) · <m> fora (listados em produtos.md)
Tracker: ClickUp workspace <id> · lista "<nome>" (<id>) · prefixo <PREFIXO> · campos: <produto, escopo_deploy, tipo_report | nenhum>
GCP: projeto <id> · <n> serviços Cloud Run · <m> sites Hosting | pendente (<motivo>)
Arquivos: .claude/ecossistema.json · .claude/ecossistema/produtos.md · .claude/ecossistema/gcp-servicos.md
Pendente: <lista> | nada
Próximo passo: /criar-task <demanda> · revisar a tabela de roteamento em produtos.md
```
