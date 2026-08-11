# Criando e documentando uma skill

Guia normativo do repositório. Vale tanto pra quem escreve à mão quanto pra quem pede a um agente
("crie uma skill que…") — nesse caso, **aponte este arquivo pro agente** e exija que ele siga a
estrutura daqui.

## O que é uma skill

Uma pasta com um `SKILL.md`. O Claude Code lê o **frontmatter** de todas as skills instaladas no
início da sessão, e carrega o **corpo** só quando decide invocar aquela skill. Isso define a regra
que governa todo o resto:

> O frontmatter é o que sempre custa tokens. O corpo custa quando a skill roda. O detalhe em arquivo
> separado só custa quando o corpo mandar ler.

Escrever uma boa skill é, essencialmente, distribuir a informação entre essas três camadas.

## Quando criar

Crie quando o padrão **se repete em mais de um projeto**. Não crie pra:

| Situação | Onde vive |
|---|---|
| Regra de um repositório só | `CLAUDE.md` daquele repo |
| Comando de build/dev de um repo | `.claude/skills/` do próprio repo |
| Preferência pessoal de estilo | `~/.claude/CLAUDE.md` |
| Coisa que já existe como skill aqui | Estenda a existente, não duplique |

## Onde colocar

Skills são agrupadas **por tema**, e o tema é a área em que a skill atua:

```
skills/
├── engenharia/     ← como o agente trabalha: orquestração, revisão, qualidade, gate de contribuição
├── gestao/         ← fluxo de trabalho: tasks, decisões, tempo, rastreabilidade
└── integracoes/    ← conhecimento de plataformas externas: APIs, SDKs, protocolos
```

Tema novo é permitido — crie a pasta e justifique no PR. O `install.sh` recursa em
`skills/**/SKILL.md` em qualquer profundidade, e o nome instalado é o **basename da pasta da skill**
(`skills/gestao/plane/fechar-task/` instala como `fechar-task`). Nomes precisam ser únicos no repo.

## Anatomia da SKILL.md

```markdown
---
name: nome-da-skill
description: O que faz + QUANDO usar (com gatilhos literais) + quando NÃO usar.
---

# nome-da-skill

Uma ou duas frases: o que a skill resolve e qual é a fronteira dela.

**Alvo/argumento:** `$ARGUMENTS` — o que se espera receber, com exemplo.

## Token discipline
O que ler, o que não ler, o que é lazy-load.

## Safe-mode
O que a skill nunca faz sozinha.

## Passos
Numerados, na ordem, com o comando concreto de cada um.

## Output
O formato exato do resumo final.
```

### O campo `description` é o mais importante do arquivo

É a **única** coisa que o Claude vê antes de decidir invocar a skill. Uma `description` vaga produz
uma skill que nunca dispara — ou que dispara na hora errada. Ela precisa de três elementos:

1. **O que a skill faz**, em uma oração.
2. **Gatilhos literais** — as frases que o usuário realmente digita, em português *e* inglês,
   incluindo a forma `/nome-da-skill`.
3. **Fronteira negativa** — "NÃO use para X (isso é a skill Y)". Sem isso, skills vizinhas colidem.

```yaml
# ruim — não diz quando, não tem gatilho, não tem fronteira
description: Ajuda com tasks do Plane.

# bom
description: Fecha uma task no Plane — grava tempo (worklog), tokens, custo de IA e um comentário
  de resumo, encerrando o ciclo. Use quando o usuário disser "fechar task", "encerrar a task X",
  "/fechar-task PROJ-25", "close task". NÃO use para só comentar/reportar sem encerrar (isso é
  /reportar-task) nem para iniciar (isso é /iniciar-task).
```

Escreva a `description` em **terceira pessoa, descrevendo a skill** — não em imperativo pro modelo.

### Progressive disclosure

`SKILL.md` ≤ 150 linhas. O que passar disso vira arquivo separado, lido sob demanda:

