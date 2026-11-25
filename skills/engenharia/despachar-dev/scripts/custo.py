#!/usr/bin/env python3
"""Soma os tokens dos subagentes por classe de despacho e por modelo.

Lê ~/.claude/projects/*/*/subagents/*.meta.json (description, agentType) e o .jsonl
ao lado (usage de cada mensagem, sem duplicar por message.id). A classe vem da tag
no começo da description: "[C2·R2] ..." ou "[C2·R2·esc] ...".

Uso: custo.py [--dias N] [--csv]
"""
import argparse
import collections
import glob
import json
import os
import re
import sys
import time

TAG = re.compile(r"^\s*\[(C[123])\s*[·.\-]\s*(R[12])(?:\s*[·.\-]\s*(esc))?\]")
CAMPOS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")


def uso(arquivo):
    vistos, soma, modelo = set(), collections.Counter(), ""
    try:
        with open(arquivo, errors="ignore") as f:
            for linha in f:
                try:
                    ev = json.loads(linha)
                except ValueError:
                    continue
                msg = ev.get("message") or {}
                if ev.get("type") != "assistant" or msg.get("id") in vistos:
                    continue
                vistos.add(msg.get("id"))
                for k in CAMPOS:
                    soma[k] += (msg.get("usage") or {}).get(k, 0)
                modelo = msg.get("model") or modelo
    except OSError:
        pass
    return soma, modelo.replace("claude-", "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dias", type=float, default=7)
    ap.add_argument("--csv", action="store_true")
    a = ap.parse_args()

    corte = time.time() - a.dias * 86400
    raiz = os.path.expanduser("~/.claude/projects")
    linhas = collections.defaultdict(lambda: [0, collections.Counter()])
    for meta_path in glob.glob(os.path.join(raiz, "*", "*", "subagents", "*.meta.json")):
        if os.path.getmtime(meta_path) < corte:
            continue
        try:
            meta = json.load(open(meta_path))
        except (OSError, ValueError):
            continue
        tipo = meta.get("agentType") or "?"
        m = TAG.match(meta.get("description") or "")
        if m:
            classe = f"{m.group(1)}·{m.group(2)}" + ("·esc" if m.group(3) else "")
        elif tipo == "general-purpose":
            classe = "fora da skill"
        else:
            classe = f"({tipo})"
        soma, modelo = uso(meta_path[: -len(".meta.json")] + ".jsonl")
        chave = (classe, modelo or meta.get("model") or "?")
        linhas[chave][0] += 1
        linhas[chave][1].update(soma)

    if not linhas:
        print(f"Nenhum subagente nos últimos {a.dias:g} dias.")
        return 0

    ordem = sorted(linhas.items(), key=lambda kv: -sum(kv[1][1].values()))
    if a.csv:
        print("classe,modelo,agentes," + ",".join(CAMPOS))
        for (classe, modelo), (n, s) in ordem:
            print(f"{classe},{modelo},{n}," + ",".join(str(s[k]) for k in CAMPOS))
        return 0

    total = sum(sum(s.values()) for _, (_, s) in ordem) or 1
    print(f"Subagentes nos últimos {a.dias:g} dias\n")
    print("| Classe | Modelo | Agentes | Tokens (M) | % | Saída (M) | Cache lido (M) |")
    print("|---|---|---:|---:|---:|---:|---:|")
    for (classe, modelo), (n, s) in ordem:
        t = sum(s.values())
        print(f"| {classe} | {modelo} | {n} | {t/1e6:.1f} | {100*t/total:.0f}% "
              f"| {s['output_tokens']/1e6:.2f} | {s['cache_read_input_tokens']/1e6:.1f} |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
