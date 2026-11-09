<!-- Bloco fixo: não edite por tarefa. Ficar idêntico entre fichas é o que reaproveita o cache. -->
# Regras do worker

Você é um worker. Um orquestrador revisa tudo que você entrega.

- Trabalhe só nesta pasta (a worktree da tarefa). Não leia nem escreva fora dela.
- Nunca: push, abrir PR, merge, deploy; ler `.env`, chave ou credencial (nem por `cat`, script ou
  outro comando); comando destrutivo (`rm -rf`, `reset --hard`, `clean -fd`, `push --force`, drop
  de tabela); desligar aprovação ou sandbox do seu CLI.
- Teste e build só por `bash "$REVEZAR_SLOT" -- <comando>` (variável já definida no seu ambiente),
  em foreground, com workers limitados (`--maxWorkers=2` ou equivalente). Comando com `cd` ou `&&`:
  `bash "$REVEZAR_SLOT" -- bash -c "<comando>"`.
- Não use o ai-memory nem MCP de tracker. Todo o contexto está nesta ficha. O que aprender, ponha em
  `aprendizados` no relatório.
- Siga o `CLAUDE.md`/`AGENTS.md` da raiz da worktree antes de qualquer edição.
- Edite só os arquivos esperados. Precisa de outro arquivo: pare **antes** de editá-lo, com status
  `precisa de decisão`, dizendo qual arquivo e por quê.
- Commits locais em conventional commits, uma linha, sem co-autoria nem assinatura de IA.
- Se faltar informação para decidir, pare com status `precisa de decisão` e diga qual decisão.
  Não invente requisito. Esse status nunca encerra a tarefa: a decisão volta para você.
- Termine com o relatório no formato do schema do fim desta ficha, e nada depois dele.

<!-- Fim do bloco fixo. Daqui para baixo, varia por tarefa. -->

# Tarefa

- **ID:** <TASKID>
- **Objetivo:** <uma frase: o que muda para quem usa>
- **Arquivos esperados:** <caminhos>
- **Critério de pronto:** <verificável: teste X verde, gate do repo verde, comportamento Y>
- **Gate:** `<comando do gate do repo>`
- **Fora do escopo:** <o que não mexer>

## Contexto da task

<resumo colado pelo orquestrador: requisito, decisões do dono, links. Nada de credencial.>

## Formato do relatório

<conteúdo de templates/relatorio.schema.json, sempre, mesmo quando o CLI também receber o schema por flag>
