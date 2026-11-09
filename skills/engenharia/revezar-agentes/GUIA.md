# Guia de uso — revezar-agentes

Para quem vai operar o fluxo. O `SKILL.md` é para o agente; este arquivo é para você.

## A ideia em uma frase

Um orquestrador (o modelo maior) decide e confere; workers (modelos menores, de vários
fornecedores e contas) fazem o volume; o ai-memory guarda o contexto para que nenhuma troca de
agente, conta ou sessão faça você perder o fio.

## Preparação (uma vez)

1. **Contas no Orca:** `orca account add --agent claude` para cada conta Claude e
   `orca account add --agent codex` para cada conta Codex (janela anônima para a segunda conta).
   Confira com `orca account list`.
2. **Grok e cursor-agent:** login normal de cada CLI. Para uma segunda conta, uma pasta de config
   por conta (ver `references/agentes.md`).
3. **ai-memory:** servidor no ar (`ai-memory status`) e hooks dos agentes instalados
   (`ai-memory install-hooks --agent <agente> --apply`). Confira com `ai-memory doctor`.
4. **Registro de contas:** crie `contas/estado.md` no projeto `_global` do ai-memory a partir de
   `templates/contas.md`, dizendo qual conta orquestra e quais trabalham.
5. **Piloto:** `/revezar-agentes despachar` uma tarefa trivial para cada CLI e conta numa worktree
   descartável. Só entra no revezamento quem passar.

## No dia a dia

| Situação | O que você diz | O que acontece |
|---|---|---|
| Começo do dia | `/revezar-agentes status` | contas, resets, workers ativos e o próximo movimento |
| Tarefa grande com partes independentes | `/revezar-agentes despachar <tarefa>` | o orquestrador quebra em fichas, escolhe agente/conta/modelo pelo peso e inicia os workers no Orca |
| Limite perto | `/revezar-agentes bastão` | grava o bastão no ai-memory antes de a conta parar |
| Limite batido | `/revezar-agentes <agente ou conta>` | grava o bastão e devolve o comando para continuar no destino |
| Quer intervir num worker | abra o terminal dele no Orca (desktop ou celular) e digite | o worker recebe direto; o orquestrador segue com a própria sessão |
| Quer mudar a tarefa de um worker sem entrar nele | peça ao orquestrador | ele manda por `orchestration send` |

## Gastar pouco, sem deixar acabar

- A conta do orquestrador só orquestra: ficha curta, leitura de relatório, decisão.
- Tarefa leve vai para modelo pequeno; pesada fica com Claude maior, nunca o contrário.
- Troque de agente entre tarefas, não no meio: cada troca paga o contexto de novo (cache frio).
- O bastão tem no máximo 40 linhas: o agente novo não relê a conversa anterior.
- Registre o horário de reset sempre que uma conta parar; é o que permite planejar o dia.

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
