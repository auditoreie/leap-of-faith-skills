---
name: rebase-seguro
description: Rebaseia uma branch sobre a integração (ex.: origin/dev) preservando o trabalho dos dois lados — inspeciona estado, cria backup ref antes de reescrever histórico, pede confirmação explícita (rebase é irreversível sem o backup), resolve conflitos lendo os dois lados em vez de aceitar um por atacado, revalida o que mudou e só publica com --force-with-lease quando autorizado. Use quando o usuário disser "rebase", "atualiza minha branch com a dev", "traz a dev pra minha branch", "resolve os conflitos do rebase", "/rebase-seguro [alvo]". NÃO use para merge (isso é git merge normal), cherry-pick, squash pedido isoladamente, nem para abrir PR de release (isso é /gerar-release).
---

# rebase-seguro

Executa o rebase pedido preservando o comportamento pretendido dos dois lados e o trabalho não relacionado. Pedido de rebase **não** autoriza squash, descarte de commit, mudança de config global nem push da branch reescrita: cada um desses é autorização à parte.

**Argumento:** `$ARGUMENTS` — a branch alvo (default: a branch de integração do repo, `origin/dev` nos repos do ecossistema; `gh repo view --json defaultBranchRef` resolve). Pode vir "continuar" quando há rebase em andamento.

`<skill-dir>` é a pasta desta `SKILL.md`.

## Token discipline

- Estado em uma chamada: `git status -sb && git log --oneline -1 && git rev-parse --git-path rebase-merge` (existência do diretório = rebase em andamento). Não leia `git log` longo.
- Conflito: leia só os blocos entre marcadores (`grep -n '^<<<<<<<\|^=======\|^>>>>>>>' <arquivo>`) e o commit sendo reaplicado (`git show --stat REBASE_HEAD`). Não leia o arquivo inteiro se ele for grande.
- Revalidação depois do rebase: `/rodar-testes` com o escopo do diff (`git diff --name-only <alvo>...HEAD`), não a suíte inteira.

## Safe-mode

- **Confirma antes de rebasear**, sempre, com a frase: "rebase de `<branch>` sobre `<alvo>` reescreve `<n>` commits e é irreversível sem o backup ref `<nome>`. Confirma?". Espera resposta explícita.
- Backup ref antes de qualquer reescrita: `scripts/backup-ref.sh` cria `backup-rebase-<branch>-<timestamp>` e recusa árvore suja ou HEAD destacado. Backup é evidência de recuperação, não permissão para `reset`.
- Árvore suja: não faz `stash`, `checkout .`, `reset` nem `clean`. Pede ao usuário para commitar ou guardar, ou usa worktree isolada.
- Rebase interativo, squash, reorder ou drop só se o usuário pediu essa mudança de histórico. Quantidade de commits não é motivo para squash.
- Publicação só com autorização explícita e sempre `--force-with-lease`; lease falhou → inspecione os commits novos do remoto, nunca troque por `--force`. Recuperação que descarta trabalho exige nova permissão.
- Nunca adiciona comentário de "resolvido conflito" em código de produção. Nunca roda a suíte inteira a cada arquivo resolvido.

## Fallback

Pré-requisito ausente ou falho (auth expirada, binário faltando, MCP indisponível, `ecossistema.json` inexistente, script com erro) **não encerra a skill**: diga em uma linha o que faltou e como resolver (`! gcloud auth login`, `/onboarding-ecossistema`, instalar a ferramenta), ofereça seguir sem essa parte e, com a aprovação do usuário, prossiga marcando no Output o que ficou **não verificado**. O que não muda: escrita externa (ClickUp, GCP, `git push`, banco) continua exigindo confirmação, e "não verificado" nunca vira "ok".

## Passos

1. **Inspecionar.** Branch atual, alvo, sujeira, rebase em andamento, `git fetch origin` recente. Conte os commits a reaplicar: `git rev-list --count <alvo>..HEAD`. Se há rebase em andamento e o usuário não disse "continuar", pergunte se retoma ou aborta (`git rebase --abort` volta ao estado anterior; ainda assim, confirme).

2. **Backup.**
   ```bash
   bash <skill-dir>/scripts/backup-ref.sh
   ```
   Recusou (árvore suja ou detached) → resolva a causa com o usuário; não contorne.

3. **Confirmar e rebasear.** Frase de confirmação do Safe-mode. Depois `git rebase <alvo>` direto. Interativo só se pedido.

4. **Conflito.** Para cada arquivo: `ours` = alvo + commits já reaplicados; `theirs` = o commit sendo reaplicado agora. Leia os dois lados e o motivo de cada mudança (`git log -1 --format=%B REBASE_HEAD`). Preserve contratos de segurança, estado e compatibilidade dos dois lados; API renomeada de um lado e usada do outro exige ajustar o uso, não escolher um lado. Resolva, `git diff <arquivo>` para revisar, `git add <arquivo>` só do resolvido, `git rebase --continue`. Conflito repetido no mesmo trecho: reaproveite a decisão anterior.

5. **Revalidar.** `git log --oneline <alvo>..HEAD` (a série faz sentido? nenhum commit sumiu?), `git diff <alvo>...HEAD --stat`, e `/rodar-testes` no escopo do diff. Teste que expõe regressão → fix de produção, não asserção mais fraca.

6. **Publicar (só se autorizado).** `git push --force-with-lease origin <branch>`. Se o PR tiver checks obrigatórios, avise que vão rodar de novo.

## Output

```
Rebase: <branch> sobre <alvo> · <n> commits reaplicados · backup: <ref> (<sha>)
Conflitos: <n> arquivos — <arquivo: decisão em 1 linha> | nenhum
Revalidado: <comando → resultado>
Publicado: sim (--force-with-lease) | não (aguardando autorização)
Recuperação: git reset --hard <backup-ref>  ← só com autorização explícita
```
