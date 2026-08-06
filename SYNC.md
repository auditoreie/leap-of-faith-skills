# SYNC — mantendo os dois repos em sincronia

Este conteúdo vive **espelhado em dois repositórios**, um por org, porque Auditore e Sintetiza são organizações GitHub separadas e **não compartilham seats**. Cada repo recebe PRs do seu próprio time.

| Papel | Repo | Remote local |
|---|---|---|
| **Primário** (referência) | `auditoreie/team-skills` | `origin` |
| **Espelho** (também recebe PRs) | `Sintetiza-AI/team-skills` | `sintetiza` |

## Por que não é um repo só

O ideal seria **um repo canônico + acesso cruzado** (convidar o time da outra org). Como não há seats compartilháveis entre as orgs, isso não é possível — daí os dois repos. O risco é **divergência**; este ritual existe pra evitar isso.

## Setup do remote (uma vez)

```bash
git remote add origin     git@github.com:auditoreie/team-skills.git
git remote add sintetiza  https://github.com/Sintetiza-AI/team-skills.git
git fetch --all
```

## Ritual de sincronização

**Antes de começar a trabalhar:**
```bash
git fetch --all
git checkout main
git merge origin/main
git merge sintetiza/main        # reconcilia o que entrou no espelho
# resolva conflitos se houver; main local agora é a união dos dois
```

**Depois de mergear um PR em qualquer um dos repos:**
```bash
git fetch --all
git checkout main
git merge origin/main
git merge sintetiza/main
git push origin   main
git push sintetiza main         # republica a main unificada nos dois
```

**Ao abrir uma feature:** crie a branch a partir da `main` já reconciliada e abra PR **nos dois repos** (push da mesma branch pros dois remotes, um PR em cada). Assim a revisão acontece em cada org e o merge mantém os dois alinhados.

## Regras

- **`main` é sempre a união reconciliada.** Nunca dê push de uma `main` que não passou pelo merge dos dois lados.
- **PRs sempre a partir da `main` atualizada** dos dois remotes, pra minimizar conflito.
- **Auditore é o tie-breaker** em caso de divergência de conteúdo.
- Mudança estrutural (mover/renomear skill, mexer no `install.sh`) → sincronize **imediatamente** nos dois pra não acumular drift.

## Evolução (opcional)

Automatizar via **deploy key + GitHub Action** que, ao mudar a `main` de um repo, abre um "sync PR" no outro. Bot/deploy key **não consome seat**. Não implementado ainda — começamos no manual acima.
