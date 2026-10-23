---
name: julgar-pr
description: >-
  Revisa um pull request com régua de evidência e publica, só quando autorizado, uma única review
  consolidada no GitHub com comentários inline. Roda o gate determinístico do próprio repo primeiro,
  passa o diff por um scanner de bypass (supressão de lint/tipo, teste pulado, `as any`, TLS
  desligado, catch vazio), obtém os achados pelo `/code-review` (fork multi-agente na classe crítica,
  um agente leve na rotina), verifica as afirmações da descrição do PR, exige `arquivo:linha`, URL
  oficial ou comando de reprodução em todo blocker e só aceita texto que passe no gate de ruído
  (`scripts/review_gate.py`). Rodada 2 em diante só confere resolução e blocker novo, com teto de 3
  rodadas. Use quando o usuário disser "julgar o PR", "julgue esse PR", "/julgar-pr 123",
  "/julgar-pr 123 publicar", "review com veredito", "revisa e posta no GitHub", "judge this PR".
  NÃO use para análise de diff só no terminal sem veredito (isso é /review ou /code-review direto),
  para corrigir CI, para escrever o fix, para responder comentários de review, nem para revisar
  documento ou ADR.
---

# julgar-pr

Review de PR com régua de evidência: poucos achados, cada um com `arquivo:linha`, URL oficial ou
comando de reprodução, e uma única review consolidada. O que a ferramenta do repo já pega (lint,
tipos, teste) não vira comentário. A skill não escreve o fix e não responde thread de review.

**Alvo:** `$ARGUMENTS` — número ou URL do PR (`123`, `https://github.com/<org>/<repo>/pull/123`);
vazio usa o PR da branch atual. A palavra `publicar` autoriza o passo 7; sem ela, a review fica no
terminal e no `findings.json`.

## Token discipline

- Leia o diff, os arquivos tocados e, só quando um achado exigir, quem chama ou é chamado. Nunca o
  repositório inteiro. Arquivo mecânico (lockfile, gerado, snapshot, vendorizado, build) não se lê.
- Detecção que regex faz vai para `scripts/scan_bypasses.py`, não para prosa.
- `references/contrato-findings.md` (schema, severidades, resumo, voz) é lido no passo 5.
  `references/passadas.md` (checklist A–F) só entra no prompt do agente do passo 3.

## Safe-mode

- **Nunca publica sem autorização.** O passo 7 só roda com `publicar` em `$ARGUMENTS` ou com o ok
  explícito do usuário depois de ver o resumo. A review sai com a identidade do `gh` do usuário e
  com o veredito como evento: `APPROVE` publicado é aprovação formal dele no GitHub.
- Teste e build rodam em **foreground**, uma suíte por vez, com limite de workers
  (`--maxWorkers=2` ou equivalente). Nunca em background, nunca duas suítes ao mesmo tempo.
- Não instala ferramenta, não corrige código, não faz commit, não abre PR.
- Reprodução de blocker só dentro do checkout e do harness de teste do repo. Sem rede, sem ataque.
- Achado sem evidência não existe. Nunca invente `arquivo:linha` ou URL para passar no gate: o gate
  é a última linha, não o alvo.

## Passo 0 — Contexto e rodada

```bash
gh pr view $PR --json number,title,body,author,url,baseRefName,headRefName,additions,deletions,changedFiles
gh pr diff $PR
gh pr view $PR --json files --jq '.files[].path'
gh api user --jq .login
gh api "repos/{owner}/{repo}/pulls/$PR/reviews" --jq '[.[] | select(.user.login=="<login>") | {id, submitted_at, body}]'
```

Sem PR para a branch: use `git diff origin/<base>...HEAD`, siga até o passo 6 e avise que não há
onde publicar. Review anterior sua existe: é rodada N, siga "Rodadas" em vez do fluxo cheio.
Classifique cada arquivo em **core** ou **mecânico**; bloco de 3+ linhas removido num lugar e
adicionado idêntico em outro é código movido, não novo.

**Classe de risco.** Leia `.github/PULL_REQUEST_TEMPLATE.md` se existir. Diff que toca dinheiro,
auth ou credencial, schema ou migração, isolamento entre contas, API pública ou CI/deploy é classe
**crítica**; o resto é **rotina**. Leia também o `CLAUDE.md` do repo: regra que ele marca como
absoluta, de ouro ou inegociável é blocker quando o diff a viola, sem exigir exploração provada.

## Passo 1 — Gate determinístico do repo

```bash
bun run gates origin/<base>   # se package.json tiver o script "gates", ele é a escada inteira
# senão: os scripts de lint, typecheck e teste focado que package.json, Makefile ou CI declararem
gh pr diff $PR | python3 <pasta-da-skill>/scripts/scan_bypasses.py
```

