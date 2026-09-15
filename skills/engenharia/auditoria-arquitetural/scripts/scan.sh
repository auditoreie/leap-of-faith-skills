#!/usr/bin/env bash
# scan.sh — sinais arquiteturais num escopo TypeScript (NestJS/Angular). Só leitura.
# Uso: bash scan.sh <pasta> [--no-madge]
# Requer ripgrep (rg). Ciclos via madge (bunx, depois npx); sem rede/ferramenta → "não verificado".
set -uo pipefail
dir="${1:-}"; [[ -n "$dir" && -d "$dir" ]] || { echo "uso: $0 <pasta> [--no-madge]" >&2; exit 2; }
nomadge=0; [[ "${2:-}" == "--no-madge" ]] && nomadge=1
command -v rg >/dev/null 2>&1 || { echo "precisa de ripgrep (rg)" >&2; exit 3; }
dir="${dir%/}"
root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "== raiz para rastreio de uso: $root"
G=(-g '*.ts' -g '!*.spec.ts' -g '!*.test.ts' -g '!*.d.ts' -g '!**/node_modules/**' -g '!**/dist/**')
ALL=(-g '*.ts' -g '*.html' -g '!**/node_modules/**' -g '!**/dist/**')

n_files="$(rg --files "${G[@]}" "$dir" | wc -l | tr -d ' ')"
echo "== escopo: $dir · arquivos .ts (sem specs): $n_files"

echo ""; echo "== maiores arquivos (linhas)"
rg --files "${G[@]}" "$dir" | xargs wc -l 2>/dev/null | sort -rn | grep -v ' total$' | head -10 | sed 's/^/  /'

echo ""; echo "== exports sem referência fora do próprio arquivo (heurística; rastreie DI, templates, rotas, testes e API pública antes de declarar morto)"
exports="$(rg -o --no-heading -n 'export (?:const|function|class|interface|type|enum|abstract class) (\w+)' -r '$1' "${G[@]}" "$dir")"
n_exp="$(printf '%s\n' "$exports" | sed '/^$/d' | wc -l | tr -d ' ')"
[[ "$n_exp" -gt 400 ]] && echo "  aviso: $n_exp exports; analisando os 400 primeiros — divida o escopo por subpasta para cobertura completa"
dead=0
while IFS=: read -r file line name; do
  [[ -z "${name:-}" ]] && continue
  c="$(rg -c -w "$name" "${ALL[@]}" -g "!$(basename "$file")" "$root" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')"
  if [[ "$c" -eq 0 ]]; then echo "  $file:$line $name"; dead=$((dead+1)); fi
done <<< "$(printf '%s\n' "$exports" | head -400)"
[[ $dead -eq 0 ]] && echo "  nenhum"

echo ""; echo "== NestJS: @Injectable que não aparece em nenhum *.module.ts"
inj=0
while IFS=: read -r file line name; do
  [[ -z "${name:-}" ]] && continue
  rg -q -w "$name" -g '*.module.ts' "$root" 2>/dev/null || { echo "  $file:$line $name"; inj=$((inj+1)); }
done <<< "$(rg -U -o --no-heading -n '@Injectable\(\)[\s\S]{0,60}?export class (\w+)' -r '$1' "${G[@]}" "$dir")"
[[ $inj -eq 0 ]] && echo "  nenhum"

echo ""; echo "== NestJS: módulos sem importador (o módulo raiz é esperado aqui)"
mods=0
while IFS=: read -r file line name; do
  [[ -z "${name:-}" ]] && continue
  c="$(rg -c -w "$name" -g '*.ts' -g '!**/node_modules/**' -g "!$(basename "$file")" "$root" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')"
  [[ "$c" -eq 0 ]] && { echo "  $file:$line $name"; mods=$((mods+1)); }
done <<< "$(rg -o --no-heading -n 'export class (\w+Module)' -r '$1' -g '*.module.ts' -g '!**/node_modules/**' "$dir")"
[[ $mods -eq 0 ]] && echo "  nenhum"

echo ""; echo "== Angular: seletores de elemento sem uso em template (não cobre seletor de atributo nem componente roteado)"
sel=0
while IFS=: read -r file line s; do
  [[ -z "${s:-}" ]] && continue
  rg -q "<${s}[[:space:]>/]" "${ALL[@]}" "$root" 2>/dev/null || { echo "  $file:$line <$s>"; sel=$((sel+1)); }
done <<< "$(rg -o --no-heading -n "selector:[[:space:]]*'([a-z][a-z0-9-]*)'" -r '$1' "${G[@]}" "$dir")"
[[ $sel -eq 0 ]] && echo "  nenhum"

echo ""; echo "== nomes de arquivo repetidos em pastas diferentes"
dups="$(rg --files "${G[@]}" "$dir" | xargs -n1 basename | sort | uniq -d | grep -vE '^(index|constants|types|utils|module|controller|service)\.ts$' | head -15)"
[[ -n "$dups" ]] && printf '%s\n' "$dups" | sed 's/^/  /' || echo "  nenhum"

echo ""; echo "== forwardRef (sintoma de ciclo)"
rg -n 'forwardRef\(' "${G[@]}" "$dir" | head -10 | sed 's/^/  /' || echo "  nenhum"

echo ""; echo "== ciclos de import"
if [[ $nomadge -eq 1 ]]; then
  echo "  não verificado (--no-madge)"
else
  tscfg="$(find "$dir" "$(dirname "$dir")" -maxdepth 2 -name 'tsconfig*.json' 2>/dev/null | head -1)"
  out=""
  if command -v bunx >/dev/null 2>&1; then
    out="$(bunx madge --circular --extensions ts --no-spinner ${tscfg:+--ts-config "$tscfg"} "$dir" 2>&1 | tail -25)"
  fi
  if [[ -z "$out" || "$out" == *"error"* && "$out" != *"Found"* && "$out" != *"No circular"* ]]; then
    out="$(npx -y madge --circular --extensions ts --no-spinner ${tscfg:+--ts-config "$tscfg"} "$dir" 2>&1 | tail -25)"
  fi
  if [[ "$out" == *"No circular"* || "$out" == *"Found"* ]]; then printf '%s\n' "$out" | sed 's/^/  /'; else echo "  não verificado (madge indisponível: $(printf '%s' "$out" | tail -1 | cut -c1-100))"; fi
fi

echo ""; echo "resumo: arquivos=$n_files exports_sem_ref=$dead injectables_fora_de_modulo=$inj modulos_sem_importador=$mods seletores_sem_uso=$sel"
