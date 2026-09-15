# Produtos e repos do ecossistema <nome>

A raiz de trabalho é `<raiz>`; cada subpasta listada é um repo git independente. Caminhos relativos a ela. Este arquivo é lido pelas skills `criar-task`, `rodar-testes` e `migracao-segura-prisma-mongo`; edite à mão quando o harness mudar e rode `/onboarding-ecossistema` de novo quando entrar repo novo.

## Skills irmãs

`/criar-task` · `/rodar-testes` · `/migracao-segura-prisma-mongo` · `/debug-causa-raiz` · `/logs-gcp` (mapa em `gcp-servicos.md`) · `/auditoria-arquitetural` · `/licoes-aprendidas` · `/rebase-seguro` · `/consultar-docs`.

## Namespace de task

Prefixo `<PREFIXO>-NNNN` (custom ID do ClickUp). Branch: `<feat|fix|chore|docs>/<slug>_<PREFIXO>-NNNN`. Título de PR: `<type>(<escopo>): <ação + objeto + resultado>` com `(<PREFIXO>-NNNN)`. A task nasce antes da branch.

## <Produto A> — `<caminho>`

| Campo | Valor |
|---|---|
| Remote | `<org/repo>` |
| Integração / produção | `<dev>` / `<main>` |
| Harness | `<CLAUDE.md>` · PR template `<.github/...>` |
| ADRs | `<pasta>` · índice `<README.md>` · status usados |
| Docs de domínio | `<docs/...>` |
| Apps / packages | `<lista com stack e package manager>` |
| Testes | `<comandos exatos, com limite de workers>` |
| Schema / backfill | `<schema.prisma>` · `<comando db push>` · `<pasta de backfills>` |
| Regras que entram na task | `<toggle default-OFF, PR por package, classes de risco...>` |
| ClickUp | Produto `<label>` · Escopo de Deploy `<opção>` |

## Roteamento entre produtos

| Sinal na demanda | Repo |
|---|---|
| `<sinais do produto A>` | A |
| `<sinais do produto B>` | B |
| `<contrato compartilhado: webhook, DTO, toggle>` | **Perguntar**: duas tasks coordenadas ou uma com dono |
| Nenhum sinal claro | **Perguntar** |

## Outros repos na raiz (não mapeados)

`<lista>` — confirmar com o usuário e mapear aqui antes de rotear.
