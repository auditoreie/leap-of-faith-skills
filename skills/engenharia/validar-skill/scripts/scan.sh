#!/usr/bin/env bash
# scan.sh — varredura de bloqueantes antes de publicar uma skill.
#
# Uso:
#   ./scan.sh                 # audita o diff contra a main
#   ./scan.sh caminho [...]   # audita caminhos específicos (arquivo ou diretório)
#
# Exit codes: 0 = limpo (pode ter ressalvas) · 1 = bloqueio encontrado · 3 = erro de uso.
#
# NUNCA imprime o valor de um segredo — só arquivo, linha, tipo e um prefixo de 4 chars.
# Compatível com bash 3.2 (macOS) e com o grep BSD/GNU (só ERE, sem -P).

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SELF_DIR="skills/engenharia/validar-skill"

blocks=0
warns=0
skipped_self=0

red()  { printf '\033[31m%s\033[0m\n' "$1"; }
yell() { printf '\033[33m%s\033[0m\n' "$1"; }
grn()  { printf '\033[32m%s\033[0m\n' "$1"; }

block() { red   "  ⛔ $1"; blocks=$((blocks + 1)); }
warn()  { yell  "  ⚠️  $1"; warns=$((warns + 1)); }

# --- alvo -------------------------------------------------------------------

cd "$REPO_DIR" || exit 3

files=""
if [[ $# -gt 0 ]]; then
  for p in "$@"; do
    if [[ -d "$p" ]]; then
      files="$files$(find "$p" -type f -not -path '*/.git/*')"$'\n'
    elif [[ -f "$p" ]]; then
      files="$files$p"$'\n'
    else
      echo "Caminho inexistente: $p" >&2
      exit 3
    fi
  done
else
  base="main"
  git rev-parse --verify "$base" >/dev/null 2>&1 || base="master"
  files="$(git diff --name-only "$base...HEAD" 2>/dev/null; git diff --name-only; git ls-files --others --exclude-standard)"
fi

# normaliza: únicos, existentes, fora do .git
files="$(printf '%s\n' "$files" | sed '/^$/d' | sort -u | while IFS= read -r f; do [[ -f "$f" ]] && printf '%s\n' "$f"; done)"

if [[ -z "$files" ]]; then
  grn "Nada a validar (sem diff contra a main e sem caminhos informados)."
  exit 0
fi

n_files="$(printf '%s\n' "$files" | wc -l | tr -d ' ')"
echo "🔎 scan.sh — $n_files arquivo(s)"
echo ""

# --- 1. nomes de arquivo proibidos -----------------------------------------

FORBIDDEN_NAMES='(^|/)(\.env($|\..*)|\.envrc|.*\.pem$|.*\.key$|.*\.p12$|.*\.pfx$|.*\.jks$|.*\.keystore$|id_rsa.*|id_dsa.*|id_ecdsa.*|id_ed25519.*|credentials(\.json)?$|service-account.*\.json$|\.npmrc$|\.pypirc$|\.netrc$|plane_config\.json$|ecossistema\.json$|gcp-servicos\.md$|.*\.sqlite3?$|.*\.dump$|.*\.bak$)'

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if printf '%s' "$f" | grep -qE -- "$FORBIDDEN_NAMES"; then
    block "$f — arquivo proibido no repositório (credencial/estado local). Remova e adicione ao .gitignore."
  fi
done <<< "$files"

# --- 2. binários e arquivos pesados ----------------------------------------

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  size=$(wc -c < "$f" | tr -d ' ')
  if [[ "$size" -gt 1048576 ]]; then
    block "$f — $((size / 1024)) KB (> 1 MB). Skill é texto; anexo pesado não entra."
  fi
  if ! grep -Iq . "$f" 2>/dev/null; then
    block "$f — arquivo binário. Só texto versionado aqui."
  fi
done <<< "$files"

# --- 3. credenciais no conteúdo (alta confiança = bloqueio) ----------------

# Formato: <rótulo>|<regex ERE>
CRED_PATTERNS='
Chave da API Anthropic|sk-ant-[A-Za-z0-9_-]{20,}
Chave da API OpenAI|sk-(proj-)?[A-Za-z0-9_-]{32,}
Token do GitHub|gh[pousr]_[A-Za-z0-9]{36,}
Token do GitHub (fine-grained)|github_pat_[A-Za-z0-9_]{50,}
AWS Access Key ID|(AKIA|ASIA)[0-9A-Z]{16}
AWS Secret Access Key|aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9/+=]{40}
Token do Slack|xox[baprs]-[A-Za-z0-9-]{10,}
Chave da API Google|AIza[0-9A-Za-z_-]{35}
Chave secreta Stripe (live)|(sk|rk)_live_[0-9a-zA-Z]{24,}
Token de acesso Meta/Graph|EAA[A-Za-z0-9]{80,}
Chave da API Plane|plane_api_[A-Za-z0-9]{20,}
Chave privada (bloco PEM)|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----
JSON Web Token|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}
Senha embutida em URL|[a-z][a-z0-9+.-]*://[^/[:space:]:@]+:[^/[:space:]:@]{4,}@
'

# Ressalvas: padrões genéricos, alta taxa de falso positivo → não bloqueiam.
SUSPECT_PATTERNS='
Atribuição de segredo em literal|(password|passwd|secret|api_?key|access_token|client_secret)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{12,}["'"'"']
CPF|[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2}
CNPJ|[0-9]{2}\.[0-9]{3}\.[0-9]{3}/[0-9]{4}-[0-9]{2}
Possível número de cartão|(4[0-9]{3}|5[1-5][0-9]{2})[ -]?[0-9]{4}[ -]?[0-9]{4}[ -]?[0-9]{4}
Telefone com DDI|\+55[[:space:]]?[0-9]{2}[[:space:]]?9?[0-9]{4}-?[0-9]{4}
Caminho absoluto de máquina|/(Users|home)/[a-zA-Z0-9._-]+/
'

