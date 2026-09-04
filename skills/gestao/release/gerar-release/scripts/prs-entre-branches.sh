#!/usr/bin/env bash
# Lista o que existe em <head> e ainda nao esta em <base>: PRs mergeados (por
# numero) e commits diretos sem PR. Roda de dentro do repositorio.
#
# uso: prs-entre-branches.sh <base> <head>
set -euo pipefail

BASE="${1:?informe a branch base (ex: main)}"
HEAD="${2:?informe a branch head (ex: staging)}"

resolve() {
  local r="$1"
  if git rev-parse --verify --quiet "origin/$r" >/dev/null 2>&1; then
    git fetch origin "$r" --quiet 2>/dev/null || true
    echo "origin/$r"
  elif git rev-parse --verify --quiet "$r" >/dev/null 2>&1; then
    echo "$r"
  else
    echo "ref nao encontrada: $r" >&2; exit 2
  fi
}
BASE_REF=$(resolve "$BASE"); HEAD_REF=$(resolve "$HEAD")
RANGE="$BASE_REF..$HEAD_REF"
echo "# range: $RANGE"

echo "## PRs mergeados em $HEAD ausentes em $BASE"
prs=$(git log --merges --format='%s' "$RANGE" \
  | grep -oE 'Merge pull request #[0-9]+' | grep -oE '[0-9]+' | sort -un || true)
if [ -z "$prs" ]; then
  echo "(nenhum)"
else
  echo "$prs"
fi

echo
echo "## commits diretos (sem PR) — hotfix, bump, etc."
diretos=$(git log --no-merges --first-parent --format='%h %ad %s' --date=short "$RANGE" \
  | grep -vE '\[skip ci\]|^[0-9a-f]+ [0-9-]+ Merge ' || true)
if [ -z "$diretos" ]; then
  echo "(nenhum)"
else
  echo "$diretos"
fi

echo
echo "## resumo"
n_prs=$(printf '%s' "$prs" | grep -c . || true)
n_dir=$(printf '%s' "$diretos" | grep -c . || true)
n_schema=$(git diff --name-only "$BASE_REF...$HEAD_REF" -- prisma/schema.prisma | grep -c . || true)
echo "prs=$n_prs commits_diretos=$n_dir schema_alterado=$n_schema"
