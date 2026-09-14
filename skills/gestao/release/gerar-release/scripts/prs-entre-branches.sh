#!/usr/bin/env bash
# Lista o que existe em <head> e ainda nao esta em <base>: PRs mergeados (por
# numero) e commits diretos sem PR. Roda de dentro do repositorio.
#
# uso: prs-entre-branches.sh <base> <head>
#      MAX_API_LOOKUPS=40 (teto de chamadas commits/<sha>/pulls; 0 desliga a fonte C)
#      BASE_NAME=main (nome da branch que <base> representa, quando <base> e hash ou tag;
#                      com nome de branch o script deduz sozinho)
#
# Tres fontes, da mais barata para a mais cara, unidas no final:
#   A. mensagem dos merge commits ("Merge pull request #N")            — so git
#   B. PRs mergeados no GitHub cujo headRefOid OU mergeCommit esta no range — 1 chamada gh
#      Pega PR EMPILHADO (mergeado por dentro de outro PR, sem merge commit
#      proprio) e squash merge. Foi o buraco que deixou um PR empilhado
#      fora de uma release em 14/09/2026.
#      PR cuja base e a propria <base> (release anterior, hotfix direto) e
#      ignorado: seu conteudo ja esta na base ou E a base.
#   C. commits first-parent do range ainda sem PR -> API commits/<sha>/pulls — 1 chamada por commit
#      Pega rebase merge. Tem teto (MAX_API_LOOKUPS).
# Sem `gh` autenticado cai para A e avisa: nesse caso confira o log do range a mao.
set -euo pipefail

BASE="${1:?informe a branch base (ex: main)}"
HEAD="${2:?informe a branch head (ex: staging)}"
MAX_API_LOOKUPS="${MAX_API_LOOKUPS:-40}"
BASE_NAME="${BASE_NAME:-${BASE#origin/}}"

# Aceita branch (resolve para origin/<b>), ref ja qualificada (origin/x, tag) ou hash.
resolve() {
  local r="$1" b="${1#origin/}"
  # Fetch ANTES de validar: branch remota nova passa a existir localmente e
  # branch conhecida fica atualizada. So cai na copia local se o fetch falhar,
  # e avisa — inventario sobre ref velha e o erro mais silencioso desta skill.
  if git fetch origin "$b" --quiet 2>/dev/null \
     && git rev-parse --verify --quiet "origin/$b" >/dev/null 2>&1; then
    echo "origin/$b"
  elif git rev-parse --verify --quiet "$r" >/dev/null 2>&1; then
    echo "$r"   # hash, tag ou branch so local
  elif git rev-parse --verify --quiet "origin/$b" >/dev/null 2>&1; then
    echo "aviso: fetch de origin/$b falhou; usando a copia local, que pode estar desatualizada" >&2
    echo "origin/$b"
  else
    echo "ref nao encontrada: $r" >&2; exit 2
  fi
}
BASE_REF=$(resolve "$BASE"); HEAD_REF=$(resolve "$HEAD")
RANGE="$BASE_REF..$HEAD_REF"
echo "# range: $RANGE"

commits=$(git rev-list "$RANGE")
if [ -z "$commits" ]; then
  echo "## nada a liberar: $HEAD_REF nao tem commit ausente em $BASE_REF"
  echo; echo "## resumo"; echo "prs=0 commits_diretos=0 schema_alterado=0 fonte=git"
  exit 0
fi
in_range() { printf '%s\n' "$commits" | grep -q "^$1"; }

gh_ok=0
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then gh_ok=1; fi

# ---- A: merge commits -------------------------------------------------------
prs_a=$(git log --merges --format='%s' "$RANGE" \
  | grep -oE 'Merge pull request #[0-9]+' | grep -oE '[0-9]+' || true)

