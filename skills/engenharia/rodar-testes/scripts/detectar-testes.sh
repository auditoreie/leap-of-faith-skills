#!/usr/bin/env bash
# detectar-testes.sh — descobre como o repo testa, sem rodar nada.
# Uso: bash detectar-testes.sh [repo-dir]   (default: diretório atual)
# Cobre raiz, apps/* e packages/*. Só leitura. Exit 3 se o diretório não existir.
set -uo pipefail
root="${1:-.}"
cd "$root" 2>/dev/null || { echo "diretório inválido: $root" >&2; exit 3; }

pm() {
  local d="$1"
  if   [[ -f "$d/bun.lockb" || -f "$d/bun.lock" ]]; then echo bun
  elif [[ -f "$d/pnpm-lock.yaml" ]]; then echo pnpm
  elif [[ -f "$d/yarn.lock" ]]; then echo yarn
  elif [[ -f "$d/package-lock.json" ]]; then echo npm
  else echo "?"; fi
}

echo "== repo: $(basename "$PWD") · processos node ativos: $(ps aux | grep -cE '[n]ode') (limite prático ~15)"

for p in . apps/*/ packages/*/; do
  p="${p%/}"
  [[ -f "$p/package.json" ]] || continue
  echo ""
  echo "-- $p (pm: $(pm "$p"))"
  python3 - "$p/package.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for k, v in d.get('scripts', {}).items():
    if any(t in k for t in ('test', 'e2e', 'spec', 'prisma')):
        print(f"   {k}: {v[:110]}")
PY
  ls "$p"/jest.config.* "$p"/jest-e2e.json "$p"/karma.conf.js "$p"/playwright.config.* 2>/dev/null | sed 's#^#   config: #'
  find "$p" -maxdepth 5 -name 'schema.prisma' -not -path '*/node_modules/*' 2>/dev/null | sed 's#^#   prisma: #'
  n=$(find "$p" -type f \( -name '*.spec.ts' -o -name '*.test.ts' \) -not -path '*/node_modules/*' -not -path '*/dist/*' 2>/dev/null | wc -l | tr -d ' ')
  echo "   specs: $n"
done

echo ""
echo "-- CLAUDE.md: linhas sobre teste (mandam sobre o resto)"
found=0
for f in CLAUDE.md ../CLAUDE.md; do
  if [[ -f "$f" ]]; then
    grep -nEi 'test|spec|karma|jest|inst[aá]vel|maxWorkers|runInBand' "$f" | cut -c1-160 | head -12
    found=1; break
  fi
done
[[ $found -eq 0 ]] && echo "   (sem CLAUDE.md)"

echo ""
echo "-- compose com mongo (integração local)"
grep -lE 'mongo' docker-compose*.yml 2>/dev/null | head -3 || true
