#!/usr/bin/env bash
# diff-schema.sh — classifica a mudança de um schema.prisma (MongoDB) sem ler o arquivo inteiro.
# Uso: bash diff-schema.sh [repo-dir] [caminho/do/schema.prisma]
# Compara origin/<integração>...HEAD e o working tree. Só leitura. Exit 3 se não achar schema.
set -uo pipefail
root="${1:-.}"; cd "$root" 2>/dev/null || { echo "diretório inválido: $root" >&2; exit 3; }
schema="${2:-}"
if [[ -z "$schema" ]]; then
  schema="$(find . -name schema.prisma -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/.claude/*' -not -path '*/.git/*' 2>/dev/null | awk '{ print length, $0 }' | sort -n | head -1 | cut -d' ' -f2-)"
fi
[[ -n "$schema" && -f "$schema" ]] || { echo "schema.prisma não encontrado; passe o caminho" >&2; exit 3; }

integ="${INTEGRATION_BRANCH:-}"
if [[ -z "$integ" ]] && command -v gh >/dev/null 2>&1; then
  slug="$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]##; s#\.git$##')"
  [[ -n "$slug" ]] && integ="$(gh repo view "$slug" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || true)"
fi
[[ -z "$integ" ]] && integ="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
[[ -z "$integ" ]] && integ="dev"
git rev-parse -q --verify "origin/$integ" >/dev/null 2>&1 || integ="main"

provider="$(grep -E 'provider\s*=\s*"' "$schema" | grep -vi 'prisma-client' | head -1 | sed -E 's/.*"(.*)".*/\1/')"
echo "== schema: $schema · provider: ${provider:-?} · base: origin/$integ"
[[ "$provider" != "mongodb" ]] && echo "   aviso: provider não é mongodb — esta skill assume Mongo (sem Prisma Migrate)"

d1="$(git diff "origin/$integ...HEAD" -- "$schema" 2>/dev/null)"
d2="$(git diff HEAD -- "$schema" 2>/dev/null)"
diff="$d1"$'\n'"$d2"
if [[ -z "$(printf '%s' "$diff" | grep -E '^[+-][^+-]')" ]]; then
  echo "sem mudança no schema em relação a origin/$integ (nem no working tree)"; exit 0
fi

add="$(printf '%s\n' "$diff" | grep -E '^\+[^+]' | sed 's/^+//')"
del="$(printf '%s\n' "$diff" | grep -E '^-[^-]' | sed 's/^-//')"
field_re='^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+[A-Za-z_][A-Za-z0-9_]*(\[\])?\??([[:space:]]|$)'

echo ""; echo "== models novos";    printf '%s\n' "$add" | grep -E '^model [A-Za-z]' | sed 's/^/   /' || true
echo "== models removidos";        printf '%s\n' "$del" | grep -E '^model [A-Za-z]' | sed 's/^/   /' || true

echo ""; echo "== campos adicionados"
req=0
while IFS= read -r l; do
  [[ -z "$l" ]] && continue
  printf '%s' "$l" | grep -Eq "$field_re" || continue
  printf '%s' "$l" | grep -Eq '@relation|@@' && continue
  if printf '%s' "$l" | grep -Eq '\?([[:space:]]|$)|@default|@id'; then
    echo "   opcional/default: $(echo "$l" | tr -s ' ')"
  else
    echo "   OBRIGATÓRIO (documentos antigos quebram na leitura): $(echo "$l" | tr -s ' ')"; req=$((req+1))
  fi
done <<< "$add"

echo ""; echo "== campos removidos (só depois de parar de ler e escrever)"
printf '%s\n' "$del" | grep -E "$field_re" | grep -Ev '@@|^model|^enum' | sed 's/^/   /' | tr -s ' ' || true

echo ""; echo "== índices e unicidade"
uniq_add="$(printf '%s\n' "$add" | grep -E '@unique|@@unique' || true)"
[[ -n "$uniq_add" ]] && echo "   @unique novo (db push falha se houver duplicata; conte antes):" && printf '%s\n' "$uniq_add" | sed 's/^/     /' | tr -s ' '
printf '%s\n' "$add" | grep -E '@@index' | sed 's/^/   índice novo: /' | tr -s ' ' || true
printf '%s\n' "$del" | grep -E '@unique|@@unique|@@index' | sed 's/^/   removido: /' | tr -s ' ' || true

echo ""; echo "== enums"
enum_del="$(printf '%s\n' "$del" | grep -E '^[[:space:]]+[A-Z][A-Z0-9_]*[[:space:]]*$' || true)"
[[ -n "$enum_del" ]] && echo "   valor de enum removido (backfill ANTES do merge):" && printf '%s\n' "$enum_del" | sed 's/^/     /' | tr -s ' '
printf '%s\n' "$add" | grep -E '^[[:space:]]+[A-Z][A-Z0-9_]*[[:space:]]*$' | sed 's/^/   valor novo: /' | tr -s ' ' || true

echo ""; echo "== renomes via @map (sem migração de dado)"
printf '%s\n' "$add" | grep -E '@map\(' | sed 's/^/   /' | tr -s ' ' || true

echo ""
dados=0
[[ $req -gt 0 || -n "$uniq_add" || -n "$enum_del" ]] && dados=1
printf '%s\n' "$del" | grep -Eq "$field_re" && dados=1
if [[ $dados -eq 1 ]]; then
  echo "veredito: dados+schema — algum documento existente precisa mudar (ou ser contado) antes do schema valer"
else
  echo "veredito: só-schema — nada de documento existente muda; ainda assim confirme onde o db push roda"
fi
