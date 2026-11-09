#!/usr/bin/env bash
# Lista, por CLI, as contas instaladas e se estão logadas. Só leitura: não faz login,
# não gasta cota (não chama modelo) e não imprime token.
set -uo pipefail

line() { printf '%-13s %-22s %s\n' "$1" "$2" "$3"; }
has() { command -v "$1" >/dev/null 2>&1; }

line "AGENTE" "CONTA" "ESTADO"

if has claude; then
  root="${CCA_HOME:-$HOME/.claude-accounts}"
  for dir in "$HOME/.claude" "$root"/*/; do
    [ -d "$dir" ] || continue
    dir="${dir%/}"
    name="$([ "$dir" = "$HOME/.claude" ] && echo default || basename "$dir")"
    if CLAUDE_CONFIG_DIR="$dir" claude auth status 2>/dev/null | grep -q '"loggedIn": *true'; then
      state="logada"
    else
      state="deslogada"
    fi
    line "claude" "$name" "$state"
  done
else
  line "claude" "-" "não instalado"
fi

if has codex; then
  for dir in "$HOME/.codex" "$HOME"/.codex-*; do
    [ -d "$dir" ] || continue
    name="$([ "$dir" = "$HOME/.codex" ] && echo default || basename "$dir" | sed 's/^\.codex-//')"
    if CODEX_HOME="$dir" codex login status 2>&1 | grep -qi 'logged in'; then
      state="logada"
    else
      state="deslogada"
    fi
    line "codex" "$name" "$state"
  done
else
  line "codex" "-" "não instalado"
fi

if has grok; then
  for dir in "$HOME/.grok" "$HOME"/.grok-*; do
    [ -d "$dir" ] || continue
    name="$([ "$dir" = "$HOME/.grok" ] && echo default || basename "$dir" | sed 's/^\.grok-//')"
    line "grok" "$name" "instalado (login não verificável sem chamar o modelo)"
  done
else
  line "grok" "-" "não instalado"
fi

if has cursor-agent; then
  if cursor-agent status 2>&1 | grep -qi 'logged in'; then
    line "cursor-agent" "default" "logada"
  else
    line "cursor-agent" "default" "deslogada"
  fi
else
  line "cursor-agent" "-" "não instalado"
fi

if has ai-memory; then
  if ai-memory status >/dev/null 2>&1; then
    line "ai-memory" "-" "servidor ok"
  else
    line "ai-memory" "-" "servidor fora do ar (revezamento sem linha de trabalho)"
  fi
else
  line "ai-memory" "-" "não instalado"
fi
