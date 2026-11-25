#!/usr/bin/env bash
# Vaga de teste/build compartilhada pela máquina inteira: no máximo REVEZAR_SLOTS (padrão 2)
# comandos pesados ao mesmo tempo, vindos de qualquer worker ou do orquestrador.
#   slot.sh -- <comando de teste ou build>
# Espera em foreground até abrir uma vaga, roda o comando e libera a vaga ao sair (mesmo com erro
# ou Ctrl-C, encerrando o comando junto). A vaga guarda o PID do comando e só é recuperada quando
# ele morreu. Sai com o código do comando.
set -uo pipefail

[ "${1:-}" = "--" ] && shift
[ $# -gt 0 ] || { echo "uso: slot.sh -- <comando>" >&2; exit 2; }

slots="${REVEZAR_SLOTS:-2}"
base="${REVEZAR_SLOTS_DIR:-$HOME/.cache/revezar/slots}"   # o mesmo dentro e fora do jail
mkdir -p "$base" 2>/dev/null
# Sem escrita em $base toda vaga pareceria ocupada e a espera nunca acabaria: falhe na hora.
if ! mkdir "$base/.teste.$$" 2>/dev/null; then
  echo "slot.sh: sem escrita em $base (Codex: --add-dir $base; jail: --jail-rw-map)" >&2; exit 3
fi
rmdir "$base/.teste.$$"
mine=""
waited=0

child=""
release() {
  if [ -n "$child" ] && kill -0 "$child" 2>/dev/null; then kill "$child" 2>/dev/null; wait "$child" 2>/dev/null; fi
  [ -n "$mine" ] && rm -f "$mine/pid" && rmdir "$mine"
}
trap release EXIT
trap 'exit 130' INT TERM

while [ -z "$mine" ]; do
  for i in $(seq 1 "$slots"); do
    d="$base/$i"
    if mkdir "$d" 2>/dev/null; then
      echo $$ > "$d/pid"; mine="$d"; break
    fi
    pid="$(cat "$d/pid" 2>/dev/null || true)"
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$d/pid"; rmdir "$d" 2>/dev/null   # dono morreu: vaga liberada
    fi
  done
  if [ -z "$mine" ]; then
    [ "$waited" = 0 ] && echo "slot.sh: $slots vagas ocupadas; aguardando…" >&2
    waited=1
    sleep 5
  fi
done

echo "slot.sh: vaga ${mine##*/}/$slots — $*" >&2
"$@" &
child=$!
echo "$child" > "$mine/pid"   # a vaga passa a valer enquanto o comando viver
wait "$child"
