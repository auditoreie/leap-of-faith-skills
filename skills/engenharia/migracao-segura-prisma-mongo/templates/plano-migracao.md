## Plano de migração — <campo/model> (<só-schema | dados+schema>)

**Motivação:** <uma frase: que comportamento ou decisão exige a mudança; ADR se houver>

**Documentos afetados:** <n> em <coleção>, contados em <ambiente> em <data> com `<filtro>`

### Expand (este PR)
- Schema: `<Model.campo>` nasce <opcional | com @default> · índice: <nenhum | @@index(...)>
- Código: escreve em <antigo e novo> atrás de `<TOGGLE>` (default OFF)
- Script: `<caminho>` (`<pm> run prisma:backfill-<nome>`), `DRY_RUN` default

### Backfill
| Ambiente | Backup | Dry-run (a migrar) | Execução | Restantes |
|---|---|---|---|---|
| local | n/a | <n> | ok | 0 |
| staging | <script/snapshot> | <n> | <data hora> | 0 |
| produção | <script/snapshot> | <n> | <pendente> | <pendente> |

### Ordem de deploy
1. Merge expand → deploy → `db push` (<onde roda>) → `<TOGGLE>=ON`
2. Backfill staging → produção → recontagem zero
3. PR leitura do campo novo (toggle) → observar <o que>
4. PR contract: <obrigatório | enum | @unique | remoção> → `db push`

### Rollback
- Código: revert do PR; dado continua compatível (campo novo é opcional)
- Índice único: `db push` do schema anterior
- Backfill: <reversível por script inverso | irreversível, por isso backup + dry-run>

### Fora de escopo
- <remoção do campo antigo, outras coleções, etc.>
