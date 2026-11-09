# Guia de uso — revezar-agentes

Para quem vai operar o fluxo. O `SKILL.md` é para o agente; este arquivo é para você.

## A ideia em uma frase

Um orquestrador (o modelo maior) decide e confere; workers (modelos menores, de vários
fornecedores e contas) fazem o volume; o ai-memory guarda o contexto para que nenhuma troca de
agente, conta ou sessão faça você perder o fio.

## Preparação (uma vez)

1. **Atalho:** `ln -s ~/.claude/skills/revezar-agentes/scripts/revezar.sh ~/.local/bin/revezar`.
   `revezar status` mostra todas as contas e se estão logadas.
2. **Contas:** uma pasta por conta, criada e logada pelo próprio atalho:
   `revezar login claude <conta>`, `revezar login codex <conta>`, `revezar login grok <conta>`.
   No Orca, Claude e Codex também entram pela tela de contas (`orca account add`).
3. **ai-memory:** servidor no ar e hooks dos agentes instalados
   (`ai-memory install-hooks --agent <agente> --apply`). Confira com `ai-memory doctor`.
4. **Registro de contas:** crie `contas/estado.md` no projeto `_global` do ai-memory a partir de
   `templates/contas.md`, dizendo qual conta orquestra e quais trabalham. O menu do `revezar` mostra
   o "volta em" de cada conta a partir dele.
5. **Piloto:** `/revezar-agentes despachar` uma tarefa trivial para cada CLI e conta numa worktree
   descartável. Só entra no revezamento quem passar.

## No dia a dia

| Situação | O que você faz | O que acontece |
|---|---|---|
| Começo do dia | `/revezar-agentes status` | contas, resets, workers ativos e o próximo movimento |
| Tarefa grande com partes independentes | `/revezar-agentes despachar <tarefa>` | o orquestrador quebra em fichas, escolhe agente/conta/modelo pelo peso e inicia os workers |
| Limite perto | `/revezar-agentes bastão` | commit de checkpoint e bastão gravados antes de a conta parar |
| Limite batido | na pasta da tarefa: `revezar` | menu com as contas (e quando cada uma volta), escolha a linha de trabalho; o agente novo abre já lendo o bastão |
| Quer intervir num worker | abra o terminal dele no Orca (desktop ou celular) e digite | o worker recebe direto; o orquestrador segue com a própria sessão |
| Quer mudar a tarefa de um worker sem entrar nele | peça ao orquestrador | ele manda por `orchestration send` |
| Trabalho pronto | o orquestrador entrega branch, diff e gate | você decide publicar; ele só faz push ou PR quando você pedir |

## Gastar pouco, sem deixar acabar

- A conta do orquestrador só orquestra: ficha curta, leitura de relatório, decisão.
- Tarefa leve vai para modelo pequeno; pesada fica com Claude maior, nunca o contrário.
- Troque de agente entre tarefas, não no meio: cada troca paga o contexto de novo (cache frio).
- O bastão tem no máximo 40 linhas: o agente novo não relê a conversa anterior.
- Registre quando cada conta volta, com data e hora; limite semanal dura dias.
- Teste e build passam por `slot.sh`: no máximo 2 ao mesmo tempo na máquina, venham de onde vierem.

## Próximo nível: autonomia (ainda não ligado)

Depois que o piloto e algumas semanas de uso real mostrarem que os gates seguram:

1. **Automação de status:** `orca automations create` rodando `/revezar-agentes status` em horário
   fixo e avisando quando uma conta voltar.
2. **Fila de tarefas leves:** tarefas marcadas como leves são despachadas sozinhas para a conta
   ociosa, com o mesmo gate e sem publicar nada.
3. **Teto por dia:** limite de workers e de gasto no degrau pago por token, registrado em
   `contas/estado.md`.

Publicar (push, PR, merge, deploy) continua manual em qualquer nível.

## Quando não usar

- Uma pergunta ou edição pequena: faça direto, sem worker.
- Subagentes dentro da própria sessão: `/desmond`.
- Só supervisionar workers do Orca já iniciados: skill `orchestration`.
