# team-skills

Repositório versionado de skills do Claude Code compartilhadas entre os times — **Auditore** e **Sintetiza**. Skills reusáveis e organizadas **por ferramenta**, pra ficar claro o que é genérico e o que é específico de uma ferramenta (Plane, Meta WhatsApp, etc.).

## O que tem aqui

```
team-skills/
├── skills/                       ← cada pasta com um SKILL.md é uma skill (em qualquer profundidade)
│   ├── desmond/                  ← genérica: modo tri-modelo Opus/Fable/Mythos (tokens + orquestração)
│   ├── project-ledger/           ← genérica: ADRs versionados + tasks locais
│   ├── plane/                    ← ferramenta: Plane (workflow de tasks)
│   │   ├── iniciar-task/         ← abre task + cronômetro + executa
│   │   ├── reportar-task/        ← reporta/loga tempo e custo sem fechar
│   │   ├── fechar-task/          ← encerra: tempo, tokens, custo, comentário
│   │   └── plane-onboarding/     ← setup da API key/MCP do Plane por dev
│   └── meta-waba/                ← ferramenta: Meta WhatsApp Business API (referência)
├── docs/
│   └── creating-skills.md        ← guia pra adicionar novas skills
├── install.sh                    ← symlinka skills daqui para ~/.claude/skills/ (recursa em skills/**)
├── SYNC.md                       ← como manter os dois repos (Auditore + Sintetiza) em sincronia
├── HOWTO.md                      ← como usar
└── README.md
```

O nome do symlink instalado é o **basename da pasta da skill** (ex: `reportar-task`), independente da ferramenta sob a qual ela está agrupada. Nomes devem ser únicos entre todas as skills.

## Como começar

```bash
# Clone (ou pull se já existe)
git clone <repo> ~/team-skills

# Instala (cria symlinks em ~/.claude/skills/)
~/team-skills/install.sh
```

Depois, abra o Claude Code em qualquer projeto e as skills estarão disponíveis (ex: `/project-ledger init`, `/reportar-task SINTE-25`).

Para detalhes de uso por skill, veja [HOWTO.md](HOWTO.md).
Para adicionar uma skill nova, veja [docs/creating-skills.md](docs/creating-skills.md).

## Dois repos, um conteúdo

Como Auditore e Sintetiza são orgs separadas (sem seats compartilhados), o conteúdo vive espelhado em **dois repositórios** que recebem PRs cada um do seu time. A reconciliação entre eles segue o ritual em [SYNC.md](SYNC.md). **Auditore é o primário** (referência); Sintetiza é o espelho.

## Filosofia

- **Skills reusáveis entre projetos** — nada amarrado a um único repo.
- **Organização por ferramenta** — skills específicas de uma ferramenta vivem sob `skills/<ferramenta>/`; genéricas ficam na raiz de `skills/`.
- **Token-efficient by default** — cada skill respeita um budget de leitura/escrita; ver instruções na SKILL.md de cada uma.
- **Local-first, sync opcional** — o estado vive no disco do dev. Sync com Notion/ClickUp só sob comando explícito.
- **Versionável e auditável** — toda mudança em skill compartilhada passa por commit aqui.
