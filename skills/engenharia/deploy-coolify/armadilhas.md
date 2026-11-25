# Armadilhas conhecidas

Lazy-load da skill `deploy-coolify`. Leia quando o build ou o deploy falhar de um jeito que não bate com o código.

- **`bun install` cria symlinks para `node_modules/.bun/`.** Um `COPY --from` leva o link, não o
  conteúdo. Ferramentas que geram código dentro do pacote (Prisma) exigem materializar com `cp -RL`
  a partir do caminho real (`readlink -f`).
- **`bun install --production` não poda um `node_modules` já populado** — só instalação limpa. Use
  um estágio separado para as dependências de produção.
- **Merge de vários PRs dessincroniza o lockfile.** `bun install --frozen-lockfile` passa a falhar e
  quebra o build da imagem, enquanto local continua passando porque o `node_modules` já existe.
  Rode `bun install` e commite o lockfile depois de consolidar merges.
- **Imports absolutos (`from 'src/x'`) dependem de reescrita no build.** O `tsc` emite o
  especificador intacto; quem reescreve pode ser um transformer que roda numa plataforma e não em
  outra. Declare `paths` no tsconfig, use `tsc-alias`, e trave o build se sobrar
  `require("src/` no `dist`.
- **Branch com PR aberto que também dispara por push roda o build duas vezes.** Um dos runs não
  publica (é o de `pull_request`), o que confunde ao inspecionar com `--limit 1`.

