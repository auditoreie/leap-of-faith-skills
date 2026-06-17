# HOWTO — usar as skills da Auditore

## Instalação (uma vez por máquina)

```bash
~/auditore-skills/install.sh
```

O script:
- Cria `~/.claude/skills/` se não existir
- Cria um symlink por skill apontando deste repositório para `~/.claude/skills/`
- Não sobrescreve nada sem confirmação (mostra um diff e pergunta)

Atualizar versão depois é só `git pull` no `~/auditore-skills/`.

## Como o Claude Code descobre as skills

Skills são detectadas em `~/.claude/skills/<nome>/SKILL.md`. Cada SKILL.md tem frontmatter (`name`, `description`) que o Claude lê no início da sessão. A skill aparece na lista do `/` ou é invocada por intent (palavras-chave na `description`).

## Skills disponíveis

### `project-ledger`

Orquestra **decisões de engenharia** (ADRs versionados) e **trabalho ativo** (tasks locais) em qualquer projeto.

**Quando usar:**
- Bootstrap de um repo (`/project-ledger init`) → cria `docs/adr/` versionado + ADR-0001 de baseline + workspace de tasks local
- Abrir / fechar uma task (`task new`, `task close`) — ao fechar, gera ADR automaticamente
- Registrar uma decisão avulsa (`adr new`)
- Sincronizar tasks com Notion ou ClickUp (`sync notion`, `sync clickup`) via MCP
- Conferir status atual (`status`)

**Filosofia:**
- ADRs vivem em `docs/adr/` versionado no git. Append-only, decisões aceitas.
- Tasks vivem em `.claude/tasks/` local, gitignored. Mutáveis, working log.
- Ao fechar uma task, ela vira ADR (sem reler código — task é o input).

Detalhes completos em `skills/project-ledger/SKILL.md` e `skills/project-ledger/conventions.md` (este último é lazy-load — só leia quando precisar de detalhe).

### `plane-onboarding`

Configura a máquina de um dev para trabalhar com o Plane da Sintetiza AI: coleta a **API Key pessoal**,
escreve `~/.claude/plane_config.json` (chmod 600), conecta o MCP do Plane e explica o fluxo de
`/iniciar-task` / `/fechar-task`.

**Quando usar:** primeiro setup de um dev, "configurar Plane", "setup da minha API key do Plane",
"conectar o MCP do Plane". Cada dev usa a **própria** chave — nunca compartilhada.

Detalhes em `skills/plane-onboarding/SKILL.md`.

## Como usar em um projeto novo

1. `cd ~/seu/repo`
2. Abra o Claude Code: `claude`
3. Rode `/project-ledger init`
4. Reveja o `docs/adr/0001-baseline.md` gerado
5. Continue trabalhando — use `/project-ledger task new <slug>` quando começar algo digno de registro

## Customização local

Se você quiser customizar uma skill **só na sua máquina**, **não edite o symlink** — clone a skill localmente:

```bash
cp -r ~/auditore-skills/skills/project-ledger ~/.claude/skills/project-ledger-local
rm ~/.claude/skills/project-ledger  # remove o symlink
```

E edite `~/.claude/skills/project-ledger-local/` à vontade. Pra voltar ao compartilhado, é só rodar `install.sh` de novo.

## Quando vale a pena escrever uma skill nova aqui

Use o critério: **se você teria que explicar o mesmo padrão duas vezes pro Claude em projetos diferentes, vira skill aqui.**

Não vire skill: instruções específicas de um projeto (essas vão no `CLAUDE.md` daquele repo).

Veja `docs/creating-skills.md` pra o processo.
