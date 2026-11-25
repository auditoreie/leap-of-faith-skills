# Tributos para formação de preço de software (Brasil)

Leia no passo 7 da skill. Textos legais abertos e lidos em 05/11/2026. Antes de usar em proposta,
confira se houve alteração posterior (reforma tributária muda alíquotas ano a ano) e confirme com
a contabilidade o subitem da lista de serviços que a entidade emite.

| Regra | Valor | Fonte |
|---|---|---|
| Simples: atividade de software | "elaboração de programas de computadores" e "licenciamento ou cessão de direito de uso" estão no § 5º-D do art. 18 → Anexo III; com folha < 28% da receita (fator r) vão ao Anexo V (§ 5º-M, II) | https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm |
| Simples: alíquota efetiva | (RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12 (art. 18, § 1º-A) | idem |
| Anexo III (LC 155/2016) | 6,00% até 180 mil · 11,20% (−9.360) até 360 mil · 13,50% (−17.640) até 720 mil · 16,00% (−35.640) até 1,8 mi · 21,00% (−125.640) até 3,6 mi · 33,00% (−648.000) até 4,8 mi | idem |
| Anexo V (LC 155/2016) | 15,50% · 18,00% (−4.500) · 19,50% (−9.900) · 20,50% (−17.100) · 23,00% (−62.100) · 30,50% (−540.000), mesmas faixas | idem |
| Lucro Real: PIS e COFINS de software | Regime **cumulativo** mesmo no Lucro Real (art. 10, XXV: desenvolvimento, licenciamento, programação, páginas eletrônicas) | https://www.planalto.gov.br/ccivil_03/leis/2003/l10.833.htm |
| COFINS cumulativa | 3% (art. 8º) | https://www.planalto.gov.br/ccivil_03/leis/l9718.htm |
| PIS cumulativo | 0,65% (art. 8º, I) | https://www.planalto.gov.br/ccivil_03/leis/l9715.htm |
| IRPJ | 15% + adicional de 10% sobre o lucro que exceder R$ 20.000 × meses (art. 3º) | https://www.planalto.gov.br/ccivil_03/leis/l9249.htm |
| CSLL | 9% (art. 3º, III) | https://www.planalto.gov.br/ccivil_03/leis/l7689.htm |
| ISS (exemplo: Belo Horizonte, item 1, informática) | 2% (art. 14, I). Cada município tem a sua lei; confirme o subitem emitido | https://fazenda.pbh.gov.br/internet/legislacao/findkey.asp?key=L8725 |
| Reforma tributária 2026 | IBS 0,1% (art. 343) e CBS 0,9% (art. 346) de teste; compensados com PIS/COFINS e dispensados para quem cumpre obrigações acessórias (art. 348, § 1º); **não se aplicam a optantes do Simples** (art. 348, III, c). Em 2027 e 2028 a CBS vale pela alíquota de referência do art. 14 menos 0,1 ponto (art. 347); a alíquota de referência não está no texto da lei | https://www.planalto.gov.br/ccivil_03/leis/lcp/Lcp214.htm |

## Como comparar entidades

```
Lucro Real:  preço_bruto = preço_líquido ÷ (1 − ISS − PIS − COFINS)        [sobre a receita]
             lucro = preço_bruto − tributos_receita − custo
             IRPJ = 15% × lucro + 10% × max(0, lucro − 20.000 × meses); CSLL = 9% × lucro
Simples:     preço_bruto = preço_líquido ÷ (1 − alíquota_efetiva)           [tudo dentro]
             alíquota_efetiva pela RBT12 (receita dos 12 meses anteriores) e pelo anexo (fator r)
```

Leitura que costuma valer para desenvolvimento de software:

- PIS/COFINS de software é cumulativo: nem a entidade nem o cliente geram crédito nessa nota. O
  argumento "Lucro Real gera crédito para o cliente" não se aplica.
- Lucro Real paga tributo sobre a receita (ISS + 3,65%) e mais 24% a 34% sobre o lucro. Com margem
  alta, o IRPJ + CSLL pesa mais que a diferença de alíquota sobre a receita, e o Simples tende a
  reter mais, desde que a RBT12 mantenha a entidade em faixa baixa do Anexo III.
- Não modelado aqui: INSS patronal no Lucro Real, retenções na fonte pela contratante, efeito do
  próprio contrato na faixa do Simples. Confirmar com a contabilidade antes de fechar.