scan_file() {
  local f="$1" label regex hits line num prefix
  while IFS='|' read -r label regex; do
    [[ -z "$label" ]] && continue
    hits="$(grep -nE -- "$regex" "$f" 2>/dev/null | grep -v 'scan-ignore' || true)"
    [[ -z "$hits" ]] && continue
    while IFS= read -r hit; do
      [[ -z "$hit" ]] && continue
      num="${hit%%:*}"
      prefix="$(printf '%s' "$hit" | grep -oE -- "$regex" | head -1 | cut -c1-4)"
      if [[ "$2" == "block" ]]; then
        block "$f:$num — $label (começa com '${prefix}…')"
      else
        warn "$f:$num — $label — confirme que não é dado real"
      fi
    done <<< "$hits"
  done <<< "$3"
}

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # A própria skill define os padrões — varrer-se acusaria os próprios regexes.
  if [[ "$f" == "$SELF_DIR"/* ]]; then
    skipped_self=$((skipped_self + 1))
    continue
  fi
  grep -Iq . "$f" 2>/dev/null || continue   # binário já reportado acima
  scan_file "$f" block   "$CRED_PATTERNS"
  scan_file "$f" suspect "$SUSPECT_PATTERNS"
done <<< "$files"

# --- 4. nomes de skill duplicados ------------------------------------------

dupes="$(find skills -name SKILL.md -type f 2>/dev/null | xargs -n1 dirname 2>/dev/null | xargs -n1 basename 2>/dev/null | sort | uniq -d)"
if [[ -n "$dupes" ]]; then
  while IFS= read -r d; do
    [[ -n "$d" ]] && block "nome de skill duplicado: '$d' — o install.sh symlinka pelo basename, um dos dois não instala."
  done <<< "$dupes"
fi

# --- 5. frontmatter das SKILL.md alteradas ---------------------------------

while IFS= read -r f; do
  [[ "$(basename "$f")" == "SKILL.md" ]] || continue
  dir_name="$(basename "$(dirname "$f")")"
  head -1 "$f" | grep -q '^---$' || block "$f — frontmatter ausente (arquivo precisa começar com '---')."
  grep -qE '^name:[[:space:]]*[a-z0-9-]+[[:space:]]*$' "$f" \
    || block "$f — campo 'name' ausente ou fora do kebab-case."
  grep -qE '^description:[[:space:]]*.+' "$f" \
    || block "$f — campo 'description' ausente (é o que faz o Claude escolher a skill)."
  declared="$(grep -m1 -E '^name:' "$f" | sed 's/^name:[[:space:]]*//;s/[[:space:]]*$//')"
  if [[ -n "$declared" && "$declared" != "$dir_name" ]]; then
    block "$f — 'name: $declared' difere da pasta '$dir_name'; o symlink usa a pasta."
  fi
  lines="$(wc -l < "$f" | tr -d ' ')"
  [[ "$lines" -gt 150 ]] && warn "$f — $lines linhas (> 150). Mova detalhe pra arquivo lazy-load."
  grep -qi 'token discipline' "$f" || warn "$f — não declara 'Token discipline'."
  grep -qiE 'safe-?mode' "$f"      || warn "$f — não declara 'Safe-mode'."
done <<< "$files"

# --- 6. padrões prejudiciais -----------------------------------------------

HARMFUL='
Bypass de verificação do git|--no-verify
Bypass de permissões do Claude Code|--dangerously-skip-permissions
Remoção recursiva forçada|rm[[:space:]]+-[rRf]{2,}[[:space:]]
Push forçado|push[[:space:]]+.*--force(-with-lease)?
Reset destrutivo|reset[[:space:]]+--hard
DROP de tabela/banco|DROP[[:space:]]+(TABLE|DATABASE)
Tentativa de prompt injection|(ignore|disregard|esqueça)[[:space:]]+(all[[:space:]]+)?(previous|prior|as)[[:space:]]+(instructions|instruções)
'

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ "$f" == "$SELF_DIR"/* ]] && continue
  grep -Iq . "$f" 2>/dev/null || continue
  while IFS='|' read -r label regex; do
    [[ -z "$label" ]] && continue
    hits="$(grep -nE -- "$regex" "$f" 2>/dev/null | grep -v 'scan-ignore' || true)"
    [[ -z "$hits" ]] && continue
    while IFS= read -r hit; do
      [[ -z "$hit" ]] && continue
      warn "$f:${hit%%:*} — $label — só é aceitável com confirmação explícita do usuário no fluxo."
    done <<< "$hits"
  done <<< "$HARMFUL"
done <<< "$files"

# --- resumo -----------------------------------------------------------------

echo ""
[[ "$skipped_self" -gt 0 ]] && echo "(pulados $skipped_self arquivo(s) da própria validar-skill — são a definição dos padrões)"
echo "Resumo: $blocks bloqueio(s), $warns ressalva(s)."

if [[ "$blocks" -gt 0 ]]; then
  red "VEREDICTO: BLOQUEADO — resolva os bloqueios antes de abrir o PR."
  echo "Se algum achado for credencial real: revogue e rotacione a chave. Remover do arquivo não basta —"
  echo "o histórico do git preserva o valor commitado."
  exit 1
fi

if [[ "$warns" -gt 0 ]]; then
  yell "VEREDICTO: APROVADO COM RESSALVAS — dá pra abrir o PR, ajuste no review."
  exit 0
fi

grn "VEREDICTO: APROVADO — nenhum bloqueante encontrado."
exit 0
