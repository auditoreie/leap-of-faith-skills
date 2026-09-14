#!/usr/bin/env bash
# Varre o diff <base>...<head> atras de feature toggles e configuracao que a
# release introduz ou remove. A saida e a FONTE DE VERDADE da secao de toggles do
# PR de release — o que o dev declarou no PR e conferido contra isto, nao o inverso.
#
# uso: scan-toggles.sh <base> <head>
#
# Cobre quatro sinais, do mais ao menos confiavel:
#   1. process.env.X lido em qualquer **/src/** (adicionado ou removido)
#   2. arquivos .env* versionados (.env.example, .env-example, .env.docker.example…)
#   3. padroes de leitura de toggle: xEnabled, === 'true', !== 'false', X_ENABLED
#      — adicionados (+) E removidos (-): toggle removido vira comportamento fixo
#   4. campo novo em model/type do prisma que parece configuracao por tenant
#
# Funciona em monorepo (apps/api/src, apps/dash/src…) e em repo plano (src/).
# Antes de 14/09/2026 o filtro era `-- src/` e nao enxergava apps/*/src: deixou
# passar um kill-switch novo e um toggle removido numa release de 14/09/2026.
set -euo pipefail

BASE="${1:?informe a branch base}"
HEAD="${2:?informe a branch head}"

# Aceita branch (resolve para origin/<b>), ref ja qualificada (origin/x, tag) ou hash.
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
RANGE="$BASE_REF...$HEAD_REF"
echo "# diff: $RANGE"

# Codigo de aplicacao: qualquer src/ em qualquer profundidade, sem teste nem build.
SRC=(
  ':(glob)**/src/**'
  ':(exclude,glob)**/*.spec.ts' ':(exclude,glob)**/*.spec.js'
  ':(exclude,glob)**/*.e2e-spec.ts' ':(exclude,glob)**/*.test.ts'
  ':(exclude,glob)**/tests/**' ':(exclude,glob)**/__tests__/**' ':(exclude,glob)**/test/**'
  ':(exclude,glob)**/node_modules/**' ':(exclude,glob)**/dist/**'
)
ENV_FILE_RE='(^|/)\.env[^/]*$'   # .env.example, .env-example, .env.docker.example, .env.stg…

sep() { echo; echo "## $1"; }

sep "1. process.env.* que o codigo passou a ler ou deixou de ler (**/src/**)"
# + = adicionado em head, - = removido. Conta ocorrencias por variavel.
git diff "$RANGE" -- "${SRC[@]}" 2>/dev/null \
  | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' \
  | grep -oE '^[+-].*process\.env\.[A-Z][A-Z0-9_]*' \
  | sed -E 's/^([+-]).*process\.env\.([A-Z][A-Z0-9_]*).*/\1 \2/' \
  | sort | uniq -c | sort -k2,2 -k3,3 \
  | awk '{printf "  %s %-40s (%s ocorrencia(s))\n", $2, $3, $1}' || echo "  (nenhum)"

sep "2. arquivos .env* versionados — variaveis e comentarios adicionados/removidos"
env_files=$(git diff --name-only "$RANGE" 2>/dev/null | grep -E "$ENV_FILE_RE" || true)
if [ -z "$env_files" ]; then
  echo "  (sem mudanca)"
else
  printf '%s\n' "$env_files" | while read -r f; do
    [ -z "$f" ] && continue
    echo "  --- $f"
    git diff "$RANGE" -- "$f" 2>/dev/null \
      | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' \
      | sed -E 's/^/  /' || true
  done
fi

sep "3. leituras de toggle adicionadas (+) e removidas (-)"
# xEnabled / Enabled() / === 'true' / !== 'false' / X_ENABLED / FEATURE_
# `!== 'false'` = default LIGADO (kill-switch); `=== 'true'` = default DESLIGADO.
git diff "$RANGE" -- "${SRC[@]}" 2>/dev/null \
  | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' \
  | grep -E "[a-z]Enabled([^A-Za-z0-9_]|$)|Enabled\(\)|=== 'true'|!== 'false'|=== 'false'|_ENABLED([^A-Za-z0-9_]|$)|LIGADO_POR_PADRAO|FEATURE_" \
  | grep -vE '^[+-]\s*(//|\*|/\*)' \
  | sed -E 's/^([+-])\s*/  \1 /' | sort -u || echo "  (nenhuma)"

sep "4. schema.prisma — campos adicionados/removidos que parecem config por tenant"
# Heuristica: campo escalar novo em qualquer model/type. Quem le decide se e toggle.
git diff "$RANGE" -- ':(glob)**/schema.prisma' 2>/dev/null \
  | grep -E '^[+-]\s+[a-zA-Z][a-zA-Z0-9_]*\s+(String|Boolean|Int|Float|DateTime|Json)(\?|\[\])?' \
  | grep -vE '^[+-]\s+(id|createdAt|updatedAt|atualizacao)\s' \
  | sed -E 's/^([+-])\s+/  \1 /' || echo "  (nenhum)"

sep "5. arquivos de configuracao de toggle/feature tocados"
git diff --name-only "$RANGE" 2>/dev/null \
  | grep -iE "config\.ts$|environment[^/]*\.ts$|feature|toggle|flag|$ENV_FILE_RE" \
  | sed 's/^/  /' || echo "  (nenhum)"

echo
echo "## como ler"
echo "  Cada linha da secao 1 e 3 e um toggle candidato. Para cada um, o que faz e o"
echo "  default vem do proprio codigo (o if que le a var) e do .env* de exemplo — nao do PR."
echo "  '-' na secao 1/3 = leitura REMOVIDA: o comportamento deixou de ser opcional; entra"
echo "  na tabela como 'removido', com o que passa a valer sempre."
echo "  Um toggle aqui que nenhum PR menciona vai para o topo da secao de toggles do"
echo "  release, marcado NAO DECLARADO. Um toggle que um PR menciona e que NAO aparece"
echo "  aqui e 'declarado sem codigo': ou o nome esta errado, ou ficou fora do merge."
echo "  Nem toda process.env e toggle: NODE_ENV, DATABASE_URL, senha de servico sao config."
echo "  A secao 4 lista campo de schema; so e toggle se algum codigo le e ramifica nele."
