---
name: plane-onboarding
description: Onboards a dev to the Sintetiza AI Plane setup — collects the dev's personal Plane API key, writes ~/.claude/plane_config.json, connects the Plane MCP, and verifies the /iniciar-task / /fechar-task flow. Use when a dev says "configurar Plane", "onboarding Plane", "setup da minha API key do Plane", "conectar o MCP do Plane", "configurar Claude Code para o Plane", or is setting up their machine for the first time. Each dev uses their OWN key — never a shared one.
---

# plane-onboarding

Configura a máquina de **um dev** para trabalhar com o Plane da Sintetiza AI via Claude Code.
Automatiza as Seções 1–3 do onboarding. **Cada dev usa a própria API Key** — nunca compartilhe chaves.

> Workspace fixo: `sintetizaai`. Projeto é resolvido por repo/branch (ver passo 6) — a skill não fixa Project ID.

## Pré-checagem (passo 0)

Antes de tudo, verifique e oriente o dev:

```bash
node --version   # precisa ser >= v22; se menor, instruir: nvm install 22 && nvm use 22
claude --version # Claude Code instalado e logado (claude login)
```

Se algo faltar, pare e oriente a instalar antes de seguir.

## Passo 1 — Coletar a API Key pessoal

Peça ao dev a **própria** API Key do Plane:

> "Cole sua API Key pessoal do Plane (gerada em `app.plane.so/sintetizaai → Profile → API Tokens → Create Token`, nome sugerido `claude-code-<seu-nome>`). Ela começa com `plane_api_...`. **Não** use a chave de outra pessoa."

Validações:
- Deve começar com `plane_api_`.
- Se o dev colar uma chave claramente compartilhada (ex: já vista em outro setup), recuse e peça a dele.

## Passo 2 — Salvar a config local

Escreva `~/.claude/plane_config.json` com a chave fornecida e proteja o arquivo:

```bash
printf '{\n  "api_key": "%s",\n  "workspace": "sintetizaai"\n}\n' "$PLANE_API_KEY" > ~/.claude/plane_config.json
chmod 600 ~/.claude/plane_config.json
```

Esse arquivo é **local**, fora de qualquer repositório git. Nunca commite, nunca cole a chave em código/doc/PR.

## Passo 3 — Conectar o MCP do Plane

```bash
claude mcp add plane --transport http https://mcp.plane.so/http/api-key/mcp \
  -H "Authorization: Bearer $PLANE_API_KEY" \
  -H "X-Workspace-slug: sintetizaai"
```

## Passo 4 — Verificar

```bash
python3 -c "import json,os;print('config ok:', json.load(open(os.path.expanduser('~/.claude/plane_config.json')))['api_key'][:14]+'…')"
claude mcp list | grep -i plane   # deve aparecer "plane ... Connected"
```

Confirme ao dev: config salva (mostrando só o prefixo da chave) + MCP `plane` conectado.

## Passo 5 — Comandos de task

Os comandos `/iniciar-task <ID>` e `/fechar-task <ID>` leem a key de `~/.claude/plane_config.json`
(nunca hardcoded). Em repos que os versionam (`.claude/commands/`), a versão do repo tem precedência
sobre a global de `~/.claude/commands/`.

## Passo 6 — Como o projeto Plane é resolvido (explique ao dev)

- **Repo whitelabel** (tem `.claude/plane-projects.json`): o projeto é resolvido **automaticamente pela
  branch atual** — o slug de cliente que aparece como substring no nome da branch vence; sem match usa
  `_default`. O dev **não** informa Project ID.
- **Repo single-project**: o Project ID vem do campo `Plane Project ID` no `CLAUDE.md` do repo.
- Sem nenhum dos dois: usa o projeto piloto SINTE.

## Segurança

- Uma key por dev; revogue/rotacione em `app.plane.so/sintetizaai → Profile → API Tokens` se vazar.
- `plane_config.json` com `chmod 600`. Nunca versione `.env`/keys.

## Fechamento

Resuma ao dev o que foi configurado e aponte o teste rápido: abrir um repo, rodar `/iniciar-task <ID>`,
fazer uma mudança, abrir PR (`<ID>: descrição`) e rodar `/fechar-task <ID>`.
