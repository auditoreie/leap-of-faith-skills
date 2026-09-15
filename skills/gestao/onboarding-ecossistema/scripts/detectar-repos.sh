#!/usr/bin/env bash
# detectar-repos.sh — inventaria os repositórios git sob uma raiz e o harness de cada um. Só leitura.
# Uso: bash detectar-repos.sh <raiz> [profundidade=3]
# Por repo: caminho, remote, default branch (gh → origin/HEAD → ?), CLAUDE.md (repo ou pai), ADRs, PR template,
# package manager, scripts de teste, schema.prisma. Saída em linhas "campo=valor" agrupadas por repo.
set -uo pipefail
raiz="$(cd "${1:-.}" 2>/dev/null && pwd)" || { echo "raiz inválida" >&2; exit 3; }
depth="${2:-3}"
gh_ok=nao; command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && gh_ok=sim
echo "== raiz: $raiz · gh: $gh_ok"
find "$raiz" -maxdepth "$depth" -name .git \( -type d -o -type f \) -not -path '*/node_modules/*' -not -path '*/.claude/*' 2>/dev/null | sort | while IFS= read -r g; do
  repo="$(dirname "$g")"; rel="${repo#$raiz/}"
  url="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"; slug="$(printf '%s' "$url" | sed -E 's#.*github\.com[:/]##; s#\.git$##')"
  def=""; [[ "$gh_ok" == sim && -n "$slug" && "$url" == *github.com* ]] && def="$(gh repo view "$slug" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || true)"
  [[ -z "$def" ]] && def="$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  claude=""; for c in "$repo/CLAUDE.md" "$(dirname "$repo")/CLAUDE.md" "$repo/AGENTS.md"; do [[ -f "$c" ]] && { claude="${c#$raiz/}"; break; }; done
  adr="$(find "$repo" -maxdepth 3 -type d \( -name adr -o -name decisions -o -name adrs \) -path '*docs*' -not -path '*/node_modules/*' 2>/dev/null | head -1)"; adr="${adr#$repo/}"
  prt="$(find "$repo/.github" -maxdepth 1 -iname 'pull_request_template*' 2>/dev/null | head -1)"; prt="${prt#$repo/}"
  pm="?"; [[ -f "$repo/bun.lockb" || -f "$repo/bun.lock" ]] && pm=bun; [[ -f "$repo/pnpm-lock.yaml" ]] && pm=pnpm; [[ -f "$repo/package-lock.json" ]] && pm=npm; [[ -f "$repo/yarn.lock" ]] && pm=yarn
  tests="$(python3 - "$repo" <<'PY' 2>/dev/null
import json, sys, glob, os
r = sys.argv[1]; out = []
for pj in [r + '/package.json'] + glob.glob(r + '/apps/*/package.json') + glob.glob(r + '/packages/*/package.json'):
    try: s = json.load(open(pj)).get('scripts', {})
    except Exception: continue
    ks = [k for k in s if k.startswith('test')]
    if ks: out.append(os.path.relpath(os.path.dirname(pj), r) + ':' + ','.join(ks[:4]))
print(' | '.join(out))
PY
)"
  prisma="$(find "$repo" -maxdepth 6 -name schema.prisma -not -path '*/node_modules/*' -not -path '*/.claude/*' 2>/dev/null | head -1)"; prisma="${prisma#$repo/}"
  echo ""; echo "repo=$rel"; echo "  remote=${slug:-$url}"; echo "  default_branch=${def:-?}"; echo "  claude_md=${claude:-nenhum}"
  echo "  adrs=${adr:-nenhum}"; echo "  pr_template=${prt:-nenhum}"; echo "  pm=$pm"; echo "  testes=${tests:-nenhum}"; echo "  prisma=${prisma:-nenhum}"
done
