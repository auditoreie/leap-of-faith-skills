# auditore-skills

Repositório versionado de skills do Claude Code compartilhadas entre os projetos internos da Auditore.

## O que tem aqui

```
auditore-skills/
├── skills/                       ← cada subpasta é uma skill (com SKILL.md)
│   └── project-ledger/           ← ADRs versionados + tasks locais + ADRs gerados de tasks
├── docs/
│   └── creating-skills.md        ← guia pra adicionar novas skills
├── install.sh                    ← symlinka skills daqui para ~/.claude/skills/
├── HOWTO.md                      ← como usar
└── README.md
```

## Como começar

```bash
# Clone (ou pull se já existe)
git clone <repo> ~/auditore-skills

# Instala (cria symlinks em ~/.claude/skills/)
~/auditore-skills/install.sh
```

Depois, abra o Claude Code em qualquer projeto e as skills estarão disponíveis (ex: `/project-ledger init`).

Para detalhes de uso por skill, veja [HOWTO.md](HOWTO.md).
Para adicionar uma skill nova, veja [docs/creating-skills.md](docs/creating-skills.md).

## Filosofia

- **Skills reusáveis entre projetos** — nada amarrado a um único repo.
- **Token-efficient by default** — cada skill respeita um budget de leitura/escrita; ver instruções na SKILL.md de cada uma.
- **Local-first, sync opcional** — o estado vive no disco do dev. Sync com Notion/ClickUp só sob comando explícito.
- **Versionável e auditável** — toda mudança em skill compartilhada passa por commit aqui.