Resultado do gate vai para "Checagens" no resumo, com números crus; o que ele aponta fica fora dos
comentários. Sem tooling, diga isso no resumo e siga; não instale nada. Cada linha do scanner
(`caminho:linha<TAB>categoria<TAB>trecho`) é candidato da passada F, não achado: supressão com
justificativa e link de issue passa; supressão nua não.

## Passo 2 — Pesquisa externa obrigatória

Liste toda superfície externa do diff: dependência nova ou com bump, API chamada, recurso de
framework sensível a versão. Para cada uma, abra a doc oficial, release notes ou advisory e anote a
URL. Sem fonte conclusiva, o achado vira pergunta ou morre. Nenhuma superfície: escreva isso no
log de pesquisa.

## Passo 3 — Achados

| Classe | Como obter os candidatos |
|---|---|
| crítica | `Skill(skill: "code-review", args: "<PR> high")`: fork multi-agente com verificação própria. Sem `code-review` na sessão, o agente da linha abaixo com `model: "opus"` |
| rotina | um `Agent` `model: "sonnet"`, somente leitura; prompt = `references/passadas.md` + diff + saída do scanner + resultado do passo 1 + regras do `CLAUDE.md` do repo + "não rode teste nem build" |

Candidato = afirmação, severidade provisória, ponteiro de evidência, input ou estado que dispara a
falha. **Passada E é sempre sua:** cada "corrige X" ou "melhora Y" da descrição e cada checkbox
marcado do template vira claim verificável (teste que falha antes e passa depois, comando rodado,
link). Sem evidência, vira 🟠 em forma de pergunta pedindo a prova, nunca afirmação de que é falso.

## Passo 4 — Verificação

Para cada candidato: releia o código no ponto citado e confirme. Deduplique entre passadas. Na
dúvida, rebaixe: blocker incerto é should-fix em forma de pergunta. Blocker de correção ou
segurança que dá para demonstrar no harness do repo ganha evidência `repro` com comando e saída;
se a reprodução era viável e não reproduziu, o achado morre. Risco baixo não é falso positivo:
mate por falta de evidência, rebaixe por falta de impacto.

## Passo 5 — Escrever

Leia `references/contrato-findings.md` agora. Escreva em português com acentuação completa, salvo
pedido de outro idioma; tokens de veredito, identificadores e saída de ferramenta ficam literais.
Grave o `findings.json` fora do repositório: no diretório de rascunho da sessão, se houver, senão
em `${TMPDIR:-/tmp}/julgar-pr/<pr>/`. `templates/findings.exemplo.json` passa no gate; use de molde.

## Passo 6 — Gate

```bash
python3 <pasta-da-skill>/scripts/review_gate.py <caminho>/findings.json
```

Corrija cada violação e rode de novo até `gate: PASS`. A saída nomeia o padrão e o achado: apague
a frase, não a reescreva em volta do padrão.

## Passo 7 — Publicar (só com autorização)

```bash
python3 <pasta-da-skill>/scripts/post_review.py <caminho>/findings.json --pr $PR
```

Uma chamada: resumo, evento do veredito e comentários inline. Autor do PR igual ao usuário do
`gh`: o script publica como COMMENT e anota o veredito pretendido no rodapé. HTTP 422 com inline:
alguma âncora não está no diff; reancore numa linha alterada ou leve o achado para o resumo.

## Rodadas

Rodada 1 é a review inteira: nada fica guardado para depois. Rodada N ≥ 2 faz só duas coisas:
(1) tabela de Resolução com todo achado anterior, resolvido com o commit, aberto ou recusado-aceito;
(2) só 🔴 novo introduzido pelo fix. Nenhum 🟠, 🟡 ou 🟣 novo. Recusa com razão que se sustenta vira
recusado-aceito; senão, rebata uma vez com evidência nova e pare. Na rodada 3 todo achado aberto
vira fix, issue combinada ou escalada fora da thread. Aprove assim que o PR melhorar a saúde do
código; 🟡 aberto nunca segura APPROVE.

## Output

```
⚖️ julgar-pr — PR #<n> <título> · rodada <N> · classe <crítica|rotina>
Veredito: <APPROVE|COMMENT|REQUEST_CHANGES>  (🔴 n · 🟠 n · 🟡 n · 🟣 n)
Checagens: <gate do repo> · scanner: <n> candidato(s) · pesquisa: <n> URL(s) · pulados: <n>
findings.json: <caminho> · gate: PASS · publicado: <url da review | não, aguardando "publicar">
```
