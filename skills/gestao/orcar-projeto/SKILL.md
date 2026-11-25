---
name: orcar-projeto
description: >-
  Monta orçamento e proposta técnica de projeto de software a partir dos documentos do cliente
  (briefing, edital, cadernos, RFP): extrai a régua de avaliação e os SLAs, fecha premissas com
  /entrevistar, mede o sistema real antes de estimar (crawl somente leitura, Lighthouse, APIs
  públicas), estima por item com três pontos e horas por papel, separa base de opcionais, forma o
  preço com prêmio de risco explícito (contingência por confiança, exposição a SLA) em vez de
  valor-hora puro, e calcula o gross-up tributário por entidade com fonte legal. Toda linha sai
  rotulada [caderno], [medido] ou [estimativa]. Use quando o usuário disser "orçar esse projeto",
  "monta a proposta", "quantas horas isso dá", "preço pra essa concorrência", "/orcar-projeto
  <pasta com os documentos>", "estimate this project", "build the proposal". NÃO use para
  estimar uma task isolada dentro de um projeto já contratado (isso é /criar-task), para escrever
  a spec funcional (isso é /spec), nem para decidir arquitetura sem orçamento envolvido (isso é
  /entrevistar direto).
---

# orcar-projeto

Produz `orcamento.md` (e opcionalmente a planilha interativa) com horas por item e por papel,
base e opcionais, preço com prêmio de risco e comparação tributária. A regra que governa tudo:
**nenhum número sem rótulo de origem e sem a premissa ao lado**. Quem lê precisa auditar o
orçamento sem confiar na gente.

**Alvo:** `$ARGUMENTS` — pasta com os insumos (`docs/`) e, se houver, URL do sistema atual.
Exemplo: `/orcar-projeto docs/ https://www.exemplo.com.br`. `<skill-dir>` é a pasta desta `SKILL.md`.

## Token discipline

- Leia os insumos uma vez, via `pdftotext -layout` para `docs/txt/`, e busque com Python a partir
  daí. Não releia PDF inteiro a cada pergunta.
- Medição (crawl, Lighthouse) roda em script, não no modelo. O modelo lê o CSV resumido.
- `references/precificacao-por-risco.md` só no passo 6. `references/tributos-br.md` só no passo 7.
- Pesquisa de plataforma externa (CMS, CDN, CRM, API de mensageria) vai para `Explore` com
  `model: "sonnet"` e volta com URL da doc oficial. Afirmação sem URL não entra no orçamento.

## Safe-mode

- **Crawl é somente leitura**: respeita `robots.txt`, no máximo 1 requisição por segundo,
  user-agent genérico sem e-mail pessoal. Nunca preenche formulário, nunca envia mensagem,
  nunca contata ninguém do cliente.
- Não cria remote, não faz push, não compartilha artefato. Material de concorrência é sigiloso.
- Número de mercado (valor-hora "típico", taxa de conversão "do setor") só com fonte citável;
  sem fonte, diga que não há e use o dado interno ou a decisão do usuário.
- Não inventa requisito: o documento do cliente é a fonte de verdade. Lacuna vira pergunta ou
  opcional, nunca escopo implícito.

## Passos

1. **Régua antes do escopo.** Dos insumos, extraia em tabela: critérios de avaliação e pesos,
   formato exigido da proposta (ex.: "horas por papel"), SLAs e penalidades, garantia, prazo e
   fases, aceite. Isso define o que a proposta precisa mostrar e o prêmio de risco do passo 6.
2. **Descoberta com `/entrevistar`.** Tema: "premissas do orçamento de <projeto>". Primeira
   rodada obrigatória: acessos a dados reais (analytics, search console, CRM), volumes (leads/mês,
   conteúdo, mídia), o que o cliente já tem contratado, quem são as outras partes (agência,
   departamento interno), entidade que fatura, custo interno por hora e margem-alvo. "Não sei"
   vira item de "dados que faltam" com dono.
3. **Medir o sistema real** (se existe um). `python3 <skill-dir>/scripts/crawl.py --site <url>` → `data/raw/pages.jsonl`;
   `bash <skill-dir>/scripts/lighthouse.sh <lista>` + `python3 <skill-dir>/scripts/lighthouse_resumo.py` → tabela. Conte objetos
   publicados por API pública quando houver (WordPress: cabeçalho `X-WP-Total` de
   `/wp-json/wp/v2/<tipo>`). Compare com o inventário do cliente em `data/inventario-vs-caderno.md`:
   divergência é lacuna, e lacuna é onde a proposta mostra expertise.
4. **Estimar por item, não por bloco.** Use `templates/orcamento.md`. Cada item tem: horas
   otimista/provável/pessimista (PERT: E = (O + 4P + Pe)/6, σ = (Pe − O)/6), papel
   (dev/QA ou arquitetura/gestão), fundamento em uma linha com rótulo, referência no documento
   do cliente. Versão **enxuta** = provável; **completa** = com o que o documento pede mas o
   volume medido não justifica ainda. Se vier item sem fundamento, pare: não chute, pergunte.
5. **Base e opcionais.** Base = o mínimo que atende o documento. Opcional = escolha do cliente
   com preço fechado e condição de ativação ("só se houver mídia ativa na plataforma"). Lacuna
   do documento vira opcional com a solução proposta, não risco embutido no preço.
6. **Preço com prêmio de risco.** Leia `references/precificacao-por-risco.md`. Preço da base =
   custo-alvo (horas P50 × custo interno) + margem-alvo + prêmio de risco (contingência P80 − P50
   + valor esperado das penalidades de SLA). O contrato é **preço fixo por fase com aceite**; o
   valor-hora que aparece na proposta é o preço dividido pelas horas P50 por papel, para cumprir
   o formato exigido, não a base de cobrança. Suporte e manutenção ficam por hora ou pacote.
7. **Tributo e entidade.** Leia `references/tributos-br.md`. Gross-up do preço líquido por
   entidade candidata (Simples por anexo e faixa; Lucro Real com PIS/COFINS cumulativos se for
   software). Mostre lado a lado o que sobra. Decisão é do usuário com a contabilidade.
8. **Validação cruzada.** Se existe proposta anterior ou post mortem, confira cada afirmação
   contra o documento do cliente e marque confirmada / parcial / refutada com a evidência.
9. **Entregar.** `orcamento.md` conforme o template; opcionalmente a planilha interativa
   (artefato com horas por papel, opcionais com checkbox, comparação tributária). Registre em
   `dados-que-faltam` tudo que o usuário respondeu "não sei".

| Situação | Faça |
|---|---|
| Documento do cliente contradiz a medição | Apresente os dois com método (lab × campo, data), nunca "o cliente errou" |
| Volume real é pequeno | KISS: não proponha fila, cache ou cluster que o volume não exige; anote como opcional condicionado |
| Fornecedor atual aparece no diagnóstico | Cite o achado, não o nome da empresa |
| Sem histórico interno de estimado × real | Use a contingência por PERT e diga que a base de referência começa neste projeto |

## Output

```
📐 orcar-projeto — <projeto> · <n> itens · base <h> h / completa <h> h

| Versão | Horas P50 | Preço líquido | Prêmio de risco | Preço com tributo (<entidade>) |
|---|---:|---:|---:|---:|

Opcionais: <n>, de R$ <min> a R$ <max>
Lacunas do documento cobertas: <lista curta>
Dados que faltam: <lista com dono>
Arquivos: orcamento.md, data/inventario-vs-caderno.md, data/performance.md
Próximo passo: <decisão que só o usuário toma>
```