```
skills/<tema>/<nome>/
├── SKILL.md            ← roteamento + passos + budget  (sempre lido quando a skill roda)
├── conventions.md      ← convenções e detalhes         (lido quando o SKILL.md mandar)
├── references/         ← documentação de referência    (um arquivo por assunto)
├── scripts/            ← executáveis determinísticos   (grep/curl > pedir pro modelo raciocinar)
└── templates/          ← modelos de arquivo gerado
```

No corpo, aponte explicitamente: *"Leia `references/webhooks.md` **apenas** se a tarefa envolver
verificação de assinatura."* Referência sem condição de leitura vira leitura incondicional.

**Prefira script a prosa** quando a tarefa for determinística. Um `scan.sh` com grep custa alguns
tokens e não erra; a mesma verificação descrita em prosa custa uma leitura inteira e depende do
modelo não se distrair.

## Princípios obrigatórios

1. **Token discipline explícita** — toda skill declara o que ler, o que evitar e o que é lazy-load.
2. **Safe-mode explícito** — toda skill declara o que nunca faz sem confirmação. Skill não faz git,
   não deleta arquivo, não chama API externa sem comando do usuário.
3. **Sem segredo, sem dado de cliente** — placeholders sempre (`provider-1`, `PROJ-25`,
   `<workspace>`). Credencial se lê de config local, nunca do corpo da skill.
4. **Roteamento por intent** — se a skill tem várias operações, decida por `$ARGUMENTS` logo no topo.
5. **Output com valor percebido** — a operação principal termina com um resumo curto: o que mudou e
   o que vale fazer em seguida.
6. **Fronteira declarada** — diga de qual skill vizinha você se diferencia, nos dois sentidos.

## Como documentar bem (a parte que os agentes erram)

- **Escreva o comando, não a intenção.** "Busque o Project ID" é instrução vaga; o bloco `curl` com
  o `python3 -c` que extrai o campo é executável.
- **Diga o que fazer quando der errado.** Todo passo que pode retornar vazio precisa da linha "se
  vier vazio, pare e mostre X — não chute".
- **Documente a pegadinha junto do passo.** O aviso de que o Plane fica atrás do Cloudflare vale mais
  ao lado do `curl` do que numa seção "Notas" no fim.
- **Use tabela pra decisão, lista pra sequência.** Se o leitor precisa escolher, tabela; se precisa
  executar em ordem, lista numerada.
- **Mostre o output esperado.** Um bloco com o formato exato do resumo final elimina variação entre
  execuções.
- **Não repita o que o Claude já sabe.** Documentar sintaxe de bash ou o que é um commit é gasto de
  token sem retorno. Documente o que é específico: o endpoint, o campo obrigatório, a ordem.
- **Uma skill, uma responsabilidade.** Se a descrição precisa de "e também", provavelmente são duas.

## Processo

1. Leia este guia e escreva `skills/<tema>/<nome>/SKILL.md`.
2. Instale e teste de verdade: `./install.sh`, abra um projeto, invoque a skill algumas vezes.
3. Itere com base no uso real — principalmente na `description`, que só se calibra vendo a skill
   disparar (ou não) nas situações certas.
4. **Rode o gate antes do PR:** `/validar-skill` (ou `./skills/engenharia/validar-skill/scripts/scan.sh`).
5. Abra o PR. Veja [CONTRIBUTING.md](../CONTRIBUTING.md) pro fluxo de fork e review.

## Antipadrões

- Skill que delega tudo a subagentes — custa muito mais do que resolve.
- Skill que carrega o repositório inteiro "pra entender o contexto".
- Skill que toma ação destrutiva sem confirmação.
- `SKILL.md` > 200 linhas sem lazy-load.
- Skill que duplica outra existente em vez de estendê-la.
- `description` genérica — a skill fica instalada e nunca é invocada.
- Credencial, ID real de cliente ou path absoluto de máquina no corpo.

## Versionamento

Mudança de comportamento vira commit explícito, em conventional commits, uma linha:

```
feat(skill/nome): ...
fix(skill/nome): ...
docs(skill/nome): ...
```
