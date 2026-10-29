---
name: despachar-dev
description: Despacha trabalho de desenvolvimento para um subagente com o modelo certo para o tamanho do problema. O orquestrador classifica a tarefa em complexidade (C1 mecânica, C2 padrão conhecido, C3 desenho novo) e risco (R1 rotina, R2 crítico). A complexidade escolhe o modelo que implementa e o risco escolhe quem verifica. Antes de disparar, o orquestrador mostra uma ficha de despacho com classe, modelo, motivo, critério de pronto e limites. A classe vai como tag na descrição do agente, e o `scripts/custo.py` mede depois quanto cada classe custou. Use sempre que for delegar implementação, correção, refactor, resposta a review ou escrita de testes a um subagente, e quando o usuário disser "despacha isso", "manda um agente fazer", "qual modelo usar pra essa task", "/despachar-dev <tarefa>", "quanto custaram os agentes", "/despachar-dev custo". NÃO use para busca ou leitura ampla (isso é `Explore` direto), para review de PR com veredito (isso é /julgar-pr), para decisão de arquitetura (fica com o orquestrador, sem delegar) nem para o modo completo de orquestração com economia de tokens (isso é /desmond, que usa esta tabela).
---

# despachar-dev

Quem orquestra é responsável pelo desenvolvimento que delega. Esta skill dá a régua para
escolher o modelo de cada subagente e torna essa escolha visível e mensurável. Ela não
substitui o julgamento do orquestrador: ele pode sair da tabela, desde que diga por quê
na ficha.

**Argumento:** `$ARGUMENTS`. Pode ser uma descrição da tarefa, que leva ao despacho
(passos 1 a 5), ou `custo [dias]`, que leva ao relatório (passo 6).

## Token discipline

- Classifique com o que já está no contexto. Só abra um `Explore` (`haiku`) se não
  souber o tamanho ou o raio da mudança, e não leia o repo inteiro.
- O prompt do subagente vem de `templates/prompt-dev.md`. Leia o template **só** na hora
  de escrever o prompt.
- Agente já despachado tem contexto acumulado: o follow-up vai por `SendMessage`, não por
  um agente novo, a não ser que seja escalada de modelo (passo 5).

## Safe-mode

- O subagente não faz push, merge, deploy, `db push` nem ação destrutiva. Se isso for
  necessário, ele devolve ao orquestrador, que pede confirmação ao usuário.
- Testes rodam em foreground, com workers limitados e uma suíte por vez. Isso vem
  embutido no template.

## Passos

1. **Classificar.** Dê uma nota para cada eixo, com evidência curta.

   | Complexidade | Sinal |
   |---|---|
   | **C1 mecânica** | A mudança está especificada por inteiro (arquivo, símbolo, texto). Rename, codemod, ajuste de copy, bump. |
   | **C2 padrão conhecido** | Feature ou correção que segue um padrão que já existe no repo, com critério de pronto claro. É a maior parte do trabalho. |
   | **C3 desenho novo** | Módulo ou integração nova, API externa pouco conhecida, causa raiz desconhecida, requisito ambíguo ou mudança espalhada por várias camadas. |

   | Risco | Sinal |
   |---|---|
   | **R1 rotina** | Reversível, local, coberto por teste e sem efeito fora do repo. |
   | **R2 crítico** | Dinheiro, auth ou segurança, multi-tenant, schema ou migração, dado de cliente, integração de pagamento, hotfix de produção. |

2. **Escolher modelos.** A complexidade decide quem implementa e o risco decide quem
   verifica.

   | | Implementa (`general-purpose`) | Verifica |
   |---|---|---|
   | C1 | `haiku` se for pequena e totalmente especificada; senão `sonnet` | R1: o orquestrador confere o diff · R2: review leve `sonnet` |
   | C2 | `sonnet` | R1: testes + review leve `sonnet` · R2: `/code-review` fork |
   | C3 | `opus` | R1: review `sonnet` · R2: `/code-review` fork + verificação adversarial `fable` |

   - Decisão de arquitetura, trade-off ou definição de critério não se delega: fica
     inline com o orquestrador, **antes** do despacho. Uma C3 que já tem o desenho
     decidido costuma virar C2.
   - Todo despacho passa `model` explícito, mesmo quando é `sonnet`. Despacho sem
     `model` aparece no relatório como "fora da skill".
   - Trabalho paralelo que altera arquivos usa `isolation: "worktree"`.

3. **Mostrar a ficha** ao usuário, sem esperar aprovação (o orquestrador tem autonomia),
   e despachar em seguida:

   ```
   🚚 [C2·R2] <ação + objeto + resultado esperado>
   - Complexidade: C2 padrão conhecido: <evidência, ex.: mesmo fluxo de <módulo-x>>
   - Risco: R2 crítico: <motivo, ex.: altera cálculo de taxa>
   - Implementa: general-purpose · sonnet
   - Verifica: /code-review fork
   - Pronto quando: <critério observável: teste X passa, endpoint Y responde Z>
   - Fora da tabela: <só se aplicável: modelo escolhido e por quê>
   ```

4. **Despachar** com `description: "[C2·R2] <título curto>"`. A tag no começo é o que o
   `custo.py` lê. Escreva o prompt a partir de `templates/prompt-dev.md`.

5. **Receber e escalar.** Compare o retorno com o critério de pronto, rodando você
   mesmo o teste ou o comando quando for barato.
   - Retorno incompleto: siga com o mesmo agente via `SendMessage`.
   - Bloqueio por capacidade (a mesma falha duas vezes, ou "não sei como"): **escale um
     degrau** (`haiku` → `sonnet` → `opus`) num agente novo, com o que já foi tentado, e
     tag `[C2·R2·esc]`. Só uma escalada: se o agente escalado também travar, o problema
     é de desenho e volta para o orquestrador.
   - Depois rode a verificação da tabela e só então declare pronto.

6. **Custo (`custo [dias]`).** Rode:

   ```bash
   python3 ~/.claude/skills/despachar-dev/scripts/custo.py --dias 7
   ```

   O script lê os metadados dos subagentes nas transcrições locais do Claude Code e soma
   os tokens por classe e por modelo. Mostre a tabela e aponte no máximo dois ajustes,
   por exemplo uma classe que escala com frequência (sobe o padrão) ou despachos fora da
   skill. Se não houver nenhum subagente no período, diga isso e pare.

## Output

Ao terminar um despacho, uma linha por agente: `[classe] título: pronto | escalado |
devolvido, verificação <ok|achados>`. No relatório de custo, a tabela do script e até
dois ajustes.
