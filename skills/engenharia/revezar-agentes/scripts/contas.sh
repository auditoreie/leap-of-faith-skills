#!/usr/bin/env bash
# Lista, por CLI, as contas instaladas e se estão logadas. Só leitura: não faz login,
# não gasta cota (não chama modelo) e não imprime token.
#   contas.sh         tabela para humanos
#   contas.sh --tsv   agente<TAB>conta<TAB>estado<TAB>VAR=pasta (usado pelo revezar.sh)
set -uo pipefail

TSV=0
[ "${1:-}" = "--tsv" ] && TSV=1

line() {
  if [ "$TSV" = 1 ]; then printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${4:-}"
  else printf '%-13s %-22s %s\n' "$1" "$2" "$3"; fi
}
has() { command -v "$1" >/dev/null 2>&1; }

[ "$TSV" = 1 ] || line "AGENTE" "CONTA" "ESTADO"

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
    line "claude" "$name" "$state" "CLAUDE_CONFIG_DIR=$dir"
  done
else
  line "claude" "-" "não instalado"
fi

if has codex; then
  for dir in "$HOME/.codex" "$HOME"/.codex-*; do
    [ -d "$dir" ] || continue
    name="$([ "$dir" = "$HOME/.codex" ] && echo default || basename "$dir" | sed 's/^\.codex-//')"
    # O código de saída decide (login por ChatGPT ou por chave de API imprimem textos diferentes).
    if CODEX_HOME="$dir" codex login status >/dev/null 2>&1; then
      state="logada"
    else
      state="deslogada"
    fi
    line "codex" "$name" "$state" "CODEX_HOME=$dir"
  done
else
  line "codex" "-" "não instalado"
fi

if has grok; then
  found=0
  for dir in "${GROK_HOME:-}" "$HOME/.grok" "$HOME"/.grok-*; do
    [ -n "$dir" ] && [ -d "$dir" ] || continue
    case " ${seen_grok:-} " in *" $dir "*) continue ;; esac
    seen_grok="${seen_grok:-} $dir"
    found=1
    if [ "$dir" = "$HOME/.grok" ]; then name=default
    elif [ "$dir" = "${GROK_HOME:-}" ]; then name="$(basename "$dir" | sed 's/^\.grok-//') (GROK_HOME)"
    else name="$(basename "$dir" | sed 's/^\.grok-//')"; fi
    line "grok" "$name" "instalado (login não verificável sem chamar o modelo)" "GROK_HOME=$dir"
  done
  [ "$found" = 1 ] || line "grok" "-" "instalado, sem pasta de conta (login não verificado)"
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

if [ "$TSV" = 0 ]; then
  if has ai-memory; then
    if ai-memory status >/dev/null 2>&1; then
      line "ai-memory" "-" "servidor ok"
    else
      line "ai-memory" "-" "servidor fora do ar (revezamento sem linha de trabalho)"
    fi
  else
    line "ai-memory" "-" "não instalado"
  fi
fi
