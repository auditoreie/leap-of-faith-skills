---
name: auditoria-arquitetural
description: Audita um escopo de código TypeScript (módulo NestJS, feature Angular, pacote) em busca de código morto, duplicação, ciclos de import, responsabilidade confusa e smells caros de manter — varre com script determinístico (rg + madge), rastreia uso real antes de declarar algo morto (DI do Nest, módulos dinâmicos, templates e rotas Angular, testes, API pública) e entrega achados com arquivo:linha, custo e a menor mudança útil, separando o que foi inspecionado do que não foi. Use quando o usuário disser "auditoria arquitetural", "tem código morto aqui?", "dependência circular", "onde está duplicado", "esse módulo está inchado", "/auditoria-arquitetural <pasta>". NÃO use para revisar um diff (isso é /review e /code-review), para segurança (isso é /security-review), para performance, nem para aplicar refactor sem pedido explícito.
---

# auditoria-arquitetural

Auditoria é **leitura**: produz achados confirmados no fonte, não uma lista de palpites. Limiar é pista, não defeito. "Não encontrado no checkout" não é "morto": API pública, DI, módulo dinâmico e template contam como uso.

**Argumento:** `$ARGUMENTS` — a pasta ou módulo (ex.: `apps/api/src/payments`, `packages/dash/src/app/reservas`). Vazio → pergunte o escopo; nunca audite o repo inteiro sem pedido, e mesmo assim por pacote.

`<skill-dir>` é a pasta desta `SKILL.md`.

## Token discipline

- `bash <skill-dir>/scripts/scan.sh <pasta>` faz a varredura (maiores arquivos, exports sem referência, providers e módulos Nest sem uso aparente, seletores Angular sem uso em template, nomes duplicados, ciclos via madge). Não leia arquivos até ter a lista de candidatos.
- Depois do scan, leia **só o entorno** de cada candidato (`sed -n` ±20 linhas) e o que o rastreio exigir. Nunca o arquivo inteiro de um service grande.
- Leia `references/catalogo-deteccao.md` ao **classificar** um candidato, na seção correspondente; não antes.
- Escopo com mais de ~400 exports: o script avisa; divida por subpasta ou delegue o rastreio de uso a um `Explore` com `model: haiku` (só leitura), um lote de símbolos por agente, síntese inline.
- Ciclos: `madge` via `bunx` (ou `npx`) precisa de rede na primeira vez; se falhar, o relatório diz "ciclos: não verificado", nunca "nenhum".

## Safe-mode

- Só leitura por padrão. Remediação só com pedido explícito, **um achado por PR**, com teste que prove que nada observável mudou (`/rodar-testes`).
- Nunca apaga export, provider ou componente por estar sem referência no checkout. Antes: DI (`providers:`/`exports:` de módulos, `forRoot*`/`register*`), templates e rotas (`loadComponent`, `loadChildren`), testes, API pública (`/v1`, contratos de integrador), scripts em `package.json`.
- Áreas não inspecionadas aparecem no relatório como não inspecionadas. Cobertura ausente nunca vira "nenhum achado".
- Achado que implica decisão de desenho (fronteira de módulo, dono de um conceito) vira proposta de ADR via `project-ledger`, não refactor silencioso.

## Fallback

Pré-requisito ausente ou falho (auth expirada, binário faltando, MCP indisponível, `ecossistema.json` inexistente, script com erro) **não encerra a skill**: diga em uma linha o que faltou e como resolver (`! gcloud auth login`, `/onboarding-ecossistema`, instalar a ferramenta), ofereça seguir sem essa parte e, com a aprovação do usuário, prossiga marcando no Output o que ficou **não verificado**. O que não muda: escrita externa (ClickUp, GCP, `git push`, banco) continua exigindo confirmação, e "não verificado" nunca vira "ok".

## Passos

1. **Varrer.**
   ```bash
   bash <skill-dir>/scripts/scan.sh <pasta>            # adicione --no-madge para pular ciclos
   ```
   Guarde a saída; ela é a lista de candidatos e a evidência de cobertura.

2. **Classificar** cada candidato com `references/catalogo-deteccao.md`: morto · duplicado · ciclo · dono confuso · tipo confuso · padrão de mudança caro. Descarte com uma linha o que o catálogo desqualifica (ex.: módulo raiz sem importador é normal).

3. **Rastrear antes de afirmar.** Para "morto": `rg -n -w <símbolo>` no repo inteiro (não só no escopo), inclusive `*.html`, `*.spec.ts`, `*.module.ts`, `package.json`, docs de API. Para ciclo: leia os dois lados e diga qual dependência é acidental. Para duplicação: abra as duas cópias e confirme que fazem a mesma coisa pelo mesmo motivo (duas cópias com motivos diferentes não são duplicação).

4. **Confirmar no fonte.** Cada achado material tem `arquivo:linha`, o custo concreto (o que quebra, o que fica caro de mudar, o que já causou incidente) e a menor mudança útil. Diga a incerteza quando houver.

5. **Relatar.** Achados por prioridade (incidente conhecido > ciclo > dono confuso > morto > duplicado > smell), seguido de "Inspecionado" e "Não inspecionado". Salve em `.claude/tasks/auditoria-<escopo>-<AAAA-MM-DD>.md` quando a pasta existir e estiver ignorada pelo git; senão no scratchpad. Pedido pontual ("tem ciclo aqui?") → só a lista curta, sem arquivo.

6. **Encaminhar.** Achado com decisão → ADR (`project-ledger`). Achado com trabalho → task (`/criar-task`, uma por achado). Refactor imediato só se pedido.

## Output

```
Escopo: <pasta> · <n> arquivos · maiores: <arquivo (linhas)> …
Ciclos: <n> (<A → B → A>) | não verificado (<motivo>)
Achados (prioridade):
  1. <tipo> — <arquivo:linha> — <custo em 1 linha> — <menor mudança útil>
  …
Descartados após rastreio: <símbolo — onde é usado (DI/template/teste/API)> …
Inspecionado: <pastas/arquivos> · Não inspecionado: <o que ficou fora e por quê>
Encaminhamento: <ADR proposto | tasks sugeridas | nada a fazer>
Relatório: <caminho> | inline
```