# ---- B: PRs mergeados no GitHub, casados por SHA -----------------------------
prs_b=""; notas=""; rows_b=""; ignorados=""
if [ "$gh_ok" = 1 ]; then
  since=$(git log -1 --format=%cs "$(git merge-base "$BASE_REF" "$HEAD_REF")")
  # Sem --base: PR empilhado pode ter ficado com base numa feature branch.
  rows_b=$(gh pr list --state merged --search "merged:>=$since" --limit 300 \
             --json number,headRefOid,mergeCommit,baseRefName \
             --jq '.[] | "\(.number)\t\(.headRefOid)\t\(.mergeCommit.oid // "-")\t\(.baseRefName)"' 2>/dev/null || true)
  while IFS=$'\t' read -r num head_sha merge_sha pr_base; do
    [ -z "$num" ] && continue
    hit=""
    if [ "$merge_sha" != "-" ] && in_range "$merge_sha"; then hit="mergeCommit"; fi
    if [ -n "$head_sha" ] && in_range "$head_sha"; then hit="${hit:+$hit+}headRefOid"; fi
    [ -z "$hit" ] && continue
    if [ "$pr_base" = "$BASE_NAME" ]; then ignorados="$ignorados #$num"; continue; fi
    prs_b="$prs_b$num"$'\n'
    if ! printf '%s\n' "$prs_a" | grep -qx "$num"; then
      notas="$notas  #$num — sem merge commit proprio no range (empilhado em outro PR, ou squash); casado por $hit"$'\n'
    fi
  done <<< "$rows_b"
fi

# ---- C: commits first-parent sem PR conhecido -> API de commits ---------------
prs_c=""; diretos=""; lookups=0; truncado=0
cand=$(git log --no-merges --first-parent --format='%H %ad %s' --date=short "$RANGE" \
  | grep -vE '\[skip ci\]' || true)
while read -r sha rest; do
  [ -z "$sha" ] && continue
  # squash commit ou head de PR fast-forwarded: ja e de um PR visto em B
  if [ -n "$rows_b" ] && printf '%s\n' "$rows_b" | awk -F'\t' -v s="$sha" '$2==s || $3==s {f=1} END{exit !f}'; then continue; fi
  if [ "$gh_ok" = 1 ] && [ "$lookups" -lt "$MAX_API_LOOKUPS" ]; then
    lookups=$((lookups + 1))
    found=$(gh api "repos/{owner}/{repo}/commits/$sha/pulls" \
              --jq '.[] | select(.merged_at != null) | .number' 2>/dev/null || true)
    if [ -n "$found" ]; then
      for n in $found; do
        prs_c="$prs_c$n"$'\n'
        if ! printf '%s\n%s' "$prs_a" "$prs_b" | grep -qx "$n"; then
          notas="$notas  #$n — casado pela API de commits (rebase merge; commit ${sha:0:8})"$'\n'
        fi
      done
      continue
    fi
  elif [ "$gh_ok" = 1 ]; then
    truncado=1
  fi
  diretos="$diretos${sha:0:8} $rest"$'\n'
done <<< "$cand"

# ---- saida -------------------------------------------------------------------
prs=$(printf '%s\n%s\n%s' "$prs_a" "$prs_b" "$prs_c" | grep -E '^[0-9]+$' | sort -un || true)

echo "## PRs mergeados em $HEAD ausentes em $BASE"
if [ -z "$prs" ]; then echo "(nenhum)"; else echo "$prs"; fi

if [ -n "$notas" ]; then
  echo
  echo "## PRs sem merge commit proprio — vai como nota na tabela do release"
  printf '%s' "$notas"
fi
if [ -n "$ignorados" ]; then
  echo
  echo "## ignorados: PR com base $BASE_NAME (release anterior ou hotfix ja na base):$ignorados"
fi

echo
echo "## commits diretos (sem PR) — hotfix, bump, etc."
if [ -z "$diretos" ]; then echo "(nenhum)"; else printf '%s' "$diretos"; fi
if [ "$truncado" = 1 ]; then
  echo "  (aviso: teto MAX_API_LOOKUPS=$MAX_API_LOOKUPS atingido; commits acima podem ser de PR rebase-merged)"
fi
if [ "$gh_ok" = 0 ]; then
  echo "  (aviso: gh ausente ou sem auth — so a fonte A rodou; PR empilhado/squash/rebase NAO aparece. Confira: git log --oneline $RANGE)"
fi

echo
echo "## resumo"
n_prs=$(printf '%s' "$prs" | grep -c . || true)
n_dir=$(printf '%s' "$diretos" | grep -c . || true)
n_schema=$(git diff --name-only "$BASE_REF...$HEAD_REF" -- ':(glob)**/schema.prisma' | grep -c . || true)
fonte="git"; [ "$gh_ok" = 1 ] && fonte="git+gh(api_lookups=$lookups)"
echo "prs=$n_prs commits_diretos=$n_dir schema_alterado=$n_schema fonte=$fonte"
