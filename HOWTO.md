# HOWTO — usar as skills do time

## Instalação (uma vez por máquina)

```bash
~/team-skills/install.sh
```

O script:
- Cria `~/.claude/skills/` se não existir
- Recursa em `skills/**/SKILL.md` (suporta agrupamento por ferramenta, ex: `skills/plane/reportar-task/`)
- Cria um symlink por skill (nome = basename da pasta da skill) apontando deste repositório para `~/.claude/skills/`
- Não sobrescreve symlink divergente sem confirmação

Atualizar versão depois é só `git pull` no `~/team-skills/`.

## Como o Claude Code descobre as skills

Skills são detectadas em `~/.claude/skills/<nome>/SKILL.md`. Cada SKILL.md tem frontmatter (`name`, `description`) que o Claude lê no início da sessão. A skill aparece na lista do `/` ou é invocada por intent (palavras-chave na `description`). O nome do symlink é o **basename da pasta da skill** — o agrupamento por ferramenta (`skills/plane/...`) é só organização do repo, não muda o nome instalado.

## Skills disponíveis

### Genéricas

#### `project-ledger`

Orquestra **decisões de engenharia** (ADRs versionados) e **trabalho ativo** (tasks locais) em qualquer projeto.

**Quando usar:**
- Bootstrap de um repo (`/project-ledger init`) → cria `docs/adr/` versionado + ADR-0001 de baseline + workspace de tasks local
- Abrir / fechar uma task (`task new`, `task close`) — ao fechar, gera ADR automaticamente
- Registrar uma decisão avulsa (`adr new`)
- Sincronizar tasks com Notion ou ClickUp (`sync notion`, `sync clickup`) via MCP
- Conferir status atual (`status`)

Detalhes em `skills/project-ledger/SKILL.md` (+ `conventions.md`, lazy-load).

#### `desmond`

Modo **tri-modelo** do Opus (acionamento explícito `/desmond`): planeja com a precisão do **Mythos**, economiza tokens com a disciplina do **Fable** e decide/sintetiza com a força do **Opus**, orquestrando subagentes pra **máximo resultado por token**.

**Quando usar:**
- Atacar tarefa grande/multi-arquivo com o mínimo de tokens e o máximo de qualidade (`/desmond <tarefa>`, ou `/desmond` sozinho aplica à tarefa em curso)
- Decidir **onde** cada trabalho roda: inline (Opus) → subagente único → fan-out de Agents → `Workflow` (escada de custo crescente; Workflow só com opt-in)
- Trocar repetição manual por um **loop** agendado quando isso for mais barato que a execução na mão

**Não** dispara sozinha (explícita), não compensa em tarefa trivial de um passo, e não sai escalando pra Workflow sem seu opt-in.

Detalhes em `skills/desmond/SKILL.md`.

### Ferramenta: Plane (`skills/plane/`)

Workflow de tasks no Plane. Cada dev usa a **própria** API key (`~/.claude/plane_config.json`).

- **`plane-onboarding`** — primeiro setup: coleta a API key pessoal, escreve `~/.claude/plane_config.json` (chmod 600), conecta o MCP do Plane e explica o fluxo. Gatilhos: "configurar Plane", "setup da minha API key do Plane".
- **`iniciar-task`** — abre a task (move pra In Progress), inicia cronômetro e começa a executar. Ex: `/iniciar-task SINTE-25`.
- **`reportar-task`** — reporta/comenta na task; opcional worklog de tempo e custo (via `ccusage`) e campos personalizados `Custo IA (US$)`/`Tokens IA`; **não fecha**. Resolve o projeto pelo prefixo do ID (multi-projeto). Ex: `/reportar-task ATLASEDUCA-1 --pr <url>`.
- **`fechar-task`** — encerra: grava worklog, tokens, custo e comentário de resumo.

Fronteira: `iniciar` (começa) → `reportar` (meio, sem fechar) → `fechar` (encerra).

### Ferramenta: Meta WhatsApp (`skills/meta-waba/`)

- **`meta-waba`** — referência da WhatsApp Business Platform (Cloud API/Graph API/WABA): templates, números, webhooks HMAC, Flows, analytics, Embedded Signup, códigos de erro. Use em qualquer projeto que integre WhatsApp Business da Meta. Detalhe em `skills/meta-waba/references/`.

## Como usar em um projeto novo

1. `cd ~/seu/repo`
2. Abra o Claude Code: `claude`
3. Rode `/project-ledger init`
4. Reveja o `docs/adr/0001-baseline.md` gerado
5. Continue trabalhando — use `/project-ledger task new <slug>` quando começar algo digno de registro

## Customização local

Se você quiser customizar uma skill **só na sua máquina**, **não edite o symlink** — clone a skill localmente:

```bash
cp -r ~/team-skills/skills/project-ledger ~/.claude/skills/project-ledger-local
rm ~/.claude/skills/project-ledger  # remove o symlink
```

E edite `~/.claude/skills/project-ledger-local/` à vontade. Pra voltar ao compartilhado, é só rodar `install.sh` de novo.

## Quando vale a pena escrever uma skill nova aqui

Use o critério: **se você teria que explicar o mesmo padrão duas vezes pro Claude em projetos diferentes, vira skill aqui.** Se é específica de uma ferramenta, agrupe sob `skills/<ferramenta>/`.

Não vire skill: instruções específicas de um projeto (essas vão no `CLAUDE.md` daquele repo, ou em `.claude/skills/` do próprio repo — como `dev-up`/`dev-restart` do WhiteLabel).

Veja `docs/creating-skills.md` pra o processo.
