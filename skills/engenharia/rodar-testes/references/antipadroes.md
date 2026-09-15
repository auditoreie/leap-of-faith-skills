# Antipadrões de teste — o que não escrever, e a pergunta-gate de cada um

Use ao **escrever ou consertar** teste. Cada item: sintoma → por que é errado → o que fazer → a pergunta a responder antes de commitar.

## Fragilidade

1. **Seletor de implementação** (`.btn.primary`, xpath posicional). Quebra em refactor sem mudança de comportamento. Angular: `data-testid`, `By.css('[data-testid=…]')` ou harness do Material. *Gate:* se eu refatorar a estrutura interna e o usuário não notar, esse teste continua verde?
2. **Asserção de estrutura interna** ("método A foi chamado antes de B"). Reescreva como entrada → resultado observável. *Gate:* estou afirmando o que o código faz ou como faz?
3. **Testar método privado** por reflexão ou `as any`. Dirija-o pelo método público que o usa. *Gate:* o comportamento privado aparece em algum resultado público?
4. **Snapshot de tudo.** Sem contrato de artefato, snapshot só congela o acidente. Use asserções nomeadas. *Gate:* alguém revisaria a diff desse snapshot com atenção?

## Flakiness

5. **Espera por tempo** (`setTimeout`, `sleep`). Espere pela condição (`waitFor`, `fakeAsync` + `tick`, promessa do fluxo). *Gate:* o teste passa numa máquina 3× mais lenta?
6. **Dependência de ordem** entre casos. Cada `it` cria e destrói seu estado; `beforeEach`, não `beforeAll`, para estado mutável. *Gate:* o arquivo passa com `--randomize`?
7. **Relógio e fuso reais.** `Date.now`, `new Date()` sem controle. Injete o relógio ou use `jest.useFakeTimers`/`jasmine.clock()`. *Gate:* passa às 23:59 de 31/12 em UTC-3?
8. **Estado compartilhado com o banco.** Fixture global mutada por vários testes. Dado por teste, com identificador único, limpeza no fim. *Gate:* dois testes deste arquivo podem rodar em paralelo?

## Mocks

9. **Mock que devolve o que o teste afirma.** Prova só que o mock funciona. Mock na borda de I/O (repositório, HTTP, fila), assert no que o código fez com a resposta. *Gate:* se a regra de negócio sumir, esse teste falha?
10. **Mock do Prisma em teste de repositório.** O invariante é a query; sem banco não há teste. Use o Mongo do compose. *Gate:* o que estou provando sem executar a query?
11. **Mock de tudo no e2e.** E2E prova integração; mock só o que é externo pago ou não determinístico (gateway real, e-mail). *Gate:* o que resta de real nesse teste?

## Processo

12. **Consertar o teste para ficar verde.** Teste que expõe regressão é sinal. Só mude o teste com evidência de contrato alterado, citada no commit. *Gate:* mudei o teste ou a verdade?
13. **`skip` sem dono.** Todo `xit`/`skip` leva o ID da task que o reativa. *Gate:* quem reativa isso, quando?
14. **Suíte inteira por reflexo.** Rode o afetado primeiro. Suíte cheia é para mudança transversal ou pré-PR, uma por vez. *Gate:* que falha nova a suíte inteira pegaria que a spec afetada não pega?
15. **Cobertura como meta.** Cobertura acha ponto cego; não substitui oráculo de comportamento. Não crie branch em produção para cobrir. *Gate:* esse teste falha em algum bug real?

## Específicos de teste gerado por agente

16. **Teste que espelha a implementação com bug.** Escrito lendo o código, não o contrato. Derive o esperado da regra de negócio, ADR ou doc, e cite. *Gate:* de onde veio o valor esperado?
17. **Teste gigante que reimplementa a lógica.** Se o teste calcula o esperado com a mesma fórmula do código, prova nada. Use valores fixos conhecidos. *Gate:* o esperado está literal?
18. **Fixture inventada fora do domínio.** Valores irreais (CPF `123`, valor `1`) escondem regra. Use dados plausíveis do domínio (centavos, fuso, moeda). *Gate:* esse dado passaria na validação de produção?
