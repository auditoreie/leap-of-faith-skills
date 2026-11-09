---
name: revezar-agentes
description: Mantém o trabalho andando e paralelo quando o limite de uso de um agente acaba — escolhe agente, conta e modelo pelo peso da tarefa (Claude em várias contas, Codex, Grok, cursor-agent, e um degrau pago por token), passa o bastão pelo ai-memory em vez do histórico, despacha workers pelo Orca com ficha de prefixo fixo e relatório em schema, mantém o registro de contas e horários de reset para não deixar a cota acabar, e aplica os gates (worktree própria, sem push/deploy/.env, memória restrita ao projeto). Use quando o usuário disser "acabou o limite", "bati no limite", "troca de agente", "continua no codex", "passa pro grok", "reveza", "paraleliza isso", "distribui entre os agentes", "quanto de cota sobrou", "/revezar-agentes [status|bastão|<agente|conta>|despachar <tarefa>]", "hit the limit", "switch agent". NÃO use para subagentes da própria sessão (isso é /desmond) nem para a mecânica de supervisão de workers do Orca, que esta skill chama (isso é orchestration).
---

# revezar-agentes

Paralelismo e controle mesmo quando os tokens acabam. Três camadas, cada uma com um dono:

| Camada | Ferramenta | Responsável por |
|---|---|---|
| Execução | Orca (`orca account`, `orchestration worker-start`, terminais) | contas, workers, status ao vivo, intervenção pelo app e pelo celular |
| Contexto | ai-memory (linha de trabalho, bastão, registro de contas) | o que sobrevive à troca de agente, conta, sessão ou ferramenta |
| Regras | esta skill | peso → agente, ficha, relatório, gates, orçamento de cota |

Sem Orca (terminal puro, outra máquina): a execução cai para `ai-memory run` e os comandos sem
interface de `references/agentes.md`. O resto não muda. Guia para humanos: `GUIA.md`.

**Argumento:** `$ARGUMENTS`

| Valor | Faz |
|---|---|
| vazio ou `status` | contas e resets, workers ativos, linhas de trabalho; recomenda o próximo movimento |
| `bastão` | grava o bastão da tarefa atual (rode quando o limite estiver perto) |
| `<agente>` ou `<conta>` | grava o bastão e devolve o comando para continuar nele |
| `despachar <tarefa>` | prepara a ficha, escolhe agente/conta/modelo e inicia o worker |

## Token discipline

- **Orquestrador só sintetiza.** Ele escreve fichas, lê relatórios e decide; não lê arquivo grande
  nem roda teste. Volume vai para worker.
- **Trocar de agente ou conta esfria o cache** (o cache é por modelo e conta). Troque na fronteira
  de uma tarefa e leve só o bastão (≤ 40 linhas), nunca o histórico.
- **Ficha com prefixo fixo** (`templates/ficha.md`): o bloco de regras é idêntico em toda ficha, e
  o que varia fica no fim; o cache do worker se reaproveita entre tarefas.
- **Contexto externo entra pela ficha.** Task do ClickUp ou spec: o orquestrador lê em modo resumo
  e cola o essencial. Worker não chama MCP de tracker.
- Leia `references/agentes.md` só ao montar o comando de um CLI fora do Orca, e `GUIA.md` só se o
  usuário pedir para aprender o fluxo.

## Safe-mode (gates)

| Quem | Pode | Nunca |
|---|---|---|
| Worker | ler e escrever na própria worktree; rodar o gate do repo em foreground; ler memória do próprio projeto | push, PR, merge, deploy; ler `.env` ou credencial de produção; comando destrutivo; desligar aprovação ou sandbox (`--yolo`, `--force`, `--always-approve`, `--dangerously-*`); `ai-memory` com `--global`, outro projeto ou `write-page` |
| Orquestrador | gravar bastão, registro de contas e memória durável; revisar o diff; rodar o gate de novo; publicar pelas regras do repo | aceitar relatório sem conferir o diff; credencial na ficha; dirigir worker pelo terminal (use `orchestration send`) |
| Você | entrar no terminal de qualquer worker pelo Orca e intervir | — |

- Máquina: até 4 workers ao mesmo tempo, no máximo 2 em teste ou build, test runner com workers
  limitados, sempre em foreground.
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
bash ~/.claude/skills/revezar-agentes/scripts/contas.sh          # login por CLI e conta
orca account list && orca worktree ps                             # contas do Orca e workers
ai-memory read-page --project _global --path contas/estado.md    # resets e reservas
```

Saldo restante não é legível de forma confiável por CLI: use o registro de contas, o aviso que o
agente dá ao bater o limite (`… limit · resets HH:MM`) e o que o usuário informar. Conta
`deslogada` ou "sign in again": pare e peça o login a quem tem o navegador.

### 2. Registro de contas (mantém a cota viva)

A cada limite batido ou reset observado, atualize `contas/estado.md` (`templates/contas.md`) com
`ai-memory write-page --project _global --path contas/estado.md --tier working --body -`. Regras:
a conta do orquestrador não faz trabalho de worker; abaixo de ~20% do bloco, grave o bastão antes
de continuar.

### 3. Bastão (antes de qualquer troca)

Preencha `templates/bastao.md` e grave no projeto da tarefa:
`ai-memory write-page --path "bastoes/<workstream>.md" --kind fact --tier working --body -`.
`<workstream>` = `<TASKID>-<slug>`. Com o MCP do ai-memory carregado, registre também
`memory_handoff_begin` (handoff manual, entregue antes dos automáticos).

### 4. Revezar (continuar a mesma tarefa em outro agente)

- No Orca: `orca account select --agent <claude|codex> --account <email|rótulo>` e
  `orca agent launch --agent <x> --model <id> --prompt "Leia bastoes/<workstream>.md no ai-memory e siga do próximo passo"`.
- Fora do Orca: `ai-memory run --workstream "<workstream>" [--env CLAUDE_CONFIG_DIR=…] <harness>`
  (`--new` na primeira vez; `--env`/`--profile` antes do harness).
- Grok e cursor-agent não têm conta gerenciada no Orca: conta por variável de ambiente
  (`references/agentes.md`).

### 5. Despachar em paralelo

1. Uma ficha por tarefa independente (`templates/ficha.md`), com arquivos esperados e critério de
   pronto verificável. Tarefas que tocam os mesmos arquivos não vão em paralelo.
2. Escolha conta (`orca account select`), agente e modelo pela tabela de peso.
3. `orca orchestration worker-start --spec-file <ficha> --agent <x> --model <id> --effort <nível>
   --worktree new-top-level --repo id:<repoId> --name <slug>`; inicie todos e encerre o turno.
   Daqui em diante siga a skill `orchestration` (o Orca acorda o orquestrador; sem polling).
4. No retorno: relatório fora do schema (`templates/relatorio.schema.json`), status `bloqueado` ou
   diff fora dos arquivos da ficha não é aceito. Confira o diff, rode o gate, só então publique.

### 6. Piloto (uma vez por CLI, conta e degrau pago)

Ficha trivial numa worktree descartável: escreveu só na worktree, a sandbox recusou escrita fora,
o relatório saiu no schema e `ai-memory recent` mostra a sessão no projeto certo. Falhou: fora do
revezamento até corrigir.

## Output

```
Revezamento: <origem> → <destino> (<peso>) · bastão bastoes/<workstream>.md (<N> linhas)
Comando: <linha exata para continuar>
Workers: <n ativos> · <tarefa → agente/conta/modelo, status>
Contas em espera: <conta> volta às <HH:MM>
```
