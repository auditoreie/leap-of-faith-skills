# Contrato do findings.json, do resumo e da voz dos comentários

Tudo aqui é verificado por `scripts/review_gate.py`. Escreva já dentro das regras: o gate é
conferência, não rascunho.

## Severidade e veredito

| Severidade | Emoji | É | Efeito |
|---|---|---|---|
| `blocker` | 🔴 | muda se o PR pode mergear: perda de dado, exploração real, dinheiro errado, auth quebrada, migração irreversível, PII em log, regra absoluta do repo violada | REQUEST_CHANGES |
| `should-fix` | 🟠 | defeito real que não é risco de merge | COMMENT |
| `nit` | 🟡 | menor; máximo 5 inline, o excedente vira contagem no resumo | nenhum |
| `pre-existing` | 🟣 | bug que o PR não introduziu; só no resumo, nunca inline, sem `line` | nenhum |

Qualquer 🔴 (novo ou em `carryover`): REQUEST_CHANGES. Zero 🔴 e zero 🟠: APPROVE. Senão: COMMENT.
O gate recalcula e reprova veredito diferente disso.

## Schema

```json
{
  "language": "pt-BR",
  "round": 1,
  "carryover": {"blocker": 0, "should-fix": 0},
  "verdict": "REQUEST_CHANGES",
  "summary": "## TL;DR\n...\n## Achados\n...\n## Promover a lint rule\n...\n## Pesquisa\n...\n## Checagens\n...\n## Arquivos pulados\n...",
  "findings": [
    {
      "id": "F1",
      "path": "src/cobranca/parcela.ts",
      "line": 142,
      "severity": "blocker",
      "body": "🔴 ...",
      "evidence": [
        {"type": "internal", "ref": "src/cobranca/parcela.ts:142"},
        {"type": "external", "ref": "https://..."},
        {"type": "repro", "ref": "bun x jest src/tests/cobranca/parcela.spec.ts -t 'lista vazia'"}
      ]
    }
  ]
}
```

Regras do gate, por campo:

- `id` estável entre rodadas: F1 é F1 para sempre.
- `body` começa com o emoji da severidade. Até 900 caracteres e 10 linhas; nit até 400.
- `blocker` e `should-fix`: pelo menos uma `evidence`. `internal` é `caminho:linha` que você
  releu; `external` é URL `https://` de fonte oficial aberta nesta review; `repro` é o comando
  rodado, com o resultado observado dentro do `body`.
- `path` e `line` inteiro ≥ 1, ancorado em linha presente no diff, para tudo que não é
  `pre-existing`. `pre-existing` não leva `line`.
- `round` ≥ 2 exige `carryover` (zeros valem), só achados `blocker`, e seção de Resolução no resumo.
- `summary` contém "TL;DR" com o token do veredito literal e uma seção cujo título contém
  "lint rule".

## Texto: o que o gate reprova

Vale para `body` e `summary`, ignorando código entre crases:

- travessão (— ou –) e ponto de exclamação;
- palavras: obviamente, simplesmente, ademais, parabéns, desculpe, desculpa, e as inglesas
  (obviously, simply, leverage, crucial, seamless, delve, furthermore, moreover, kudos, awesome,
  sorry);
- frases: "ótimo trabalho", "bom trabalho", "espero que ajude", "fique à vontade", "vale ressaltar",
  "vale notar", "note que", "além disso", "você esqueceu", "com toda certeza", e as inglesas
  ("good catch", "let me know", "note that", "feel free", "you forgot", "hope this helps");
- construção "não apenas X mas Y";
- primeira linha do `body` abrindo com "vou ", "deixa eu", "primeiramente", "olhando", "bom,",
  "let me", "I'll", "looking at", "first,", "so,", "sure", "ok,".

A lista completa está no próprio `review_gate.py`; a saída do gate nomeia o padrão exato.

## Voz dos comentários

1. Primeira linha: problema e local, com o emoji na frente. Ex.: `🔴 \`aplicarDesconto\` divide
   por \`itens.length\` sem guarda para lista vazia (src/cobranca/parcela.ts:142).`
2. Depois, a correção mais simples que funciona, nesta ordem de preferência: helper que já existe
   no repo, biblioteca padrão, recurso da plataforma, dependência já instalada, uma linha, código
   novo mínimo. Nunca sugerir dependência nova para o que três linhas resolvem.
3. Bug em função compartilhada: a correção vai nela, não no chamador que aparece no diff.
4. Correção em etapas: lista numerada de até 5 passos. Um passo cabe numa frase.
5. Simplificação deliberada: "pular X; adicionar quando Y".
6. Pergunta termina com a pergunta: a última linha é um pedido concreto e respondível.
7. Tom: descreva a lacuna no código, nunca a pessoa. Sem aula sobre conceito que o autor domina.
   Sem elogio; no máximo uma observação factual positiva no resumo. Trade-off real reconhecido em
   uma oração, depois o pedido.
8. A maioria dos comentários cabe em 4 linhas. Se a explicação estoura o limite, o comentário está
   fazendo o trabalho do fix: linke o local e corte.

## Resumo (`summary`)

```markdown
## TL;DR
Uma a três frases: o que o PR faz e o veredito com o motivo. Contém APPROVE, COMMENT ou
REQUEST_CHANGES literal.

## Achados
| ID | Severidade | Local | Resumo |
|---|---|---|---|

## Resolução (rodada 2+)
| ID | Situação | Nota |
|---|---|---|
Todo achado anterior: resolvido (commit), aberto ou recusado-aceito (razão do autor). Omitir na
rodada 1.

## Promover a lint rule
Achados determinísticos por natureza (padrão proibido, convenção de nome): a regra e uma linha de
como lintar. A review fica mais barata a cada ciclo. Escreva "nenhuma" se vazio.

## Pesquisa
Uma URL por linha, com a afirmação que ela sustenta ou refuta. Fonte que matou um candidato entra
também. Sem superfície externa: escreva isso.

## Checagens
Resultado do gate do repo, números crus: testes (passou/falhou/pulou), lint, tipos, contagem do
scanner de bypass.

## Arquivos pulados
Mecânicos e gerados, excluídos da review.

## Nits não postados
"N nits adicionais não postados individualmente" quando passou do teto. Omitir se não.
```

Nit retido: se um 🔴 ou 🟠 manda reestruturar um bloco, não empilhe nits dentro dele; anote
"nits retidos nas linhas que a correção estrutural reescreve" no resumo.
