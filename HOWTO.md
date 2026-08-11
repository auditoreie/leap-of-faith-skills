# HOWTO — usando as skills

## Instalação (uma vez por máquina)

```bash
git clone git@github.com:auditoreie/leap-of-faith-skills.git ~/leap-of-faith-skills
~/leap-of-faith-skills/install.sh
```

O script:
- cria `~/.claude/skills/` se não existir;
- recursa em `skills/**/SKILL.md`, em qualquer profundidade;
- cria um symlink por skill, nomeado pelo **basename da pasta** da skill;
- não sobrescreve symlink divergente nem cópia local sem confirmação.

Atualizar depois é `git pull` em `~/leap-of-faith-skills/`. Como são symlinks, o pull já vale pra
todos os projetos — não precisa reinstalar.

## Como o Claude Code descobre as skills

Skills vivem em `~/.claude/skills/<nome>/SKILL.md`. O Claude lê o **frontmatter** (`name`,
`description`) de todas no início da sessão e carrega o corpo só quando invoca aquela skill. Por isso
a skill dispara de dois jeitos:

- **por comando** — você digita `/nome-da-skill`;
- **por intent** — o que você pediu casou com a `description`.

O agrupamento por tema (`skills/engenharia/…`) é organização do repositório e não aparece no nome
instalado.

## Skills disponíveis

### engenharia

#### `desmond`

Modo de orquestração com **acionamento explícito** (`/desmond`). Planeja antes de agir, despacha cada
trabalho pro agente mais barato que dá conta e reserva o modelo de fronteira pra síntese e decisão.

**Quando usar:**
- Tarefa grande ou multi-arquivo, com o mínimo de tokens e o máximo de qualidade —
  `/desmond <tarefa>`, ou `/desmond` sozinho aplica à tarefa em curso
- Decidir **onde** cada trabalho roda: inline → subagente único → fan-out → `Workflow` (escada de
  custo crescente; `Workflow` só com opt-in seu)
- Trocar repetição manual por um loop agendado, quando isso sair mais barato que fazer na mão

**Não** dispara sozinha, não compensa em tarefa trivial de um passo e não escala pra `Workflow` sem
você pedir.

#### `validar-skill`

Gate de contribuição — rode **antes de todo PR** neste repositório.

```bash
/validar-skill                          # audita o diff contra a main
/validar-skill skills/gestao/nova-skill # audita uma skill específica

# ou direto, sem o agente:
./skills/engenharia/validar-skill/scripts/scan.sh
```

Bloqueia: segredo e credencial, `.env` e derivados, chave privada, PII, dado de cliente, binário,
arquivo > 1 MB, frontmatter inválido, nome de skill duplicado. Sinaliza como ressalva: SKILL.md longa
demais, falta de token budget ou safe-mode, padrão destrutivo, caminho absoluto de máquina.

Exit code `1` quando há bloqueio — serve direto em CI.

**Neste repositório o gate já é automático:** o `install.sh` aponta `core.hooksPath` pra `.githooks/`,
e o hook de `pre-commit` roda o scanner sobre os arquivos em stage a cada commit. Bloqueio aborta o
commit; ressalva passa e aparece no review. Confira com `git config core.hooksPath` — deve responder
`.githooks`.

> Se o gate acusar credencial real: **revogue a chave primeiro**. Apagar do arquivo não resolve —
> o histórico do git preserva o valor commitado.

### gestao

#### `project-ledger`

Orquestra **decisões de engenharia** (ADRs versionados) e **trabalho ativo** (tasks locais, fora do
git) em qualquer projeto.

- `/project-ledger init` — bootstrap: cria `docs/adr/` versionado, o ADR-0001 de baseline e o
  workspace local de tasks
- `task new <slug>` / `task close` — ao fechar, gera o ADR automaticamente
- `adr new` — registra uma decisão avulsa
- `sync notion` / `sync clickup` — sincroniza via MCP, só sob comando explícito
- `status` — situação atual de tasks e ADRs

Detalhe em `skills/gestao/project-ledger/SKILL.md` (+ `conventions.md`, lazy-load).

#### Fluxo Plane (`skills/gestao/plane/`)

Ciclo de task no Plane. Cada dev usa a **própria** API key, lida de `~/.claude/plane_config.json` —
nunca hardcoded, nunca compartilhada. Workspace e Project ID são resolvidos em runtime (o projeto sai
do prefixo do task ID), então as skills funcionam em qualquer workspace do Plane.

