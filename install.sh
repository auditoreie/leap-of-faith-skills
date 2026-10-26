#!/usr/bin/env bash
# install.sh — symlinka cada skill deste repo para ~/.claude/skills/
# Suporta estrutura aninhada por ferramenta (skills/<tool>/<skill>/SKILL.md) e
# skills na raiz (skills/<skill>/SKILL.md). O nome do symlink é o basename da
# pasta da skill (precisa ser único entre todas as skills do repo).
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
seen=" "  # lista de nomes já vistos (compatível com bash 3.2, sem arrays assoc.)

# Cada diretório que contém um SKILL.md é uma skill (em qualquer profundidade).
# fd 3 para a lista de skills: o `read` do prompt de conflito usa o stdin de verdade,
# não a próxima linha do find (bug que pulava a skill seguinte a cada conflito).
while IFS= read -r -u 3 skillmd; do
  skill_dir="$(cd "$(dirname "$skillmd")" && pwd)"
  name="$(basename "$skill_dir")"
  target="$SKILLS_DEST/$name"

  if [[ "$seen" == *" $name "* ]]; then
    echo "Conflito de nome: '$name' aparece em mais de uma skill. Pulando a duplicata: $skill_dir" >&2
    skipped=$((skipped + 1))
    continue
  fi
  seen="$seen$name "

  if [[ -L "$target" ]]; then
    current="$(readlink "$target")"
    if [[ "$current" == "$skill_dir" ]]; then
      skipped=$((skipped + 1))
      continue
    fi
    echo "Symlink existente para $name aponta para: $current"
    read -r -p "  Substituir por $skill_dir? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      rm "$target"
      ln -s "$skill_dir" "$target"
      relinked=$((relinked + 1))
    else
      skipped=$((skipped + 1))
    fi
  elif [[ -e "$target" ]]; then
    echo "Arquivo/diretório real existe em $target — pulando (não sobrescrevemos cópia local)."
    skipped=$((skipped + 1))
  else
    ln -s "$skill_dir" "$target"
    created=$((created + 1))
  fi
done 3< <(find "$SKILLS_SRC" -name SKILL.md -type f | sort)

# Gate de validação: todo commit neste repo passa pelo scan antes de entrar.
if [[ -d "$REPO_DIR/.git" && -d "$REPO_DIR/.githooks" ]]; then
  chmod +x "$REPO_DIR/.githooks/pre-commit" 2>/dev/null || true
  if git -C "$REPO_DIR" config core.hooksPath .githooks; then
    echo "Hook de validação ativado (core.hooksPath = .githooks)."
  else
    echo "Aviso: não consegui configurar core.hooksPath — rode o scan manualmente antes do commit." >&2
  fi
fi

echo ""
echo "Resumo: $created criado(s), $relinked re-linkado(s), $skipped pulado(s)."
echo "Primeira vez numa pasta de cliente? Abra o Claude nela e rode /onboarding-ecossistema (gera <raiz>/.claude/ecossistema.json, fora de repo público)."
echo "Skills em $SKILLS_DEST:"
ls -1 "$SKILLS_DEST" | sed 's/^/  - /'
