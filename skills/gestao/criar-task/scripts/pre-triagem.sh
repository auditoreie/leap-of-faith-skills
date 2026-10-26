#!/usr/bin/env bash
# pre-triagem.sh — varredura determinística antes de criar uma task.
#
# Uso: bash pre-triagem.sh <repo-dir> <kw1> [kw2] [kw3 ...]
#      INTEGRATION_BRANCH=staging bash pre-triagem.sh <repo-dir> <kw>   # força a branch de integração
#
# Faz: git fetch; descobre a branch de integração (default do GitHub via gh → origin/HEAD → dev);
# reporta o estado do checkout local; lista PRs abertos, branches remotas e commits recentes da
# integração que casam com as palavras-chave (case-insensitive, OR); extrai os IDs de task dos PRs (TASK_PREFIX=PROJ estreita o regex).
# Somente leitura: nenhum checkout, pull, branch ou write. Exit: 0 ok · 2 uso · 3 repo inválido.
# Compatível com bash 3.2 (macOS) e grep BSD/GNU (ERE).

set -uo pipefail

if [[ $# -lt 2 ]]; then
  echo "uso: $0 <repo-dir> <kw1> [kw2 ...]" >&2
  exit 2
fi

repo="$1"; shift
[[ -d "$repo/.git" ]] || { echo "não é um repo git: $repo" >&2; exit 3; }
cd "$repo" || exit 3

# regex OR das palavras-chave, com metacaracteres ERE escapados
pattern=""
for kw in "$@"; do
  esc="$(printf '%s' "$kw" | sed -E 's#[][\.|*?+(){}^$\\/]#\\&#g')"
  pattern="${pattern:+$pattern|}$esc"
done

origin_url="$(git remote get-url origin 2>/dev/null || true)"
slug="$(printf '%s' "$origin_url" | sed -E 's#.*github\.com[:/]##; s#\.git$##')"
gh_ok=nao
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then gh_ok=sim; fi

echo "== repo: $(basename "$PWD") · origin: ${slug:-?} · gh autenticado: $gh_ok"

# --- fetch ------------------------------------------------------------------
if git fetch origin --quiet --prune 2>/dev/null; then
  echo "fetch: ok"
else
  echo "fetch: FALHOU — leitura pode estar defasada (offline? sem acesso ao remote?)"
fi

# --- branch de integração ----------------------------------------------------
integ="${INTEGRATION_BRANCH:-}"
if [[ -z "$integ" && "$gh_ok" == sim && -n "$slug" ]]; then
  integ="$(gh repo view "$slug" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || true)"
fi
[[ -z "$integ" ]] && integ="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
[[ -z "$integ" ]] && integ="dev"
if ! git rev-parse -q --verify "origin/$integ" >/dev/null 2>&1; then
  echo "branch de integração 'origin/$integ' não existe — rode com INTEGRATION_BRANCH=<nome>" >&2
  exit 3
fi

sha="$(git rev-parse --short "origin/$integ")"
when="$(git log -1 --format='%cs' "origin/$integ")"
subj="$(git log -1 --format='%s' "origin/$integ" | cut -c1-90)"
echo "integração: origin/$integ @ $sha ($when) — $subj"

# --- checkout local ---------------------------------------------------------
cur="$(git branch --show-current 2>/dev/null)"; [[ -z "$cur" ]] && cur="(detached)"
dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
behind="$(git rev-list --count "HEAD..origin/$integ" 2>/dev/null || echo '?')"
ahead="$(git rev-list --count "origin/$integ..HEAD" 2>/dev/null || echo '?')"
if [[ "$cur" == "$integ" ]]; then
  echo "local: branch $cur · arquivos modificados=$dirty · atrás de origin=$behind · à frente=$ahead"
else
  echo "local: branch $cur (não é a integração) · arquivos modificados=$dirty · commits de origin/$integ ausentes aqui=$behind"
fi
if [[ "$cur" != "$integ" || "$behind" != "0" || "$dirty" != "0" ]]; then
  echo "  → o checkout não reflete origin/$integ: leia com 'git show origin/$integ:<arquivo>' e 'git grep <padrão> origin/$integ -- <path>'"
fi

# --- PRs abertos ------------------------------------------------------------
echo ""
echo "== PRs abertos que casam com /$pattern/i"
prs_hit=0; prs_total="?"; pr_task_ids=""
if [[ "$gh_ok" == sim && -n "$slug" ]]; then
  lines="$(gh pr list -R "$slug" --state open --limit 100 \
    --json number,title,headRefName,author,url,isDraft,updatedAt \
    --jq '.[] | "#\(.number)\t\(.title)\t\(.headRefName)\t@\(.author.login)\t\(if .isDraft then "draft" else "open" end)\t\(.updatedAt[:10])\t\(.url)"' 2>/dev/null || true)"
  prs_total="$(printf '%s\n' "$lines" | sed '/^$/d' | wc -l | tr -d ' ')"
  hits="$(printf '%s\n' "$lines" | grep -iE -- "$pattern" || true)"
  prs_hit="$(printf '%s\n' "$hits" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ -n "$hits" ]]; then
    printf '%s\n' "$hits" | awk -F'\t' '{printf "  %s %s\n     branch %s · %s · %s · atualizado %s\n     %s\n", $1, $2, $3, $4, $5, $6, $7}'
  else
    echo "  nenhum"
  fi
  pr_task_ids="$(printf '%s\n' "$lines" | grep -oE "${TASK_PREFIX:-[A-Z]{2,6}}-[0-9]{2,5}" | sort -u | tr '\n' ' ')"
  echo "  (PRs abertos no repo: $prs_total · tasks referenciadas por eles: ${pr_task_ids:-nenhuma})"
else
  echo "  NÃO VERIFICADO — gh indisponível ou não autenticado. Não afirme que não há PR duplicado."
fi

# --- branches remotas -------------------------------------------------------
echo ""
echo "== branches remotas que casam"
br="$(git branch -r --format='%(refname:short)' 2>/dev/null | grep -v -- '->' | grep -iE -- "$pattern" || true)"
br_hit="$(printf '%s\n' "$br" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ -n "$br" ]]; then
  while IFS= read -r b; do
    [[ -z "$b" ]] && continue
    echo "  $b ($(git log -1 --format='%cs' "$b" 2>/dev/null))"
  done <<< "$br"
else
  echo "  nenhuma"
fi

# --- commits recentes na integração -----------------------------------------
echo ""
echo "== commits em origin/$integ (90 dias) que casam"
cm="$(git log "origin/$integ" --since=90.days -i -E --grep="$pattern" --format='  %h %cs %s' 2>/dev/null | head -15)"
cm_hit="$(printf '%s\n' "$cm" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ -n "$cm" ]]; then printf '%s\n' "$cm"; else echo "  nenhum"; fi

# --- resumo -----------------------------------------------------------------
echo ""
echo "resumo: prs=$prs_hit branches=$br_hit commits=$cm_hit integracao=origin/$integ@$sha gh=$gh_ok"
