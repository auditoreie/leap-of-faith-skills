#!/usr/bin/env bash
# ecossistema.sh — localiza a config do ecossistema subindo a partir do diretório atual (ou do argumento)
# e imprime os campos que as skills usam. Só leitura. Exit 3 = não encontrado (rode /onboarding-ecossistema).
# Uso: bash ecossistema.sh [dir]
set -uo pipefail
d="$(cd "${1:-.}" 2>/dev/null && pwd)" || { echo "diretório inválido" >&2; exit 3; }
while [[ "$d" != "/" ]]; do
  if [[ -f "$d/.claude/ecossistema.json" ]]; then cfg="$d/.claude/ecossistema.json"; break; fi
  d="$(dirname "$d")"
done
if [[ -z "${cfg:-}" ]]; then
  echo "ecossistema.json não encontrado subindo a partir de ${1:-$PWD}. Rode /onboarding-ecossistema na pasta raiz do cliente, ou informe os IDs manualmente (fallback)." >&2
  exit 3
fi
python3 - "$cfg" <<'PY'
import json, sys, os
cfg = sys.argv[1]; raiz = os.path.dirname(os.path.dirname(cfg))
d = json.load(open(cfg)); t = d.get("tracker", {}); g = d.get("gcp", {})
print(f"RAIZ={raiz}"); print(f"CONFIG={cfg}"); print(f"NOME={d.get('nome','?')}")
print(f"TRACKER={t.get('tipo','?')} workspace_id={t.get('workspace_id','')} space_id={t.get('space_id','')} folder_id={t.get('folder_id','')} list_id={t.get('list_id','')}")
print(f"LISTA={t.get('list_nome','')}"); print(f"PREFIXO={t.get('prefixo_task','')} STATUS_INICIAL={t.get('status_inicial','')}")
for k, v in t.get("campos", {}).items():
    print(f"CAMPO {k}: id={v.get('id')} tipo={v.get('tipo')} opcoes={','.join(v.get('opcoes',{}).keys())}")
print(f"PRODUTOS_MD={os.path.join(raiz, d.get('produtos_md','.claude/ecossistema/produtos.md'))}")
print(f"GCP projeto={g.get('projeto','')} regiao={g.get('regiao_default','')} mapa={os.path.join(raiz, g.get('mapa','.claude/ecossistema/gcp-servicos.md')) if g else ''}")
for r in d.get("repos", []):
    c = r.get("campos", {})
    print(f"REPO {r.get('caminho')} | {r.get('nome')} | integracao={r.get('integracao','')} producao={r.get('producao','')} | produto={c.get('produto','')} escopo_deploy={c.get('escopo_deploy','')}")
pend = d.get("pendente", [])
if pend: print("PENDENTE: " + "; ".join(pend))
PY
