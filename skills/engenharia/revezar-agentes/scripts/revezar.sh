#!/usr/bin/env bash
# revezar — abre um agente na conta escolhida, na mesma linha de trabalho do ai-memory, sem você
# digitar variável de ambiente. Instale uma vez:
#   ln -s <skill>/scripts/revezar.sh ~/.local/bin/revezar
#
#   revezar                          menu: conta → linha de trabalho → abre
#   revezar <agente> <conta> [linha] direto, sem menu (ex.: revezar codex default HMAXX-1-x)
#   revezar status                   contas e estado de login
#   revezar login <agente> <conta>   cria a pasta da conta e abre o login do CLI
#   REVEZAR_DRY=1 revezar …          só mostra o comando, sem abrir
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
DIR="$(cd "$(dirname "$SELF")" && pwd)"

die() { echo "revezar: $*" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }

# Escolhe uma linha da entrada padrão: fzf quando houver, senão menu numerado.
pick() {
  local prompt="$1"
  if has fzf; then
    fzf --prompt "$prompt> " --height 40% --reverse --delimiter $'\t' --with-nth 1,2,3,5
  else
    local lines=() l i=1 n
    while IFS= read -r l; do lines+=("$l"); done
    for l in "${lines[@]}"; do printf '%2d) %s\n' "$i" "$(printf '%s' "$l" | tr '\t' ' ')" >&2; i=$((i + 1)); done
    read -r -p "$prompt (número): " n </dev/tty
    [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#lines[@]}" ] || return 1
    printf '%s\n' "${lines[$((n - 1))]}"
  fi
}

harness_of() {
  case "$1" in
    claude) echo claude ;;
    codex) echo codex ;;
    grok) echo grok ;;
    cursor-agent) echo cursor ;;
    *) return 1 ;;
  esac
}

# "volta em" de cada conta, lido do registro de contas (contas/estado.md no _global).
resets() {
  ai-memory read-page --project _global --path contas/estado.md 2>/dev/null |
    awk -F'|' 'NF > 7 && $2 !~ /Agente|---/ {
      gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $3); gsub(/^ +| +$/, "", $6)
      if ($6 != "" && $6 != "—") print $2 "\t" $3 "\t" $6 }'
}

cmd_status() { bash "$DIR/contas.sh"; }

cmd_login() {
  local agente="${1:-}" conta="${2:-}"
  [ -n "$agente" ] && [ -n "$conta" ] || die "uso: revezar login <claude|codex|grok> <conta>"
  case "$agente" in
    claude) local d="${CCA_HOME:-$HOME/.claude-accounts}/$conta"; mkdir -p "$d"
            CLAUDE_CONFIG_DIR="$d" claude auth login ;;
    codex)  local d="$HOME/.codex-$conta"; [ "$conta" = default ] && d="$HOME/.codex"; mkdir -p "$d"
            CODEX_HOME="$d" codex login ;;
    grok)   local d="$HOME/.grok-$conta"; [ "$conta" = default ] && d="$HOME/.grok"; mkdir -p "$d"
            GROK_HOME="$d" grok login ;;
    cursor-agent) die "cursor-agent tem uma conta por máquina: use 'cursor-agent login'" ;;
    *) die "agente desconhecido: $agente" ;;
  esac
}

cmd_open() {
  has ai-memory || die "ai-memory não instalado"
  local contas sel agente conta env estado
  contas="$(bash "$DIR/contas.sh" --tsv | awk -F'\t' '$2 != "-"')"
  [ -n "$contas" ] || die "nenhuma conta encontrada (rode: revezar status)"

  if [ -n "${1:-}" ] && [ -n "${2:-}" ]; then
    sel="$(printf '%s\n' "$contas" | awk -F'\t' -v a="$1" -v c="$2" '$1 == a && $2 == c' | head -1)"
    [ -n "$sel" ] || die "conta não encontrada: $1 $2 (rode: revezar status)"
    shift 2
  else
    local r; r="$(resets)"
    sel="$(printf '%s\n' "$contas" | while IFS=$'\t' read -r a c s e; do
      v="$(printf '%s\n' "$r" | awk -F'\t' -v a="$a" -v c="$c" '$1 == a && $2 == c {print "volta em " $3}')"
      printf '%s\t%s\t%s\t%s\t%s\n' "$a" "$c" "$s" "$e" "$v"
    done | pick "conta")" || die "nada escolhido"
  fi
  IFS=$'\t' read -r agente conta estado env _ <<<"$sel"
  [ "$estado" = deslogada ] && die "$agente/$conta está deslogada: revezar login $agente $conta"

  local ws="${1:-}" existentes novo=0
  existentes="$(ai-memory workstreams --json 2>/dev/null |
    python3 -c 'import json,sys; [print(w["name"]) for w in json.load(sys.stdin)]' 2>/dev/null || true)"
  if [ -n "$ws" ]; then
    printf '%s\n' "$existentes" | grep -qxF -- "$ws" || novo=1
  else
    ws="$( { printf '%s\n' "$existentes" | awk 'NF {print $0 "\t\t\t\texistente"}'; printf '+ nova linha de trabalho\t\t\t\t\n'; } | pick "linha" | cut -f1)" || die "nada escolhido"
    if [ "$ws" = "+ nova linha de trabalho" ]; then
      read -r -p "nome da linha (<TASKID>-<slug>): " ws </dev/tty
      [ -n "$ws" ] || die "nome vazio"
      novo=1
    fi
  fi

  local h; h="$(harness_of "$agente")" || die "sem harness para $agente"
  local args=(run --env "REVEZAR_CONTA=$agente/$conta")
  [ -n "$env" ] && args+=(--env "$env")
  if [ "$novo" = 1 ]; then args+=(--new "$ws"); else args+=(--workstream "$ws"); fi
  args+=("$h")
  if ai-memory read-page --path "bastoes/$ws.md" >/dev/null 2>&1; then
    local proj; proj="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    args+=("Leia o bastão com: ai-memory read-page --path bastoes/$ws.md (rodado em $proj, que define workspace e projeto). Siga do 'Próximo passo exato'; não reabra as decisões do dono.")
  fi

  echo "revezar: $agente/$conta → linha '$ws'" >&2
  if [ "${REVEZAR_DRY:-0}" = 1 ]; then printf '%q ' ai-memory "${args[@]}"; echo; exit 0; fi
  exec ai-memory "${args[@]}"
}

case "${1:-}" in
  -h|--help) sed -n '2,10p' "$SELF" | sed 's/^# \{0,1\}//' ;;
  status) cmd_status ;;
  login) shift; cmd_login "$@" ;;
  *) cmd_open "$@" ;;
esac
