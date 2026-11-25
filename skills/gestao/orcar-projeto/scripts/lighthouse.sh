#!/usr/bin/env bash
# Lighthouse mobile (padrão: form factor mobile, throttling simulado), 3 execuções por URL, em série.
# Uso: lighthouse.sh <arquivo com linhas "rotulo url">   (RUNS=3 por padrão)
# Saída: data/lighthouse/<rotulo>-<n>.json
set -euo pipefail
# Roda a partir da raiz do projeto: grava em ./data/lighthouse/.
LISTA="$1"
RUNS="${RUNS:-3}"
mkdir -p data/lighthouse
while read -r rotulo url; do
  [ -z "${rotulo:-}" ] && continue
  for n in $(seq 1 "$RUNS"); do
    out="data/lighthouse/${rotulo}-${n}.json"
    [ -s "$out" ] && continue
    echo "$(date +%H:%M:%S) $rotulo #$n $url"
    bunx lighthouse@13.5.0 "$url" --quiet --output=json --output-path="$out" \
      --only-categories=performance,seo,accessibility,best-practices \
      --chrome-flags="--headless=new --no-sandbox" || echo "falhou: $rotulo #$n"
    sleep 5
  done
done < "$LISTA"
