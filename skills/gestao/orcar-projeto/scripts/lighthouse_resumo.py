"""Resume data/lighthouse/*.json: mediana das execuções por rótulo.

Uso: python3 -I lighthouse_resumo.py  (a partir da raiz do projeto; imprime tabela Markdown)
"""

import json
import re
import statistics
from collections import defaultdict
from pathlib import Path

ROOT = Path.cwd()
DIR = ROOT / "data" / "lighthouse"

METRICAS = [
    ("first-contentful-paint", "FCP s", 1000),
    ("largest-contentful-paint", "LCP s", 1000),
    ("total-blocking-time", "TBT ms", 1),
    ("cumulative-layout-shift", "CLS", None),
    ("speed-index", "SI s", 1000),
]


def main():
    grupos = defaultdict(list)
    for f in sorted(DIR.glob("*.json")):
        m = re.match(r"(.+)-(\d+)\.json$", f.name)
        if not m:
            continue
        d = json.loads(f.read_text())
        if d.get("runtimeError"):
            continue
        grupos[m.group(1)].append(d)

    print("| Página | URL | Exec. | Perf. | SEO | Acess. | Boas práticas | " + " | ".join(m[1] for m in METRICAS) + " | Peso total KB | Requisições |")
    print("|" + "---|" * (8 + len(METRICAS) + 1))
    for rotulo, runs in grupos.items():
        def med(fn):
            vals = [v for v in (fn(r) for r in runs) if v is not None]
            return statistics.median(vals) if vals else None

        cat = lambda k: med(lambda r: (r["categories"].get(k) or {}).get("score"))
        linha = [rotulo, runs[0]["finalDisplayedUrl"], str(len(runs))]
        for k in ("performance", "seo", "accessibility", "best-practices"):
            v = cat(k)
            linha.append("" if v is None else f"{v * 100:.0f}")
        for aid, _, div in METRICAS:
            v = med(lambda r: r["audits"][aid].get("numericValue"))
            linha.append("" if v is None else (f"{v:.3f}" if div is None else f"{v / div:.1f}" if div > 1 else f"{v:.0f}"))
        peso = med(lambda r: r["audits"]["total-byte-weight"].get("numericValue"))
        reqs = med(lambda r: len(r["audits"]["network-requests"]["details"]["items"]))
        linha.append(f"{peso / 1024:.0f}" if peso else "")
        linha.append(f"{reqs:.0f}" if reqs else "")
        print("| " + " | ".join(linha) + " |")


if __name__ == "__main__":
    main()
