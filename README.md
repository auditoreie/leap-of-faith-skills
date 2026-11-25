# leap-of-faith-skills

Skills do [Claude Code](https://claude.com/claude-code) mantidas pela **Auditore** — reusáveis entre
projetos, organizadas por tema e escritas com disciplina de token.

Uma skill é conhecimento que para de ser re-explicado: em vez de descrever o mesmo processo a cada
sessão, ele vira um arquivo que o agente carrega quando precisa e ignora quando não precisa.

**Contribuições são bem-vindas.** Fork, escreva, valide, mande o PR — veja
[CONTRIBUTING.md](CONTRIBUTING.md).

## O que tem aqui

```
leap-of-faith-skills/
├── skills/
│   ├── engenharia/               ← como o agente trabalha
│   │   ├── auditoria-arquitetural/   código morto, duplicação e ciclos num escopo TypeScript
│   │   ├── debug-causa-raiz/         bug até a causa raiz antes de qualquer fix
│   │   ├── deploy-coolify/           deploy no Coolify (OCI) com rollback por SHA
│   │   ├── desmond/                  orquestração token-efficient (acionamento explícito)
│   │   ├── despachar-dev/            modelo do subagente por complexidade e risco
│   │   ├── entrevistar/              entrevista em rodadas até fechar as decisões (primitiva)
│   │   ├── frontend-design/          direção visual de UI (Anthropic, sem alteração)
│   │   ├── julgar-pr/                review de PR com gate de evidência e publicação única
│   │   ├── migracao-segura-prisma-mongo/  expand/contract de schema Prisma sobre MongoDB
│   │   ├── rebase-seguro/            rebase com backup ref e confirmação
│   │   ├── revezar-agentes/          paralelismo e revezamento de agentes quando a cota acaba
│   │   ├── rodar-testes/             testes certos dentro dos limites da máquina
│   │   └── validar-skill/            gate de contribuição: segredos, estrutura, escopo
│   ├── gestao/                   ← fluxo de trabalho e rastreabilidade
│   │   ├── criar-task/               discovery + criação de task no ClickUp
│   │   ├── licoes-aprendidas/        lição de engenharia de uma branch, PR ou task
│   │   ├── onboarding-ecossistema/   config por cliente (repos, ClickUp, GCP), fora do repo
│   │   ├── orcar-projeto/            orçamento com medição real, PERT e prêmio de risco
│   │   ├── project-ledger/           ADRs versionados + tasks locais
│   │   └── release/gerar-release/    PR de release com changelog e toggles conferidos no diff
│   └── integracoes/              ← plataformas externas
│       ├── consultar-docs/           doc versionada via Context7
│       ├── logs-gcp/                 observabilidade somente leitura no GCP
│       └── meta-waba/                WhatsApp Business Platform (Cloud API/Graph API)
├── docs/creating-skills.md       ← como criar e documentar uma skill
├── CONTRIBUTING.md               ← fluxo de fork, PR e backlog de ideias
├── HOWTO.md                      ← uso de cada skill no dia a dia
├── .githooks/pre-commit          ← gate de validação, roda a cada commit
├── install.sh                    ← symlinks + ativação do hook
└── LICENSE                       ← PolyForm Noncommercial 1.0.0
```

O nome instalado é o **basename da pasta da skill** — `skills/gestao/release/gerar-release/` vira
`gerar-release`. O agrupamento por tema é organização do repositório, não faz parte do nome. Nomes
precisam ser únicos.

## Skills

### engenharia

| Skill | O que faz |
|---|---|
| **`desmond`** | Modo de orquestração de acionamento explícito (`/desmond`): planeja antes de agir, despacha cada trabalho pro agente mais barato que dá conta e reserva o modelo de fronteira pra síntese e decisão. Para tarefa grande e multi-arquivo com o mínimo de tokens. |
| **`entrevistar`** | Primitiva de perguntas (`/entrevistar <tema>`): mapeia o tema como árvore de decisões, pergunta a cada rodada só a fronteira, numera as perguntas com a recomendação na frente, resolve sozinha o que é fato e para quando a fronteira esvazia e o usuário confirma. `/spec`, `criar-task` e `desmond` chamam esta. |
| **`julgar-pr`** | Review de PR com régua de evidência (`/julgar-pr 123 [publicar]`): roda o gate do próprio repo, passa o diff por scanner de bypass, obtém os achados pelo `/code-review`, verifica as afirmações do PR e só aceita texto que passe no `review_gate.py` (evidência obrigatória em blocker, máximo 5 nits, veredito consistente). Publica uma única review no GitHub só com `publicar`. Scripts vendorizados da the-judge (Tech Leads Club), ver `NOTICE.md`. |
| **`revezar-agentes`** | Paralelismo e controle quando os tokens acabam (`/revezar-agentes` com `status`, `bastão`, agente/conta ou `despachar <tarefa>`): escolhe agente, conta e modelo pelo peso da tarefa, despacha workers pelo Orca com ficha de prefixo fixo e relatório em schema, passa o bastão e mantém o registro de contas e resets no ai-memory, troca de conta por menu (`revezar`), e aplica os gates (worktree sem segredo, ai-jail opcional, sem push/deploy, no máximo 2 testes por vez na máquina). Guia de uso em `GUIA.md`. |
| **`validar-skill`** | Gate de contribuição. Audita uma skill ou o PR inteiro antes de publicar: bloqueia segredo, `.env`, chave privada, PII e dado de cliente; valida frontmatter, nome único e estrutura; reprova escopo inválido e conteúdo prejudicial. Inclui `scripts/scan.sh`. |
| **`rodar-testes`** | Escolhe, escreve e roda os testes certos para uma mudança dentro dos limites da máquina (workers limitados, uma suíte por vez, nunca em background): detecta os comandos do repo, nomeia o invariante e reporta o que rodou e o que não rodou. |
| **`migracao-segura-prisma-mongo`** | Expand/contract para schema Prisma sobre MongoDB (sem Migrate): classifica a mudança, ordena deploy × `db push` × backfill idempotente com dry-run, e entrega o plano para a classe de risco `schema` do PR. |
| **`auditoria-arquitetural`** | Código morto, duplicação e ciclos de import num escopo TypeScript, com scanner `rg` + `madge` que entende DI do Nest e templates Angular; rastreia uso antes de declarar algo morto. |
| **`debug-causa-raiz`** | Bug até a causa raiz antes de qualquer fix: reproduz, instrumenta fronteiras, uma hipótese por vez, teste que falha primeiro; três tentativas falhas viram questão de arquitetura. |
| **`rebase-seguro`** | Rebase com backup ref, confirmação explícita, conflitos lidos dos dois lados e publicação só com `--force-with-lease` autorizado. |
| **`despachar-dev`** | Escolhe o modelo do subagente de desenvolvimento por complexidade (C1–C3) e risco (R1–R2), mostra a ficha de despacho e mede o custo por classe (`scripts/custo.py`). `desmond` usa esta tabela. |
| **`deploy-coolify`** | Serviço no Coolify da Auditore (OCI, ARM): imagem no GitHub Actions → GHCR → webhook, health check que testa o banco e rollback por SHA. |
| **`frontend-design`** | Direção visual intencional ao construir ou refazer UI. Skill da Anthropic sem alteração (Apache 2.0, ver `NOTICE.md`). |

### gestao

| Skill | O que faz |
|---|---|
| **`project-ledger`** | Decisões de engenharia (ADRs versionados em `docs/adr/`) e trabalho ativo (tasks locais, fora do git). `init` faz o bootstrap do repositório; fechar uma task gera o ADR. Sync com Notion/ClickUp só sob comando explícito. |
| **`onboarding-ecossistema`** | Uma vez por cliente: detecta os repos de uma pasta raiz e o harness de cada um, pergunta lista do ClickUp, campos e serviços GCP, e grava `<raiz>/.claude/ecossistema.json` + `ecossistema/*.md` — fora de qualquer repo público. |
| **`criar-task`** | Discovery + validação + criação de task no ClickUp: enquadra o repo, lê CLAUDE.md e ADRs, faz pré-triagem (PR aberto, branch, task duplicada), pergunta o que o código não responde, projeta localmente e cria na lista configurada com assignee e link. |
| **`licoes-aprendidas`** | A lição de engenharia que uma branch, PR ou task demonstra, ancorada em commit e arquivo:linha; destino opt-in em comentário ou nota de ADR. |
| **`gerar-release`** | PR de release entre duas branches: PRs mergeados (inclusive empilhados, squash e rebase) cruzados com as tasks do ClickUp, e toggles conferidos no diff, não no que o PR declara. Modo preencher escreve direto num PR de release já aberto. |
| **`orcar-projeto`** | Orçamento e proposta técnica a partir dos documentos do cliente: mede o sistema real, estima por item com PERT, forma o preço com prêmio de risco explícito e calcula o gross-up tributário. Toda linha rotulada pela origem. |

Fluxo ClickUp: `onboarding-ecossistema` (uma vez por cliente) → `criar-task` (por demanda). IDs de workspace, lista e
campos, repos e mapa GCP ficam em `<raiz>/.claude/ecossistema.json` e `ecossistema/*.md`, nunca neste repositório —
`validar-skill` bloqueia esses arquivos no commit.

### integracoes

| Skill | O que faz |
|---|---|
| **`meta-waba`** | Referência curada da WhatsApp Business Platform: templates (incluindo header de vídeo por Resumable Upload), ciclo de vida de números, webhooks com HMAC SHA-256, Flows com endpoint criptografado, analytics, Embedded Signup/Tech Provider e códigos de erro reais. Detalhe em `references/`, com scripts em TypeScript. |
| **`logs-gcp`** | Observabilidade somente leitura no GCP (Cloud Run, Cloud Build, Error Reporting, Firebase Hosting) enquanto não há Sentry: logs por serviço/janela/texto, revisões e tráfego, deploys recentes, grupos de erro. |
| **`consultar-docs`** | Documentação atualizada e versionada via Context7 CLI (`npx ctx7`) antes de responder de memória, com IDs pré-resolvidos para NestJS, Prisma, Angular, RxJS, Jest e outras. |

## Começando

```bash
git clone git@github.com:auditoreie/leap-of-faith-skills.git ~/leap-of-faith-skills
~/leap-of-faith-skills/install.sh
```

O `install.sh` recursa em `skills/**/SKILL.md`, cria um symlink por skill em `~/.claude/skills/` e não
sobrescreve nada divergente sem perguntar. Também ativa o **gate de validação**: `core.hooksPath`
aponta pra `.githooks/`, e todo commit passa pelo scanner de segredos antes de entrar. Atualizar
depois é `git pull`.

Abra o Claude Code em qualquer projeto e as skills estarão disponíveis — por comando
(`/project-ledger init`) ou por intent, quando o que você pedir casar com a `description` da skill.

Uso detalhado: [HOWTO.md](HOWTO.md) · Criar uma skill: [docs/creating-skills.md](docs/creating-skills.md)

## Contribuindo

O valor deste repositório é proporcional ao número de pessoas que o usam de verdade e devolvem o que
aprenderam. Se você teve que explicar o mesmo padrão ao Claude duas vezes em projetos diferentes,
isso é uma skill — e ela cabe aqui.

1. **Fork** e branch a partir da `main`
2. Escreva seguindo [docs/creating-skills.md](docs/creating-skills.md)
3. **Use de verdade** algumas vezes antes de mandar
4. Rode o gate: `./skills/engenharia/validar-skill/scripts/scan.sh`
5. Abra o PR

Correções contam tanto quanto skills novas: passo que quebrou porque a API mudou, `description` que
dispara na hora errada, exemplo que não funciona mais. [CONTRIBUTING.md](CONTRIBUTING.md) tem o fluxo
completo e um **backlog aberto de ideias** — revisão de PR, investigação de bug, auditoria de
dependências, acessibilidade, i18n, novas integrações. Pegue uma.

Na dúvida se a sua ideia cabe: abra uma issue antes de escrever.

## Filosofia

- **Reusável entre projetos** — nada amarrado a um único repositório.
- **Token-efficient por padrão** — cada skill declara o que ler e o que não ler; detalhe é lazy-load.
- **Safe-mode por padrão** — skill não faz git, não deleta e não chama API externa sem comando.
- **Local-first** — o estado vive no disco do dev; sync externo é sempre explícito.
- **Sem segredo, nunca** — credencial se lê de config local. O gate de validação existe pra garantir.
- **Manutenção > acumulação** — uma skill excelente vale mais que dez abandonadas.

## Licença

[PolyForm Noncommercial License 1.0.0](LICENSE) — Copyright (c) 2026 Auditore.

Você pode usar, modificar e redistribuir livremente para **qualquer fim não-comercial**: estudo,
pesquisa, projeto pessoal, uso em organização sem fins lucrativos, instituição de ensino ou órgão
público. Uso comercial por terceiros exige licença específica — fale com a Auditore.

Redistribuindo, mantenha o aviso de copyright e a licença junto. Não é uma licença aprovada pela OSI,
justamente porque restringe uso comercial; é uma licença *source-available*.
