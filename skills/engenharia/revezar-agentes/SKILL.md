---
name: revezar-agentes
description: Mantém o trabalho andando e paralelo quando o limite de uso de um agente acaba — escolhe agente, conta e modelo pelo peso da tarefa (Claude em várias contas, Codex, Grok, cursor-agent, e um degrau pago por token), passa o bastão pelo ai-memory em vez do histórico, troca de conta por menu (`revezar`) sem variável de ambiente à mão, despacha workers pelo Orca ou em worktrees próprias com ficha de prefixo fixo e relatório em schema, mantém o registro de contas e horários de reset para não deixar a cota acabar, e aplica os gates (worktree sem segredo, sem push/deploy, no máximo 2 testes por vez na máquina). Use quando o usuário disser "acabou o limite", "bati no limite", "troca de agente", "troca de conta", "continua no codex", "passa pro grok", "reveza", "paraleliza isso", "distribui entre os agentes", "quanto de cota sobrou", "/revezar-agentes [status|bastão|<agente|conta>|despachar <tarefa>]", "hit the limit", "switch agent". NÃO use para subagentes da própria sessão (isso é /desmond) nem para a mecânica de supervisão de workers do Orca, que esta skill chama (isso é orchestration).
---

# revezar-agentes

Paralelismo e controle mesmo quando os tokens acabam. Três camadas, cada uma com um dono:

| Camada | Ferramenta | Responsável por |
|---|---|---|
| Execução | Orca (contas, workers, terminais) ou `revezar` + worktrees | abrir agentes na conta certa, status ao vivo, intervenção pelo app e pelo celular |
| Contexto | ai-memory (linha de trabalho, bastão, registro de contas) | o que sobrevive à troca de agente, conta, sessão ou ferramenta |
| Regras | esta skill | peso → agente, ficha, relatório, gates, orçamento de cota |

`<skill>` = `~/.claude/skills/revezar-agentes`. Atalho `revezar` = `<skill>/scripts/revezar.sh`.

**Argumento:** `$ARGUMENTS`

| Valor | Faz |
|---|---|
| vazio ou `status` | contas e resets, workers ativos, linhas de trabalho; recomenda o próximo movimento |
| `bastão` | grava o bastão da tarefa atual (rode quando o limite estiver perto) |
| `<agente>` ou `<conta>` | grava o bastão e devolve o comando `revezar` para continuar no destino |
| `despachar <tarefa>` | prepara a ficha, escolhe agente/conta/modelo e inicia o worker |

## Token discipline

- **Orquestrador sintetiza.** Escreve fichas, lê relatórios, decide. Não lê arquivo grande nem roda
  teste de desenvolvimento; a única execução dele é o gate final na branch integrada (passo 5.5).
- **Trocar de agente ou conta esfria o cache** (o cache é por modelo e conta). Troque na fronteira
  de uma tarefa e leve só o bastão (≤ 40 linhas), nunca o histórico.
- **Ficha com prefixo fixo** (`templates/ficha.md`): o bloco de regras é idêntico em toda ficha e
  o que varia fica no fim; o cache do worker se reaproveita entre tarefas.
- **Contexto externo entra pela ficha.** Task do ClickUp ou spec: o orquestrador lê em modo resumo
  e cola o essencial. Worker não chama MCP de tracker nem lê o ai-memory.
- `references/agentes.md` só ao montar comando de CLI; `GUIA.md` só se o usuário pedir.

## Safe-mode (gates)

| Quem | Pode | Nunca |
|---|---|---|
| Worker | rodar isolado (`revezar --jail`); ler e escrever na própria worktree; teste e build só via `<skill>/scripts/slot.sh` | push, PR, merge, deploy; ler segredo; comando destrutivo; desligar aprovação ou sandbox (`--yolo`, `--force`, `--always-approve`, `--dangerously-*`); usar o ai-memory |
| Orquestrador | gravar bastão, registro de contas e memória durável; revisar diff; integrar branches; rodar o gate final via `slot.sh` | publicar sem pedido do usuário; aceitar relatório sem conferir o diff; credencial na ficha; dirigir worker pelo terminal (use `orchestration send`) |
| Você | entrar no terminal de qualquer worker pelo Orca e intervir; mandar publicar | — |

- **Segredo:** worktree de worker nasce sem `.env` (`git worktree add` não copia ignorado). Isso não
  basta: a sandbox dos CLIs lê fora da pasta. Worker de outro fornecedor só roda isolado
  (`revezar --jail`: ai-jail com home privado); sem ai-jail instalado, só tarefa sem segredo por perto.
- **Memória não é isolada:** o ai-memory local não tem login nem escopo por projeto; "worker não usa
  o ai-memory" é regra da ficha, não barreira. Até `ai-memory auth enable` (decisão do dono), dado
  sensível de cliente não vai para worker de outro fornecedor.
- **Máquina:** até 4 workers ao mesmo tempo. Teste e build passam por `slot.sh`, que deixa no máximo 2
  rodando na máquina inteira (workers e orquestrador, com ou sem Orca), em foreground.
- **Publicar é do usuário:** a skill entrega branch, diff e gate; push e PR só a pedido; merge e deploy nunca.
- Tarefa pesada nunca desce de classe para caber numa conta com saldo: grava o bastão e espera o
  reset, ou o usuário decide pagar uso extra.

## Peso da tarefa → agente

