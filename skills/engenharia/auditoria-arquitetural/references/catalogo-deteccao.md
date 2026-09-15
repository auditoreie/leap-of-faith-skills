# Catálogo de detecção — o que é pista, o que confirma, o que desqualifica

Limiar é pista. Achado só existe depois do rastreio. Cada item: sinal → como confirmar → o que desqualifica → menor mudança útil.

## Código morto

- **Export sem referência** (o scan lista). Confirmar: `rg -n -w <nome>` no repo inteiro, inclusive `*.html`, specs, `package.json`, docs de API pública. Desqualifica: uso em template Angular, em rota `loadComponent`/`loadChildren`, em módulo dinâmico (`forRoot`, `register`), em contrato público (`/v1`, DTO de integrador), em script. Mudança: remover export e arquivo; se for API pública, deprecar antes.
- **Provider `@Injectable` fora de qualquer `*.module.ts`**. Confirmar: não é `useClass`/`useFactory` em outro módulo, nem provider de teste, nem instanciado à mão. Desqualifica: provider de módulo dinâmico ou registrado por token. Mudança: registrar onde é usado ou remover.
- **Módulo Nest nunca importado**. Desqualifica: módulo raiz (`AppModule`) e módulos carregados em bootstrap. Mudança: remover módulo e seus providers exclusivos.
- **Componente/pipe/diretiva Angular com seletor sem uso em template**. Desqualifica: componente roteado (`component:` ou `loadComponent`), componente aberto por `MatDialog`/`ComponentFactory`, seletor de atributo (`[appX]`, que o scan não cobre). Mudança: remover ou tornar roteado explicitamente.
- **Toggle morto**: leitura de `process.env.X`/`environment.x` cujo valor é fixo em todos os ambientes há muito tempo, ou toggle já 100% ligado. Confirmar: env dos serviços (skill de deploy/`logs-gcp`), data do PR que ligou. Mudança: PR próprio removendo o toggle e o caminho antigo (classe de risco do caminho removido).

## Duplicação

- **Mesmo nome de arquivo em pastas diferentes** (o scan lista). Confirmar: abra as duas; duplicação é mesma responsabilidade pelo mesmo motivo. Desqualifica: mesmo nome, contextos diferentes (`payment.dto.ts` de dois bounded contexts com contratos distintos). Mudança: extrair para módulo compartilhado só se os dois mudam juntos; senão, renomear para explicitar a diferença.
- **Dois services com o mesmo verbo de domínio** (`*PaymentService`, `*ChargeService`). Confirmar: quem chama cada um e por quê. Mudança: um vira fachada do outro, ou um é removido; decisão de dono → ADR.
- **Bloco copiado com pequenas variações** (mapeamento de status de gateway, cálculo de taxa). Confirmar: `rg` por uma constante ou string peculiar do bloco. Mudança: extrair função pura com os casos parametrizados e testes de tabela.

## Ciclos

- **Import circular** (madge). Confirmar: qual lado depende do outro por acidente (geralmente um tipo ou constante que deveria morar num terceiro arquivo). Custo: em Nest, `forwardRef` e injeção `undefined` em runtime; já derrubou produção em repos do ecossistema. Mudança: mover o tipo/constante compartilhado para arquivo próprio; nunca "resolver" com `forwardRef` sem entender o ciclo.
- **`forwardRef` existente** é sintoma, não solução. Trate como ciclo a resolver.

## Dono confuso

- **Service gigante** (> 500 linhas ou > 15 métodos públicos) misturando regra, orquestração e I/O. Confirmar: liste os motivos de mudança dos últimos 20 commits (`git log --format=%s -20 -- <arquivo>`); mais de 3 temas distintos = divergent change. Mudança: extrair por motivo de mudança, um por PR, mantendo a fachada.
- **Controller com regra de negócio** (cálculo, decisão, acesso a repositório direto). Mudança: mover para service/use-case; controller só valida, autoriza e traduz.
- **Repositório com regra** (decide status, calcula valor). Mudança: repositório persiste e consulta; regra sobe.
- **DTO usado como entidade de domínio** dentro do service. Mudança: mapear na borda; domínio não conhece transporte.
- **Shotgun surgery**: uma mudança pequena toca N módulos (ver `git log --stat` de PRs recentes). Sinal de conceito sem dono. Mudança: nomear o conceito e dar-lhe um módulo → ADR.

## Tipos

- **`any`, `as unknown as`, `!` em cadeia**. Confirmar: `rg -n '\bany\b|as unknown as|!\.' <pasta>`. Nos repos do ecossistema `any` é proibido por CLAUDE.md. Mudança: tipo explícito ou `unknown` + narrowing.
- **Enum/string literal duplicado** (mesmos valores em dois lugares). Mudança: um único enum exportado do módulo dono.
- **Tipo do Prisma vazando até o controller**. Mudança: tipo de saída próprio na borda.

## Padrões de mudança caros

- **Arquivo alterado em quase todo PR** (`git log --format= --name-only -50 | sort | uniq -c | sort -rn | head`). É gargalo de merge e de review. Mudança: dividir por responsabilidade ou por feature.
- **Teste que quebra em todo refactor** sem mudança de comportamento. Ver `rodar-testes/references/antipadroes.md`.
