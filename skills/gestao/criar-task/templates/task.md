<!-- Título: ação + objeto específico + resultado/critério. Efeito observável > jargão. Sem verbo vago sozinho. -->
<!-- Cabeçalho local (NÃO vai para o ClickUp): -->
<!-- repo: <caminho> · produto: <label> · tipo: Erro|Melhoria|Suporte · assignee: <nome> · base: origin/<int> @ <sha> (<data>) -->
<!-- clickup: <preencher após criar: <PREFIXO>-NNNN · url> -->

## Problema

<!-- Quem sente, o que acontece hoje, como sabemos. Bug: passos → esperado × obtido. Cite a evidência (cliente, log, arquivo:linha). 3-6 linhas. -->
<!-- Tipo Erro: acrescente a linha abaixo (rubrica em references/qa-impacto.md). -->

**Impacto (usuário):** <Blocks-Completion | Data-Loss | Trust-Damage | Friction | Cosmetic> — <por quê, em meia linha>

## Contexto no código

<!-- Só o que foi aberto nesta sessão. `caminho/arquivo.ts:linha` — o que faz hoje · ADR-NNN (status) — o que decide · doc — o que diz. -->

-

## Escopo

<!-- Numerado, cada item verificável. Mais de 6 itens: provavelmente são duas tasks. -->

1.

## Fora de escopo

<!-- Explícito. É o que impede a task de inflar. Para feature, "nenhum" não é resposta. -->

-

## Decisões a preservar

<!-- Regras do harness e dos ADRs que restringem a implementação. -->

- ADR-NNN — <regra que afeta esta task>
- Toggle `<NOME>` default-OFF · liga em <env / config por tenant / environment.ts> · OFF = caminho atual idêntico

## Critério de aceite

<!-- Cada item testável. Comandos exatos do repo (references/produtos.md). -->

- [ ]
- [ ] Testes: `<comando exato>` verde, incluindo os novos para <o que mudou>
- [ ] Com o toggle OFF, comportamento atual inalterado
- [ ] Estado final verificado por caminho independente (tela ou API pública, após refresh), não só pelo banco

## Classe de risco

<!-- Taxonomia sugerida; adapte ao PR template do repo. Dinheiro, schema, api-pública, segurança e infra costumam exigir 2 aprovações. -->

docs · ui · api · dinheiro · schema · api-pública · segurança · infra → **<marcadas>**

## Bloqueio

<!-- Só se houver: ADR Proposto a aceitar (<PREFIXO>-…), PR aberto do mesmo tema (#N), contrato do outro produto. Remova a seção se não há. -->

## Decisões pendentes

<!-- O que o discovery não fechou, com dono. Escreva "Nenhuma." se vazio — a seção não é omitida. -->

-

## Relacionado

<!-- PR #N (estado, autor) · <PREFIXO>-NNNN (status) · ADR-NNN · doc. Só o que foi aberto nesta sessão. -->

-