| Peso | Exemplos | Classe | Conferência |
|---|---|---|---|
| Leve | busca, renomear, lint, doc, teste seguindo padrão pronto | menor (Claude Haiku/Sonnet, cursor-agent, Grok rápido) | gate do repo |
| Médio | feature com spec fechada, bug com causa conhecida, refactor localizado | Codex, Claude Sonnet, Grok | orquestrador lê o diff |
| Pesado | dinheiro, segurança, multi-tenant, schema/migração, arquitetura, causa desconhecida | Claude maior (Opus/Fable) | revisão cruzada por outro fornecedor |

Ao bater o limite: **mesma classe em outra conta → mesma classe em outro fornecedor → classe abaixo
(só leve/médio) → degrau pago por token (piloto obrigatório).** Modelos mudam: confira os IDs na
ajuda de cada CLI, não de memória.

## Passos

### 1. Status (sempre primeiro)

```bash
revezar status                                                   # login por CLI e conta
orca account list && orca worktree ps                            # se o Orca estiver no ar
ai-memory read-page --project _global --path contas/estado.md   # resets e reservas
```

Saldo restante não sai por CLI: use o registro de contas, o aviso de limite do agente e o que o
usuário informar. Conta `deslogada`: `revezar login <agente> <conta>`, por quem tem o navegador.

### 2. Registro de contas (mantém a cota viva)

A cada limite batido ou reset observado, atualize `contas/estado.md` (`templates/contas.md`) com
`ai-memory write-page --project _global --path contas/estado.md --tier working --body -`. O "volta
em" leva **data, hora e fuso** (limite semanal dura dias). Regras: a conta do orquestrador não faz
trabalho de worker; abaixo de ~20% do bloco, grave o bastão antes de continuar.

### 3. Bastão (antes de qualquer troca)

1. **Checkpoint:** tudo que não está commitado vira um commit local `wip: checkpoint <workstream>`
   (stage por caminho, nunca `-A`). `git status` limpo, ou a troca não acontece: o destino pode não
   ter acesso a esta pasta, e o bastão não carrega arquivo.
2. Preencha `templates/bastao.md` e grave, de dentro da worktree da tarefa (é ela que define workspace
   e projeto): `ai-memory write-page --path "bastoes/<workstream>.md" --kind fact --tier working --body -`.
   `<workstream>` = `<TASKID>-<slug>`.
3. Com o MCP do ai-memory carregado, registre também `memory_handoff_begin` (handoff manual).

### 4. Revezar (continuar a mesma tarefa em outro agente ou conta)

O usuário roda, na worktree da tarefa (terminal comum ou terminal do Orca):

```bash
revezar                                   # menu: conta (com "volta em") → linha de trabalho
revezar <agente> <conta> <workstream>     # direto
```

O `revezar` passa a conta ao agente, abre pelo `ai-memory run` na mesma linha de trabalho e, se
existir `bastoes/<workstream>.md` naquele projeto, já manda o agente ler o bastão e seguir do próximo
passo. Ninguém digita variável de ambiente. No Orca, Claude e Codex também trocam pela tela de contas
(`orca account select`); Grok e cursor-agent só pelo `revezar`.

### 5. Despachar em paralelo

1. **Fichas.** Uma por tarefa independente (`templates/ficha.md`), com arquivos esperados, critério de
   pronto verificável e o schema do relatório sempre colado no fim. Tarefas que tocam os mesmos
   arquivos não vão em paralelo.
2. **Worktrees.** Uma por worker, a partir da integração: `git worktree add ../wt-<slug> -b <branch>
   origin/<integração>`. Sem `.env`, sem cópia de segredo.
3. **Iniciar** cada worker num terminal aberto por `revezar --jail <agente> <conta> <workstream>` na
   worktree dele; com Orca, `worker-start --terminal <handle>` entrega a ficha (comandos em
   `references/agentes.md`, que também diz como acompanhar e recolher relatórios sem Orca, em
   `$HOME/.cache/revezar/<slug>.json`). Inicie todos e encerre o turno; com Orca, siga a skill
   `orchestration` (sem polling).
4. **Receber.** Relatório fora do schema, `bloqueado` ou diff fora dos arquivos da ficha: não aceito.
   `precisa de decisão`: leve ao usuário; aprovado arquivo extra, inclua-o em "Arquivos esperados"
   antes de devolver ao worker. Só `concluído` é aceito como pronto.
5. **Integrar e conferir.** Mais de um worker na mesma entrega: crie a branch de integração a partir
   de `origin/<integração>`, traga os commits aceitos de cada worker (`git merge --no-ff` ou
   `cherry-pick`), confira o diff e rode o gate nela, via `slot.sh`.
6. **Entregar.** Branch, diff resumido e resultado do gate ao usuário. Publicar só com pedido dele.

### 6. Piloto (uma vez por CLI, conta e degrau pago)

Ficha trivial numa worktree descartável, aberta com `revezar --jail`, que manda o worker tentar ler
uma isca **fora** da worktree (`$HOME/.revezar-isca`, valor falso). Passa se: a leitura da isca foi
negada, escreveu só na worktree, o relatório saiu no schema, `ai-memory recent` mostra a sessão no
projeto certo e a conta usada foi a escolhida. Falhou: fora do revezamento até corrigir. Apague a
worktree e a isca ao fim.

## Output

```
Revezamento: <origem> → <destino> (<peso>) · bastão bastoes/<workstream>.md (<N> linhas)
Comando: revezar <agente> <conta> <workstream>
Workers: <n ativos> · <tarefa → agente/conta/modelo, status>
Contas em espera: <conta> volta em <AAAA-MM-DD HH:MM> (<fuso>)
```
