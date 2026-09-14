# release: <head> → <base> (<AAAA-MM-DD>)

<N> PRs · <M> tasks · <K> commits diretos · schema: <alterado/inalterado>

**Classe de risco:** <só as que se aplicam: docs · ui · api · dinheiro · schema · api-pública · segurança · infra>

**Resumo em uma linha:** <o que quem faz o deploy precisa saber, em uma frase>

## Feature toggles

<!-- Fonte: scripts/scan-toggles.sh cruzado com os PRs. NÃO DECLARADO sempre no topo. Removido entra como linha própria. -->

| toggle | o que faz quando ligado | default (var ausente) | estado que esta release precisa |
|---|---|---|---|
| ⚠️ NÃO DECLARADO `<VAR>` | <lido do código> | <lido do if> | <ligar/desligar/criar=X> |
| `<VAR>` | … | **ligado** (`!== 'false'`) | nada a fazer (kill-switch) |
| ~~`<VAR>`~~ **removido** | Antes: <o que o `if` fazia com a var ligada>. Agora: <o que vale sempre>. | — | nada a fazer; apagar a env se existir |

<!-- Sempre que o scan listar env var que NÃO é toggle (TZ, NODE_ENV, JWT_SECRET, DATABASE_URL, senha de serviço…): -->
Não são toggles, mas o scan os lista: `<VAR>` (<por quê é config e não ramificação>).

<!-- Só se houver: -->
### Configuração por tenant

| campo | o que faz | onde se configura | precisa preencher para |
|---|---|---|---|
| `cliente.<campo>` | … | direto no banco / tela X | <quais tenants, ou "nenhum agora"> |

<!-- Só se schema mudou: -->
> **Deploy:** `schema.prisma` alterado — rodar `bun run prisma:gen` na imagem. <migração de dados: sim/não>

## Changelog

<!-- Ver conventions.md. Breaking primeiro. Uma entrada por comportamento observável. Segurança logo depois de Breaking. -->

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
| #<n> | <ID> | <título do PR> | <breaking / só interno / sem task / "sem merge commit próprio (empilhado no #N)" / decisão relevante do comentário / status da task vs merge> |

<!-- Só se houver: -->
## Commits diretos (sem PR)

| commit | data | mensagem |
|---|---|---|
| `<hash>` | <data> | <mensagem> |

## Deploy

<!-- O que sobe sozinho no merge (workflow em push na <base>) e o que é manual (Cloud Run…), em ordem. prisma db push se schema mudou. Env a criar. Como verificar em produção. -->
<!-- Checks do PR de release: verde, ou vermelho com causa, se bloqueia o merge e como consertar. -->

1. …

## Pós-deploy (operação)

<!-- Só se houver. Nada disto é código: rotação de credencial, reset de senha, auditoria, ligar toggle, tornar check obrigatório. -->

- …

## Changelog do produto

<!-- Só se o repo tiver changelog de usuário. Uma linha por entrada do changelog acima: a ausência tem que ser decisão, não esquecimento. -->

| entrada desta release | no changelog público? | decisão e onde está registrada |
|---|---|---|
| <área: o que mudou> | presente / ausente por decisão / ausente sem decisão | <comentário da task/PR, ou "—"> |

<!-- Para as "ausente sem decisão": bloco pronto para colar, na voz do arquivo. Publicar item de segurança é decisão do time. -->

## Fora desta release

<!-- Decisões registradas em PR ou task que EXCLUEM algo que o leitor poderia esperar aqui. -->
- <o que ficou de fora e onde está a decisão>
