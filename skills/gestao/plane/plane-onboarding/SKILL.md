---
name: plane-onboarding
description: Onboards a dev to a Plane workspace — collects the dev's personal Plane API key, writes ~/.claude/plane_config.json, connects the Plane MCP, and verifies the /iniciar-task / /fechar-task flow. Use when a dev says "configurar Plane", "onboarding Plane", "setup da minha API key do Plane", "conectar o MCP do Plane", "configurar Claude Code para o Plane", or is setting up their machine for the first time. Each dev uses their OWN key — never a shared one.
---

# plane-onboarding

Configura a máquina de **um dev** para trabalhar com um workspace do Plane via Claude Code.
**Cada dev usa a própria API Key** — nunca compartilhe chaves.

> O **workspace slug** não é fixo nesta skill: ele é perguntado ao dev e gravado em
> `~/.claude/plane_config.json`. As demais skills do Plane leem esse campo. Nos exemplos abaixo o
> slug aparece como `provider-1` — substitua pelo slug real do seu workspace (o que aparece em
> `app.plane.so/<slug>`). O Project ID também não é fixo: é resolvido pelo prefixo do task ID.

## Token discipline

- Skill de setup: não leia o repositório, não rode subagentes, não liste projetos do Plane.
- Só os comandos abaixo, na ordem. O passo 6 é explicação verbal — não vá conferir a configuração de
  resolução de projeto em nenhum repo.

## Safe-mode

- **Nunca ecoe a API Key completa** — nem de volta pro dev, nem em log, nem no resumo final. No
  máximo o prefixo (`plane_api_xxxx…`).
- Escreva **somente** `~/.claude/plane_config.json`. Não toque em nenhum arquivo do repositório atual,
  e nunca grave a chave dentro de um projeto versionado.
- `chmod 600` no arquivo é obrigatório, não opcional.
- Não revogue nem rotacione chave por conta própria — oriente o dev a fazer no painel.

## Pré-checagem (passo 0)

Antes de tudo, verifique e oriente o dev:

```bash
node --version   # precisa ser >= v22; se menor, instruir: nvm install 22 && nvm use 22
claude --version # Claude Code instalado e logado (claude login)
```

Se algo faltar, pare e oriente a instalar antes de seguir.

## Passo 1 — Coletar workspace e API Key pessoal

Pergunte o **slug do workspace** (o que aparece na URL `app.plane.so/<slug>`) e peça ao dev a
**própria** API Key:

> "Cole sua API Key pessoal do Plane (gerada em `app.plane.so/<workspace> → Profile → API Tokens →
> Create Token`, nome sugerido `claude-code-<seu-nome>`). Ela começa com `plane_api_...`.
> **Não** use a chave de outra pessoa."

Validações:
- Deve começar com `plane_api_`.
- Se o dev colar uma chave claramente compartilhada (ex: já vista em outro setup), recuse e peça a dele.
- **Nunca** ecoe a chave completa de volta na conversa — mostre no máximo o prefixo.

## Passo 2 — Salvar a config local

Escreva `~/.claude/plane_config.json` com os dados fornecidos e proteja o arquivo:

```bash
printf '{\n  "api_key": "%s",\n  "workspace": "%s"\n}\n' "$PLANE_API_KEY" "$PLANE_WORKSPACE" \
  > ~/.claude/plane_config.json
chmod 600 ~/.claude/plane_config.json
```

Esse arquivo é **local**, fora de qualquer repositório git. Nunca commite, nunca cole a chave em
código/doc/PR.

## Passo 3 — Conectar o MCP do Plane

```bash
claude mcp add plane --transport http https://mcp.plane.so/http/api-key/mcp \
  -H "Authorization: Bearer $PLANE_API_KEY" \
  -H "X-Workspace-slug: $PLANE_WORKSPACE"
```

## Passo 4 — Verificar

```bash
python3 -c "import json,os;c=json.load(open(os.path.expanduser('~/.claude/plane_config.json')));print('config ok:', c['workspace'], c['api_key'][:14]+'…')"
claude mcp list | grep -i plane   # deve aparecer "plane ... Connected"
```

Confirme ao dev: config salva (mostrando só o prefixo da chave) + MCP `plane` conectado.

## Passo 5 — Comandos de task

Os comandos `/iniciar-task <ID>`, `/reportar-task <ID>` e `/fechar-task <ID>` leem key e workspace de
`~/.claude/plane_config.json` (nunca hardcoded). Em repos que os versionam (`.claude/commands/`), a
versão do repo tem precedência sobre a global de `~/.claude/commands/`.

## Passo 6 — Como o projeto Plane é resolvido (explique ao dev)

- **Padrão:** o projeto é resolvido pelo **prefixo do task ID** (`PROJ-25` → projeto cujo
  `identifier` é `PROJ`). O dev não informa Project ID.
- **Repo multi-cliente** (tem `.claude/plane-projects.json`): o projeto sai da **branch atual** — o
  slug que aparece como substring no nome da branch vence; sem match, usa `_default`.
- **Repo single-project:** o Project ID pode vir do campo `Plane Project ID` no `CLAUDE.md` do repo.

## Segurança

- Uma key por dev; revogue/rotacione em `app.plane.so/<workspace> → Profile → API Tokens` se vazar.
- `plane_config.json` com `chmod 600`. Nunca versione `.env`/keys.
- Se o dev colar a chave num canal compartilhado (PR, issue, chat do time), oriente a **revogar
  imediatamente** e gerar outra — chave exposta é chave queimada.

## Fechamento

Resuma ao dev o que foi configurado e aponte o teste rápido: abrir um repo, rodar `/iniciar-task <ID>`,
fazer uma mudança, abrir PR (`<ID>: descrição`) e rodar `/fechar-task <ID>`.