| Comando | O que faz |
|---|---|
| `/plane-onboarding` | Primeiro setup: coleta workspace + API key pessoal, grava a config com `chmod 600`, conecta o MCP e explica o fluxo |
| `/iniciar-task PROJ-25` | Move pra In Progress, inicia o cronômetro, lê objetivo e definition of done, começa a executar |
| `/reportar-task PROJ-25 --pr <url>` | Comenta na task; opcionalmente `--time <min>` pro worklog e `--cost`/`--tokens` pros campos de custo. **Não fecha** |
| `/fechar-task PROJ-25` | Encerra: worklog, tokens, custo e comentário de resumo |

Fronteira: `iniciar` (começa) → `reportar` (meio, sem fechar) → `fechar` (encerra).

O custo de IA sai do `ccusage` (`npx ccusage@latest`), nunca de taxa fixa por token — a tarifa varia
por modelo e por input/output/cache.

### integracoes

#### `meta-waba`

Referência da WhatsApp Business Platform (Cloud API / Graph API / WABA): templates, ciclo de vida de
números, webhooks com HMAC SHA-256, Flows com endpoint criptografado, analytics, Embedded Signup e
códigos de erro. Dispara por intent — mencione WABA, Cloud API, template rejeitado, número que não
registra, webhook que não chega.

Detalhe por assunto em `skills/integracoes/meta-waba/references/`, com scripts em `scripts/` (cliente
Graph, upload resumable, verificação de HMAC).

## Usando em um projeto novo

1. `cd ~/seu/repo`
2. `claude`
3. `/project-ledger init`
4. Revise o `docs/adr/0001-baseline.md` gerado
5. Siga trabalhando — `/project-ledger task new <slug>` quando começar algo digno de registro

## Customização local

Pra customizar uma skill **só na sua máquina**, não edite o symlink — clone a skill:

```bash
cp -r ~/leap-of-faith-skills/skills/gestao/project-ledger ~/.claude/skills/project-ledger-local
rm ~/.claude/skills/project-ledger   # remove o symlink
```

Edite `~/.claude/skills/project-ledger-local/` à vontade. Pra voltar ao compartilhado, rode
`install.sh` de novo.

Se a customização for útil pra mais gente, melhor mandar de volta como PR do que manter um fork
local — veja [CONTRIBUTING.md](CONTRIBUTING.md).

## Quando vale escrever uma skill nova aqui

O critério: **se você teria que explicar o mesmo padrão duas vezes pro Claude em projetos diferentes,
vira skill aqui.**

Não vira skill: instrução específica de um projeto (vai no `CLAUDE.md` daquele repo, ou em
`.claude/skills/` do próprio repo) nem preferência pessoal de estilo (vai no `~/.claude/CLAUDE.md`).

Processo completo em [docs/creating-skills.md](docs/creating-skills.md); fluxo de fork e PR em
[CONTRIBUTING.md](CONTRIBUTING.md).

## Padrão alternativo: skill project-local

Algumas skills são valiosas mas **não cabem aqui** porque amarram em detalhes de um único repositório
(portas, paths, comandos, dados de seed). O lugar delas é
`<projeto>/.claude/skills/<nome>/SKILL.md` — versionado junto com o código que orquestram.

**Exemplo típico:** uma skill `start` que sobe o ambiente do projeto (Docker ou local, cross-OS, com
seed). É específica daquele repositório, mas segue a mesma disciplina das skills daqui:

- frontmatter com gatilhos de intent claros (`rodar`, `subir`, `iniciar`, `boot`, `start`);
- seções "Quando usar" e "Quando NÃO usar" — a segunda citando skills concorrentes (`/verify`,
  `/run`) pra evitar invocação errada;
- token discipline: `SKILL.md` ≤ 150 linhas, detalhe raro (ex: Windows nativo) em arquivo lazy-load;
- sem efeito colateral automático: confirma antes de um `docker compose up` pesado, falha explícito
  se o Docker não estiver disponível.

Use isso como modelo quando o projeto tiver setup não-trivial. Não precisa copiar — siga a estrutura
(frontmatter + seções + lazy-load) e adapte.

**Como decidir entre aqui e project-local:**

| Sinal | Vai onde |
|---|---|
| Funciona em 2+ repositórios sem mudar comando/path/porta | `leap-of-faith-skills/skills/` |
| Hardcoda algo do repositório (porta, tenant, endpoint, script do monorepo) | `<repo>/.claude/skills/` |
| Orquestra fluxo cross-project (ADRs, sync com Notion/ClickUp) | `leap-of-faith-skills/skills/` |
| Mistura regra geral com detalhe do repositório | Skill genérica aqui + skill fina no repo que a chama |
