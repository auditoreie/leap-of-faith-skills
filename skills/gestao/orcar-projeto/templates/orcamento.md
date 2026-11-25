# Orçamento: <projeto> (v<N>, <data>)

Rótulos: **[caderno]** vem do documento do cliente; **[medido]** vem de crawl, Lighthouse ou API;
**[estimativa]** é cálculo nosso, com a premissa ao lado.

## 1. Decisão rápida

| Versão | Horas P50 | Horas P80 | Preço líquido | Prêmio de risco | Prazo |
|---|---:|---:|---:|---:|---|
| Enxuta | | | | | |
| Completa | | | | | |

Uma frase: o que a enxuta deixa de fora e por quê.

## 2. Itens por bloco

Para cada bloco (A, B, C...): objetivo em uma linha, depois a tabela.

| Item | Papel | O | P | Pe | E (PERT) | Enxuta | Completa | Fundamento | Ref. |
|---|---|---:|---:|---:|---:|---:|---:|---|---|
| A1 <nome> | dev | | | | | | | [medido] <n> objetos; [estimativa] <x> h por objeto | C1 §x |

Papel: `dev` (desenvolvimento e QA) ou `arq` (arquitetura, liderança técnica, gestão).
O/P/Pe: otimista, provável, pessimista. E = (O + 4P + Pe)/6; σ = (Pe − O)/6.

## 3. O que mudou em relação à versão anterior

| Item | Antes | Agora | Motivo |
|---|---|---|---|

## 4. Opcionais

| # | Opcional | Horas | Preço | Condição para ativar | Lacuna do documento que cobre |
|---|---|---:|---:|---|---|

## 5. Lacunas do documento e solução proposta

Lista: lacuna, evidência ([medido] ou [caderno]), o que propomos, onde entra (base ou opcional).

## 6. Validação da proposta anterior / post mortem

| Afirmação | Evidência | Situação |
|---|---|---|
| | | confirmada / parcial / refutada |

## 7. Preço e prêmio de risco

- Custo interno por hora por papel: [decisão]
- Margem-alvo: [decisão]
- Contingência (P80 − P50): [estimativa]
- Exposição contratual: [caderno] cláusulas × [estimativa] probabilidade e custo
- Tarifa equivalente por papel (preço ÷ horas P50), só para cumprir o formato do edital

## 8. Tributo e entidade

| Entidade | Regime | Alíquotas usadas | Preço bruto | Sobra após tributo |
|---|---|---|---:|---:|

Fontes legais em `references/tributos-br.md`. Premissas (RBT12, fator r, ISS municipal) explícitas.

## 9. Custos recorrentes do cliente

| Serviço | Estimativa mensal | Fonte (página de preço oficial) |
|---|---:|---|

## 10. Dados que faltam

| Dado | Para quê | Dono | Impacto se não vier |
|---|---|---|---|
