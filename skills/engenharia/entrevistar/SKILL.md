---
name: entrevistar
description: >-
  Entrevista o usuário em rodadas sobre um plano, decisão ou ideia até que nenhuma premissa fique
  implícita: mapeia o tema como árvore de decisões, pergunta a cada rodada só a fronteira (o que já
  pode ser decidido), numera as perguntas com a recomendação na frente para que "sim" aceite a
  recomendação, resolve sozinha com a codebase o que é fato e deixa com o usuário só o que é
  decisão, e para quando a fronteira esvazia e o usuário confirma o entendimento. É a primitiva de
  perguntas do repositório: /spec, criar-task, desmond e qualquer skill que precise fechar decisões
  chamam esta. Use quando o usuário disser "me entrevista", "stress-test esse plano", "fecha as
  decisões antes de codar", "/entrevistar <tema>", "grill me", "interview me", ou quando uma
  tarefa tiver mais de uma decisão em aberto. NÃO use para executar o plano (isso vem depois da
  confirmação), para escrever a spec em si (isso é /spec, que chama esta), nem para pergunta única
  com default óbvio (assuma, declare e siga).
---

# entrevistar

Loop de entrevista que testa um plano antes de alguém agir sobre ele. O tema vira uma árvore de
decisões; cada rodada pergunta tudo o que já pode ser decidido; fato é resolvido pelo agente,
decisão fica com o usuário; a skill só termina quando o usuário confirma que o entendimento é
compartilhado. Quem chama recebe a tabela de decisões e segue (spec, task, plano).

**Alvo:** `$ARGUMENTS` — o tema (`migrar o envio de e-mail para fila`); vazio usa o assunto da
conversa.

## Token discipline

- Fato que o ambiente responde não vira pergunta: "isso já existe?", "qual padrão o repo usa?",
  "o que a doc oficial diz?" vão para um `Explore` com `model: "sonnet"` ou uma leitura pontual,
  antes da rodada. Afirmação sobre plataforma externa vem com a URL da fonte.
- Pesquisa em paralelo não trava a rodada: só as perguntas que dependem dela esperam.
- Não carregue o repositório inteiro para "entender o contexto". Leia o que a pergunta exige.

## Safe-mode

- **Não age antes da confirmação.** Nenhum arquivo, commit, task ou código até o usuário dizer
  que o entendimento está fechado. Esta skill não grava nada; quem chama grava.
- **Recomendação não é decisão.** Toda pergunta traz a sua recomendação, mas a resposta é do
  usuário. "Não sei" é resposta válida e vira fato a pesquisar, protótipo ou decisão adiada com dono.
- **Não concorde automaticamente.** Se a resposta contradiz evidência da codebase ou uma decisão
  anterior da própria sessão, diga isso na rodada seguinte, com a evidência.
- **Fique fora do plan mode** durante a entrevista: ele empurra para produzir um plano antes de
  as perguntas terminarem.

## Protocolo

1. **Mapear a árvore.** Em uma linha, o destino (o que fica decidido ao final). Depois as
   decisões de primeiro nível e, para cada uma, o que só faz sentido perguntar depois dela
   respondida. Isso é a árvore; não mostre a árvore inteira, use-a para calcular a fronteira.
2. **Separar fato de decisão.** Para cada nó: se a codebase, a doc oficial ou um comando responde,
   é fato e você resolve antes de perguntar. Se depende de intenção de produto, trade-off de
   negócio, apetite a risco ou escopo, é decisão e vai para a rodada.
3. **Rodada.** Pergunte **todas** as decisões cujas premissas já estão resolvidas, numeradas
   (Q1, Q2, ...), cada uma com: título, uma a três linhas de contexto com a evidência encontrada,
   e `➡️ Recomendação:` em linha própria. Formule para que "sim" aceite a recomendação. Até 4
   perguntas: use `AskUserQuestion`, com a recomendação como primeira opção marcada
   "(Recommended)". Mais de 4: texto numerado, e peça resposta por número
   ("1 sim, 2 a segunda, 3 não porque ...").
4. **Depois da resposta.** Registre cada decisão na tabela (id, decisão, razão em uma linha).
   Recalcule a fronteira: perguntas cujas premissas mudaram são reformuladas, não repetidas. Avise
   quando uma resposta tornar outra pergunta já feita obsoleta: a fronteira é calculada por
   julgamento, não por grafo, e o usuário pode enxergar a dependência antes de você.
5. **Parada.** Fronteira vazia: apresente a tabela de decisões, a lista do que ficou **não
   decidido** (com dono e gatilho) e o que ficou **fora de escopo**, e pergunte se é isso. Só com
   a confirmação a skill termina e devolve ao chamador. Nunca termine por conta própria por
   "achar que já deu".

| Situação | Faça |
|---|---|
| Pergunta que conversa não resolve ("como deve parecer", "como deve se comportar na mão") | Pare de perguntar. Proponha um protótipo descartável e volte com a resposta curta |
| Mais de três rodadas ou dezenas de perguntas | O tema é grande demais. Proponha cortar em partes com destino próprio e entrevistar uma por vez |
| Usuário responde "de acordo" a tudo, rodada após rodada | Diga isso. Peça que conteste pelo menos a recomendação que ele menos entendeu |
| Uma resposta contradiz decisão anterior | Mostre as duas e pergunte qual vale |

## Output

```
🎯 entrevistar — <tema> · <N> rodadas · <n> perguntas

| # | Decisão | Razão |
|---|---|---|
| D1 | ... | ... |

Não decidido: <item, dono, gatilho> | nenhum
Fora de escopo: <item> | nenhum

É isso? (sim fecha a entrevista e devolve ao chamador)
```
