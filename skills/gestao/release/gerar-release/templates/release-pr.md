# release: <head> → <base> (<AAAA-MM-DD>)

<N> PRs · <M> tasks · <K> commits diretos · schema: <alterado/inalterado>

## Feature toggles

<!-- Fonte: scripts/scan-toggles.sh cruzado com os PRs. NÃO DECLARADO sempre no topo. -->

| toggle | o que faz quando ligado | default (var ausente) | estado que esta release precisa |
|---|---|---|---|
| ⚠️ NÃO DECLARADO `<VAR>` | <lido do código> | <lido do if> | <ligar/desligar/criar=X> |
| `<VAR>` | … | … | nada a fazer (kill-switch) |

<!-- Sempre que o scan listar env var que NÃO é toggle (TZ, JWT_SECRET, DATABASE_URL…): -->
Não são toggles, mas o scan os lista: `<VAR>` (<por quê é config e não ramificação>).

<!-- Só se houver: -->
### Configuração por tenant

| campo | o que faz | onde se configura | precisa preencher para |
|---|---|---|---|
| `cliente.<campo>` | … | direto no banco / tela X | <quais tenants, ou "nenhum agora"> |

<!-- Só se schema mudou: -->
> **Deploy:** `prisma/schema.prisma` alterado — rodar `bun run prisma:gen` na imagem. <migração de dados: sim/não>

## Changelog

<!-- Ver conventions.md. Breaking primeiro. Uma entrada por comportamento observável. -->

### ⚠️ Breaking — <área>: <o que mudou>

**O que muda:** …
**Ação necessária:** …

### <área>: <o que mudou>

**O que muda:** …
**O que não mudou:** …

## PRs incluídos

<!-- Um por linha. Task = ID do ClickUp extraído do título/branch/corpo, ou "—". -->

| PR | task | título | nota |
|---|---|---|---|
| #<n> | <ID> | <título do PR> | <breaking / só interno / sem task / decisão relevante do comentário> |

<!-- Só se houver: -->
## Commits diretos (sem PR)

| commit | data | mensagem |
|---|---|---|
| `<hash>` | <data> | <mensagem> |

## Fora desta release

<!-- Decisões registradas em PR ou task que EXCLUEM algo que o leitor poderia esperar aqui. -->
- <o que ficou de fora e onde está a decisão>
