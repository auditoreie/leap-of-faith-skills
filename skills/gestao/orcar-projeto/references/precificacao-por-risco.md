# Precificação por risco: modelos aceitos e o que a Auditore adota

Leia este arquivo no passo 6 da skill. Fontes abertas e lidas em 05/11/2026; o que não foi
conferido no texto original está marcado **[não conferido]**.

## O problema que estamos resolvendo

Cobrar por hora pune a eficiência: quem entrega em menos horas fatura menos, e a ferramenta
(IA, automação, reuso) que encurta o trabalho vira perda de receita. O Canadian Bar Review descreve
o mesmo desalinhamento na advocacia e conclui pelo honorário fixo baseado em valor como alternativa
viável ([Better Value: Problems with the Billable Hour](https://cbr.cba.org/index.php/cbr/article/download/4282/4275/4282)).
Na pesquisa de pricing B2B, Hinterhuber mostra que precificar por custo é o padrão da maioria das
empresas e que o preço por valor é o menos difundido, em parte por conformismo gerencial
([Journal of Business Strategy 29(4), 2008](https://dx.doi.org/10.1108/02756660810887079);
Journal of Business Research vol. 133, 2021 **[não conferido]**). A evidência de que preço por valor
dá mais lucro existe, mas é do próprio autor (Liozu & Hinterhuber, 2013 **[não conferido]**).

## Modelos aceitos (do mais formal ao mais prático)

| Modelo | Como funciona | Onde é aceito | Fonte |
|---|---|---|---|
| **Preço fixo com incentivo (FPI)** | Negocia-se custo-alvo, lucro-alvo, teto de preço e fórmula de ajuste. Custo final abaixo do alvo → lucro maior que o alvo; acima → lucro menor ou prejuízo; acima do teto → o contratado absorve. | Contratação federal dos EUA desde décadas; "preferido quando custo e desempenho são razoavelmente certos" | [FAR 16.403-1](https://www.acquisition.gov/far/subpart-16.4) |
| **Custo mais incentivo (CPIF)** | Custo-alvo, taxa-alvo, taxa mínima e máxima, fórmula de ajuste. Fora da faixa, paga custo mais taxa mínima ou máxima. | Mesmo regime; para "serviços ou programas de desenvolvimento e teste" quando preço fixo não cabe | [FAR 16.405-1](https://www.acquisition.gov/far/subpart-16.4) |
| **Pagamento por tamanho, não por esforço** | O contrato paga por unidade de produto (ponto de função, SFP, story point padronizado, linha de código funcional); hora de serviço técnico (HST) é só "métrica auxiliar para produtos complementares". Produtividade vira risco e ganho do fornecedor. | Governo federal brasileiro (SISP), Roteiro de Métricas v3.0 instituído pela Portaria SGD/MGI 3656/2026 | [Roteiro v3.0 (PDF)](https://www.gov.br/governodigital/pt-br/estrategias-e-governanca-digital/sisp/documentos/arquivos/roteiro-de-metricas-do-sisp-v3.0.pdf) · [página SISP](https://www.gov.br/governodigital/pt-br/estrategias-e-governanca-digital/sisp/documentos/roteiro-de-metricas-de-software-do-sisp) |
| **Vedação ao homem-hora** | Art. 5º, VIII: vedado "adotar a métrica homem-hora ou equivalente para aferição de esforço, salvo mediante justificativa e sempre vinculada à entrega de produtos de acordo com prazos e qualidade previamente definidos". IX: vedado contratar por postos alocados sem comprovação de resultados. | IN SGD/ME 94/2022 (SISP) | [cópia integral (PDF, Governo de Roraima)](https://selc.rr.gov.br/wp-content/uploads/2025/08/INSTRUCAO-NORMATIVA-SGD-ME-No-94-DE-23-DE-DEZEMBRO-DE-2022.pdf); original em gov.br exige login |
| **Contingência por nível de confiança** | Estima-se a distribuição do custo; contingência = P80 (ou o percentil escolhido) menos a estimativa base. AACE 40R-08 define princípios; 42R-08 e 44R-08 trazem métodos (paramétrico, valor esperado). | Engenharia de custos (AACE International) | [40R-08](https://www.pathlms.com/aace/courses/3172/video_presentations/370780) · [42R-08](https://www.pathlms.com/aace/courses/2928/documents/3827) · [41R-08 reescopada em 2021](https://source.aacei.org/?p=3454) |
| **Uplift por viés de otimismo (classe de referência)** | "Há uma tendência demonstrada e sistemática de os avaliadores de projeto serem otimistas demais"; ajuste empírico com dados de projetos passados similares. Tabela 1: outsourcing 0% a 41% (sobre despesa operacional); equipamento/desenvolvimento 10% a 200% sobre capex. | Tesouro do Reino Unido (Green Book); método de Flyvbjerg | [Green Book, Optimism Bias (PDF)](https://assets.publishing.service.gov.uk/media/5a74dae740f0b65f61322c72/Optimism_bias.pdf) · [Flyvbjerg, "From Nobel Prize to Project Management"](https://arxiv.org/pdf/1302.3642) |
| **Contrato ágil "money for nothing, change for free"** | Preço fixo; cliente troca escopo de graça se o tamanho total não muda; pode encerrar antes pagando parte do restante (20% é o valor citado). Só vale se o cliente participa do processo. | Prática de mercado (Scrum Inc.), não é norma nem pesquisa | [padrão "money for nothing"](https://sites.google.com/a/scrumplop.org/published-patterns/value-stream/product-backlog/money-for-nothing) · [Scrum Inc.](https://scruminc.com/?p=5929) |
| **Honorário por resultado** | Parte da remuneração atrelada a resultado medido. Imprensa reporta que cerca de um quarto das receitas globais da McKinsey já vem desse formato (declaração de nov/2025 ao Business Insider). | Consultoria estratégica; **[não conferido na fonte primária]** | [TheStreet](https://www.thestreet.com/markets/ai-is-forcing-mckinsey-bcg-bain-to-rethink-consulting-fees) · [Yahoo Finance](https://finance.yahoo.com/sectors/technology/articles/ai-forcing-mckinsey-bcg-bain-093300265.html) |

O que esses modelos têm em comum: **o esforço é insumo da estimativa, não a base de cobrança**.
Quem cobra por produto ou por alvo com fórmula de ajuste ganha quando é eficiente e paga quando erra
a estimativa. É isso que alinha o incentivo.

## O modelo da Auditore

```
Preço da base = Custo-alvo + Margem-alvo + Prêmio de risco

Custo-alvo      = Σ (horas P50 do item × custo interno por hora do papel)
Margem-alvo     = decisão da empresa (percentual sobre o custo-alvo)
Prêmio de risco = Contingência + Exposição contratual + Uplift de classe

Contingência    = (horas P80 − horas P50) × custo interno
                  P80 ≈ E + 0,84 σ com E e σ do PERT por item (aproximação normal)
Exposição       = Σ (probabilidade × custo) das penalidades e SLAs do documento
                  (incidente crítico em N horas, disponibilidade mínima, perda orgânica, retrabalho
                  de migração). Sem dado, use a pior janela realista e diga que é estimativa.
Uplift          = diferença histórica estimado × real da própria Auditore para a classe do projeto.
                  Sem histórico: 0 e registrar que a base começa neste projeto. O Green Book só
                  serve como teto de sanidade (é dado britânico, de setor público).
```

Regras de uso:

1. **O contrato é preço fixo por fase com critério de aceite.** O cliente vê horas por papel quando
   o edital exige, calculadas como preço ÷ horas P50. Se entregarmos em menos horas, o preço não
   cai. Se errarmos a estimativa, a contingência absorve até o P80; acima disso, é prejuízo nosso,
   como no FPI acima do teto.
2. **Cláusulas que reduzem o prêmio** e por isso podem reduzir o preço: troca de escopo de mesmo
   tamanho sem custo; encerramento antecipado com percentual do restante; acesso aos dados reais
   (analytics, CRM) antes da fase 1; dependências de terceiros com prazo do cliente.
3. **Hora só onde o produto não é mensurável**: suporte, manutenção, consultoria sob demanda.
   Mesmo aí, pacote mensal com horas inclusas é melhor que hora avulsa.
4. **Valor-hora por risco, quando o cliente exige tarifa**: tarifa = (custo interno + margem) ×
   (1 + prêmio de risco ÷ custo-alvo). O multiplicador sai do cálculo acima, não de uma tabela de
   "nível de risco". Duas tarifas (dev/QA e arquitetura/gestão) bastam; mais que isso vira ruído.
5. **Registrar estimado × real por item** ao fim de cada projeto. É o único jeito de o uplift
   deixar de ser zero e de a próxima proposta ter contingência com base própria, que é o método
   da classe de referência aplicado à nossa escala.

## O que não usar

- Percentual de contingência fixo "de mercado" sem fonte. AACE não fixa número; o dev.to e blogs
  de fornecedores que citam P80/P90 são opinião.
- Pesquisas de preferência de compradores (HFS/EY, Futurum) citadas em blogs sem a fonte original.
- Multiplicador de risco por "sensação" (baixo/médio/alto). Se não dá para escrever a premissa,
  não entra no preço.
