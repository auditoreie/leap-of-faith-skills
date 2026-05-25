#!/usr/bin/env bash
# install.sh — symlinka cada skill deste repo para ~/.claude/skills/
# Idempotente: re-execução não quebra nada. Confirma antes de sobrescrever conflitos.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DEST="$HOME/.claude/skills"

if [[ ! -d "$SKILLS_SRC" ]]; then
  echo "Error: $SKILLS_SRC não existe. Estrutura do repo está incompleta." >&2
  exit 1
fi

mkdir -p "$SKILLS_DEST"

created=0
skipped=0
relinked=0

for skill_dir in "$SKILLS_SRC"/*/; do
  [[ -d "$skill_dir" ]] || continue
  name="$(basename "$skill_dir")"
  target="$SKILLS_DEST/$name"
  source="$skill_dir"

  if [[ -L "$target" ]]; then
    current="$(readlink "$target")"
    if [[ "$current" == "${source%/}" ]]; then
      skipped=$((skipped + 1))
      continue
    fi
    echo "Symlink existente para $name aponta para: $current"
    read -r -p "  Substituir por $source? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      rm "$target"
      ln -s "${source%/}" "$target"
      relinked=$((relinked + 1))
    else
      skipped=$((skipped + 1))
    fi
  elif [[ -e "$target" ]]; then
    echo "Arquivo/diretório real existe em $target — pulando (não sobrescrevemos cópia local)."
    skipped=$((skipped + 1))
  else
    ln -s "${source%/}" "$target"
    created=$((created + 1))
  fi
done

echo ""
echo "Resumo: $created criado(s), $relinked re-linkado(s), $skipped pulado(s)."
echo "Skills em $SKILLS_DEST:"
ls -1 "$SKILLS_DEST" | sed 's/^/  - /'
