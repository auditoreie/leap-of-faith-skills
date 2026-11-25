# Como escrever o changelog de release

Leia antes de escrever. O critério é um só: **quem lê decide o que fazer sem abrir o código nem o PR.**

## O que entra

Uma entrada por **mudança de comportamento observável** — não por PR, não por commit. Três PRs que juntos mudam um campo são uma entrada; um PR que muda três coisas são três.

Entra: campo novo/removido/renomeado, tipo ou valor que muda, endpoint novo, status HTTP novo, validação que passa a rejeitar o que antes aceitava, toggle que precisa ser ligado, mudança de schema que exige `prisma:gen`, comportamento que muda mesmo sem mudança de contrato (ex.: revalidação de token a cada request).

Não entra: refactor sem efeito externo, índice, teste, doc interna, bump de versão, CI. Se um PR é só isso, ele aparece na lista "PRs incluídos" e em nenhum outro lugar.

## Dois destinos, dois critérios

O **PR de release** é interno: quem lê é o release manager e o time. Nele entra **toda** mudança de comportamento observável, inclusive a que o time decidiu não anunciar publicamente — porque quem faz o deploy precisa saber que o valor de um campo mudou, mesmo que nenhum integrador vá ser avisado. Quando a decisão de não publicar existe, registre-a em itálico logo abaixo da entrada, com a razão vinda do comentário da task.

O **changelog público** (`CHANGELOG-API.md` ou equivalente) é do integrador, e a decisão de o que entra lá é do time, não desta skill. Esta skill só sinaliza no PR de release quando uma entrada do PR **não** tem correspondente no changelog público — para que a ausência seja uma decisão, não um esquecimento.

## Como decidir se um bug corrigido vira entrada

Pergunte: **alguém que consome isso precisa fazer algo diferente?** Se sim, é entrada — com a ação, não com a narrativa do defeito. Se ninguém precisa agir (bug interno, um cliente afetado já informado, nada muda no contrato), não é entrada. Essa decisão costuma estar nos **comentários da task**, não na descrição; leia-os.

## Forma

- **Breaking primeiro**, marcado. Breaking = quem não fizer nada vai quebrar ou vai ler dado errado.
- Título da entrada = endpoint ou área + o que mudou, em uma linha. Não é o título do PR.
- Corpo em três blocos, só os necessários: **O que muda** · **Ação necessária** · **O que não mudou** (quando há risco de o leitor supor que mudou).
- Verbo no presente, voz ativa, sem "foi implementado", "realizamos", "com o objetivo de".
- Valores concretos sempre: o nome do campo, o valor antes e depois, o código HTTP, a mensagem de erro literal.
- Sem justificativa interna ("porque o parser…"), sem crédito, sem número de task no corpo — o rastreio vai na tabela de PRs.

## Feature toggles

Uma linha por toggle, sempre com estes quatro dados, **lidos do código**:

| toggle | o que faz quando ligado | default | estado que esta release precisa |
|---|---|---|---|

- "Default" é o que acontece com a variável **ausente** — leia o `if`, não o `.env.example`.
- "Estado que a release precisa" é a ação do deploy: `ligar`, `desligar`, `nada a fazer`, `criar com valor X`.
- Toggle no código sem PR que o explique: primeira linha da tabela, com `⚠️ NÃO DECLARADO` — e o "o que faz" vem da leitura do código, mesmo que exija abrir o arquivo.
- Kill-switch (default ligado, variável desliga) é toggle e entra na tabela; a coluna "estado" fica `nada a fazer (kill-switch)`.
- Config por tenant (campo em `cliente`, `integrationConfig`) entra numa tabela própria, com a coluna "onde se configura" — se a resposta for "direto no banco", diga isso.

## Tamanho

Se a entrada precisa de mais de 8 linhas, ou é duas entradas ou está explicando demais. Corte a explicação antes de cortar a ação.

## Exemplo

```markdown
### ⚠️ Breaking — Todos os endpoints: 401 pode significar usuário ou hotel desativado

**O que muda:** a cada requisição a API confere se o usuário e o hotel da sessão continuam ativos. Antes, um token válido funcionava até expirar. Cache de 60s.

**Ação necessária:** trate `401` com mensagem `Usuário inativo` ou `Cliente inativo` como permanente — renovar o token não resolve. Integração com retry automático precisa limitar tentativas nesses dois casos.
```
