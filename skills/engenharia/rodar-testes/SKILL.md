---
name: rodar-testes
description: Escolhe, escreve e roda os testes certos para uma mudança respeitando os limites da máquina (16 GB, no máximo 2 processos de teste/build, workers limitados, nunca em background) — detecta os comandos do repo (Jest, Karma/Jasmine, e2e), nomeia o invariante antes de escrever teste, coloca o teste na camada mais baixa que observa a falha, e devolve evidência do que rodou e do que não rodou. Use quando o usuário disser "rodar os testes", "quais testes rodar pra isso", "escreve teste pra X", "esse teste está flaky", "cobre esse caso", "/rodar-testes [caminho|pacote]", "run tests". NÃO use para revisar código (isso é /review e /code-review), para achar a causa de um bug (isso é /debug-causa-raiz) nem para deploy.
---

# rodar-testes

Testes que podem expor a falha da mudança, na camada mais baixa que a observa, dentro do orçamento da máquina. Primeiro descobre como o repo testa; depois decide o que rodar ou escrever; por fim roda em foreground e reporta evidência, nunca suposição.

**Argumento:** `$ARGUMENTS` — caminho, pacote/app, nome de spec ou descrição da mudança. Vazio → usa o diff atual (`git diff --name-only origin/<integração>...HEAD` mais arquivos modificados) para achar o escopo.

`<skill-dir>` é a pasta desta `SKILL.md`.

## Token discipline

- `bash <skill-dir>/scripts/detectar-testes.sh <repo>` resolve package manager, pacotes, scripts de teste, configs de Jest/Karma, schema Prisma e processos node ativos. Não leia `package.json` inteiro à mão.
- Se houver ecossistema configurado (`<raiz>/.claude/ecossistema/produtos.md`, gerado por `/onboarding-ecossistema`), use a linha "Testes" do repo em vez de redescobrir.
- Leia `references/antipadroes.md` só quando for **escrever** ou **consertar** teste. Para só rodar, não.
- Saída de teste: `2>&1 | tail -60`. Leia o resumo e as falhas, não o log inteiro. Falha longa → `grep -nE 'FAIL|✕|Error|Expected|Received' | head -40`.

## Safe-mode

- Nunca roda teste ou build em background, nunca duas suítes completas ao mesmo tempo, nunca dois builds do mesmo app. Antes de qualquer suíte: `ps aux | grep -cE '[n]ode'`; muito acima de ~15, pare e mostre os processos antes de seguir.
- Jest sempre com `--maxWorkers=2` (ou `--runInBand` quando a suíte usa banco ou porta). Karma sempre `--watch=false --browsers=ChromeHeadless`. Suíte marcada como instável no `CLAUDE.md` do repo só roda com pedido explícito.
- Teste que expõe regressão → conserta o código de produção. Só altera o teste com evidência de que o contrato mudou de propósito. Nunca enfraquece asserção, nunca apaga teste, nunca marca `skip` sem ID de task.
- Não cria ramificação nem método em produção só para testar. Não adiciona snapshot, teste de prosa, CSS ou config sem um contrato real de artefato.
- `prisma generate` antes do Jest quando o schema mudou ou a branch trocou. Se outra worktree compartilha o client gerado, só com exclusividade (nenhum outro runner ativo).

## Fallback

Pré-requisito ausente ou falho (auth expirada, binário faltando, MCP indisponível, `ecossistema.json` inexistente, script com erro) **não encerra a skill**: diga em uma linha o que faltou e como resolver (`! gcloud auth login`, `/onboarding-ecossistema`, instalar a ferramenta), ofereça seguir sem essa parte e, com a aprovação do usuário, prossiga marcando no Output o que ficou **não verificado**. O que não muda: escrita externa (ClickUp, GCP, `git push`, banco) continua exigindo confirmação, e "não verificado" nunca vira "ok".

## Passos

1. **Descobrir.**
   ```bash
   bash <skill-dir>/scripts/detectar-testes.sh <repo>
   ```
   Saída: package manager por pacote, scripts `test*`/`e2e*`, configs, schema Prisma, contagem de processos node e as linhas do `CLAUDE.md` sobre teste. Essas linhas mandam: comando, suíte instável, ordem.

2. **Escopo → camada.** Para cada arquivo do escopo, a camada mais baixa que observa o invariante:

   | Mudou | Camada | Como |
   |---|---|---|
   | Regra de negócio em service/use-case (NestJS) | Unit (Jest) | mock só na borda de I/O (repositório, gateway HTTP); assert no resultado observável |
   | Repositório ou query Prisma-Mongo | Integração (Jest + Mongo do compose) | dado real no banco local; nada de mock do Prisma |
   | Controller, guard, DTO, contrato público | E2E de API (Jest e2e + supertest) | request → status e corpo; auth e authz incluídos |
   | Componente, pipe ou serviço Angular | Karma/Jasmine com TestBed | comportamento visível (DOM, output, chamada de serviço), nunca estrutura interna |
   | Fluxo ponta a ponta (checkout, webhook, split) | Scripts e2e do repo (compose, Playwright, bash) | só a pedido, um por vez; é o mais caro |
   | `schema.prisma` | `prisma generate` + Jest do repositório afetado | smoke de módulo se o repo tiver (ex.: `module-graph.smoke.spec.ts`) |

   Antes de escrever teste novo: **uma frase de invariante** ("`POST /refund` reduz o saldo exatamente no valor estornado"). Frase vaga ("o fluxo funciona") → não escreve ainda; refina.

3. **Rodar, um alvo por vez, em foreground.** Do mais barato ao mais caro: spec afetada (`jest <caminho> --maxWorkers=2`, `-t "<nome>"` para um caso) → pacote afetado → suíte do app só se a mudança for transversal. Karma: `ng test --watch=false --browsers=ChromeHeadless --include='<glob>'`. Reaproveite resultado para entrada que não mudou; expanda só em falha, edição relevante ou risco em aberto.

4. **Falhou?** Leia a primeira falha inteira e classifique: (a) regressão real → corrija produção, `/debug-causa-raiz` se a causa não for óbvia; (b) teste errado, com evidência de contrato alterado → ajuste o teste e diga por quê; (c) flaky → rode 3× com `--runInBand`; se alternar, procure estado compartilhado, relógio, ordem, porta. Não reexecute até passar.

5. **Escrever ou consertar teste** (quando pedido): leia `references/antipadroes.md`; reutilize fixtures e helpers existentes antes de criar arquivo; nome do teste = invariante; um comportamento por caso; dados mínimos; sem `any`.

## Output

```
Escopo: <arquivos/pacote> · invariantes: <n>
Rodado (foreground, sequencial):
  <comando exato> → passou | falhou (<n> testes, <tempo>)
Não rodado: <suíte> — <instável no CLAUDE.md | fora do escopo | exigiria 2º processo>
Falhas: <arquivo:linha — causa em 1 linha> | nenhuma
Testes novos/alterados: <caminho — invariante coberto> | nenhum
Próximo passo: <o que rodar antes do PR> | pronto para a seção "Como validei" do PR
```

"Não rodado" nunca vira "passou". Se algo ficou fora, está escrito.
