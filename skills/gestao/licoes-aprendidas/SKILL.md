---
name: licoes-aprendidas
description: Extrai de uma task, branch ou PR recém-concluído a lição de engenharia que o próprio código demonstra — lê commits, diff, corpo do PR e a task do ClickUp, identifica o padrão dominante (decisão estrutural, trade-off, problema resolvido, oportunidade perdida) e devolve uma lição concreta, com arquivo e linha, pronta para virar comentário na task, seção "Notes for the ADR" ou entrada de retro. Use quando o usuário disser "o que aprendemos com isso", "lição dessa task", "retro dessa branch", "qual o takeaway", "/licoes-aprendidas [branch|PR|N commits]", "what did we learn". NÃO use para revisar código em busca de bugs (isso é /review e /code-review) nem para fechar a task (isso é /fechar-task ou o fluxo do ClickUp).
---

# licoes-aprendidas

Um espelho, não uma palestra: mostra o que o código já demonstra. Uma lição bem ancorada vale mais que sete genéricas. Se a mudança for trivial, diga isso e pare.

**Argumento:** `$ARGUMENTS` — vazio (branch atual vs integração), `N` commits, um SHA, um número/URL de PR, ou um ID de task `<PREFIXO>-NNNN`.

## Token discipline

- Escopo em uma chamada: `git log --oneline <alvo>..HEAD` + `git diff --stat <alvo>...HEAD`. Diff completo só se tiver menos de ~500 linhas; senão, leia os 3-5 arquivos mais alterados, no entorno das mudanças.
- Intenção antes do diff: mensagens de commit, corpo do PR (`gh pr view <n> --json title,body,comments`) e, se a branch ou o PR trouxer um ID de task (`<PREFIXO>-NNNN`), a task no ClickUp com `clickup_get_task` **sem `include`** (`workspace_id` em `<raiz>/.claude/ecossistema.json`, quando houver). Comentários do PR: só os que mudaram decisão.
- Não leia arquivos fora do diff. Não leia ADRs inteiros: o índice basta para checar se a decisão já estava registrada.

## Safe-mode

- Só leitura por padrão. Escrever a lição em algum lugar (comentário na task, arquivo local de task, ADR) é opt-in, um destino por vez, com o texto mostrado antes.
- Nunca "você deveria ter". A forma é "a abordagem aqui mostra…" e "na próxima vez que isso aparecer, considere…".
- Se o código está bom, diga que está bom. Lição não é sinônimo de erro.

## Fallback

Pré-requisito ausente ou falho (auth expirada, binário faltando, MCP indisponível, `ecossistema.json` inexistente, script com erro) **não encerra a skill**: diga em uma linha o que faltou e como resolver (`! gcloud auth login`, `/onboarding-ecossistema`, instalar a ferramenta), ofereça seguir sem essa parte e, com a aprovação do usuário, prossiga marcando no Output o que ficou **não verificado**. O que não muda: escrita externa (ClickUp, GCP, `git push`, banco) continua exigindo confirmação, e "não verificado" nunca vira "ok".

## Passos

1. **Escopo.** Sem argumento e em branch de feature: `origin/<integração>..HEAD` (integração = `gh repo view --json defaultBranchRef`; `dev` nos repos do ecossistema). Em `dev`/`main`: últimos 5 commits. PR → `gh pr view <n> --json headRefName,baseRefName,mergeCommit` e use o range correspondente. `<PREFIXO>-NNNN` → ache a branch por `git branch -a --list "*<PREFIXO>-NNNN*"`.

2. **Intenção.** Leia as mensagens de commit e o corpo do PR primeiro. Se houver task, registre o que a descrição pedia e o que os comentários mudaram: a distância entre pedido e entrega costuma ser a lição.

3. **Mudanças.** `git diff --stat`, depois os arquivos que concentram a mudança. Anote decisões estruturais (onde nasceu a fronteira e por quê), trade-offs (legibilidade × performance, DRY × clareza, velocidade × correção), o antes/depois do problema resolvido, e oportunidades perdidas.

4. **Padrão dominante.** Escolha **um**. Ancore em um princípio da lista abaixo ou em uma regra do harness do repo (toggle default-OFF, PR por package, contrato aditivo em `/v1`, segurança > KISS > SOLID, ADR antes de implementar). Máximo dois adicionais, uma linha cada.

   Princípios úteis (cite o que se aplica, não a lista): responsabilidade única · fail-first em vez de fallback silencioso · idempotência em webhook e backfill · estado durável antes de efeito externo · fronteira explícita entre ciclos (pagamento × notificação) · contrato aditivo e versionado · toggle para toda mudança de comportamento · teste na camada mais baixa que observa o invariante · nome que revela intenção · dependência apontando para dentro · observabilidade como parte da feature · decisão registrada antes do código.

5. **Apresentar** com o template abaixo. Trivial (typo, config, bump)? "Mudança direta, sem lição profunda; boa manutenção." e pare.

6. **Destino (opt-in).** Se pedido: comentário na task do ClickUp (`clickup_create_task_comment`), seção `## Notes for the ADR` do arquivo em `.claude/tasks/open/` do repo, ou entrada no `## Working log`. Mostre o texto e confirme antes.

## Output

```markdown
## Lição: <nome do princípio ou regra>

**No código:** <2-3 frases: o que mudou, com arquivo:linha e commit>
**O princípio:** <1-2 frases>
**Por que importa aqui:** <o que quebraria sem isso, ou o que passou a funcionar>
**Da próxima vez:** <uma frase acionável>

---
**Também vale notar:** <princípio> — <1 frase no código> · <1 frase de takeaway>   ← opcional, máx. 2
```
