#!/usr/bin/env bash
# backup-ref.sh — preserva o HEAD atual numa ref de backup antes de reescrever histórico.
# Recusa árvore suja ou HEAD destacado. Não faz stash, add, reset, checkout nem push.
# Uso: bash backup-ref.sh   (dentro do repo)
set -euo pipefail

branch="$(git symbolic-ref --quiet --short HEAD)" || {
  echo "HEAD destacado: não crio backup. Volte para uma branch ou inspecione o rebase em andamento." >&2
  exit 1
}
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Árvore com mudanças não commitadas: commite ou guarde antes. Nenhum backup criado, nada alterado." >&2
  exit 1
fi

sha="$(git rev-parse HEAD)"
stamp="$(date +%Y%m%d_%H%M%S)"
ref="backup-rebase-${branch}-${stamp}"
git branch "$ref" "$sha"
info="$(git rev-parse --git-path rebase-backup-info)"
{
  printf 'backup_ref: %s\n' "$ref"
  printf 'branch: %s\n' "$branch"
  printf 'head: %s\n' "$sha"
  printf 'quando: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$info"
printf 'backup criado: %s (%s)\nmetadados: %s\nrecuperar (só com autorização): git reset --hard %s\n' "$ref" "${sha:0:10}" "$info" "$ref" # scan-ignore: só imprime a instrução; nunca executa reset
