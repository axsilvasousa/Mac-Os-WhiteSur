#!/usr/bin/env bash
#
# WhiteSur Custom — aplica o tema macOS na dock nativa do Zorin OS.
#
# Copyright (c) 2026 WhiteSur Custom contributors — MIT License.
# Veja o arquivo LICENSE nesta pasta.
#
# A dock nativa do Zorin é a extensão "Zorin Dash" (um fork do dash-to-dock),
# instalada em:
#
#     /usr/share/gnome-shell/extensions/zorin-dash@zorinos.com
#
# Este script:
#   1. faz backup do stylesheet.css e do extension.js originais;
#   2. acrescenta o tema macOS (dock-theme/stylesheet.css) no stylesheet.css;
#   3. instala o módulo de magnificação (dock-theme/whitesur-magnification.js)
#      dentro da extensão e conecta-o no extension.js;
#   4. ajusta as preferências nativas da dock (animações e indicadores).
#
# Tudo pode ser desfeito com: ./dock-theme/restore.sh
#
set -eo pipefail

DOCK_THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSS_SOURCE="${DOCK_THEME_DIR}/stylesheet.css"
JS_SOURCE="${DOCK_THEME_DIR}/whitesur-magnification.js"

BACKUP_ROOT="${HOME}/.local/share/whitesur-custom/backups/dock"

CSS_BEGIN="/* >>> WhiteSur Custom Dock Theme >>> */"
CSS_END="/* <<< WhiteSur Custom Dock Theme <<< */"
JS_BEGIN="// >>> WhiteSur Custom Dock Magnification >>>"
JS_END="// <<< WhiteSur Custom Dock Magnification <<<"
JS_MODULE_NAME="whitesur-magnification.js"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m    %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*"; }

# --------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------

# Executa um comando que escreve em arquivo do sistema (usa sudo se preciso).
run_write() {
  local target="$1"; shift

  if [[ -e "${target}" && -w "${target}" ]]; then
    "$@"
  elif [[ -w "$(dirname "${target}")" ]]; then
    "$@"
  elif command -v sudo > /dev/null; then
    sudo "$@"
  else
    warn "Sem permissão para escrever em ${target} (e sem sudo)."
    return 1
  fi
}

# Copia um arquivo do sistema para a home do usuário (preserva o dono original).
backup_file() {
  local source="$1" dest="$2"

  if [[ -w "${source}" ]]; then
    cp -f "${source}" "${dest}"
  else
    sudo cat "${source}" > "${dest}"
  fi
}

# Remove um bloco delimitado por marcadores de um arquivo.
strip_block() {
  local file="$1" begin="$2" end="$3"

  awk -v b="${begin}" -v e="${end}" '
    index($0, b) { skip = 1; next }
    index($0, e) { skip = 0; next }
    skip != 1 { print }
  ' "${file}"
}

# Garante que o arquivo termine com quebra de linha (para o bloco ser
# acrescentado sem "grudar" na última linha).
ensure_trailing_newline() {
  local file="$1"

  if [[ -s "${file}" ]] && [[ -n "$(tail -c 1 "${file}")" ]]; then
    printf '\n' >> "${file}"
  fi
}

# --------------------------------------------------------------------------
# Detecção
# --------------------------------------------------------------------------

# Descobre a pasta da extensão da dock nativa do Zorin.
detect_extension_dir() {
  local candidates=(
    "${HOME}/.local/share/gnome-shell/extensions/zorin-dash@zorinos.com"
    "/usr/share/gnome-shell/extensions/zorin-dash@zorinos.com"
    "${HOME}/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com"
    "/usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com"
    "${HOME}/.local/share/gnome-shell/extensions/ubuntu-dock@ubuntu.com"
    "/usr/share/gnome-shell/extensions/ubuntu-dock@ubuntu.com"
  )
  local dir

  for dir in "${candidates[@]}"; do
    if [[ -d "${dir}" ]] && [[ -f "${dir}/extension.js" ]]; then
      echo "${dir}"
      return 0
    fi
  done

  # Fallback: qualquer extensão da dock instalada no sistema.
  for base in "${HOME}/.local/share/gnome-shell/extensions" "/usr/share/gnome-shell/extensions"; do
    [[ -d "${base}" ]] || continue

    for dir in "${base}"/*dash*; do
      [[ -d "${dir}" ]] || continue
      [[ -f "${dir}/extension.js" ]] || continue
      echo "${dir}"
      return 0
    done
  done

  return 1
}

# Descobre o schema gsettings da dock (Zorin Dash usa o seu próprio schema).
detect_schema() {
  local ext_dir="$1"
  local schemas=""

  command -v gsettings > /dev/null || return 1

  schemas="$(gsettings list-schemas 2>/dev/null || true)"

  if [[ -z "${schemas}" && -d "${ext_dir}/schemas" ]]; then
    schemas="$(gsettings --schemadir "${ext_dir}/schemas" list-schemas 2>/dev/null || true)"
  fi

  local schema
  for schema in \
    "org.gnome.shell.extensions.zorin-dash" \
    "org.gnome.shell.extensions.dash-to-dock" \
    "org.gnome.shell.extensions.ubuntu-dock"; do
    if echo "${schemas}" | grep -qxF "${schema}"; then
      echo "${schema}"
      return 0
    fi
  done

  schema="$(echo "${schemas}" | grep -E '^org\.gnome\.shell\.extensions\..*dash.*$' | head -n1)"

  if [[ -n "${schema}" ]]; then
    echo "${schema}"
    return 0
  fi

  return 1
}

schema_has_key() {
  local schema="$1" key="$2"

  gsettings list-keys "${schema}" 2>/dev/null | grep -qxF "${key}"
}

# Descobre o nome da classe exportada pela extensão ("export default class X").
# Palavras reservadas (como "extends", no caso de classe anônima) são
# descartadas para cair no método alternativo de patch.
detect_class_name() {
  local target="$1"
  local name

  name="$(grep -oE 'export default class [A-Za-z_$][A-Za-z0-9_$]*' "${target}" | head -n1 | awk '{print $4}')"

  case "${name}" in
    ''|extends|implements|default|await|yield|static|get|set|null|true|false)
      echo ""
      ;;
    *)
      echo "${name}"
      ;;
  esac
}

# --------------------------------------------------------------------------
# Aplicação
# --------------------------------------------------------------------------

apply_css() {
  local ext_dir="$1" backup_dir="$2"
  local target="${ext_dir}/stylesheet.css"
  local tmp

  if [[ ! -f "${target}" ]]; then
    warn "stylesheet.css não encontrado em ${ext_dir} — o visual não foi aplicado."
    return 0
  fi

  if [[ ! -f "${backup_dir}/stylesheet.css.orig" ]]; then
    backup_file "${target}" "${backup_dir}/stylesheet.css.orig"
    ok "Backup do stylesheet original: ${backup_dir}/stylesheet.css.orig"
  fi

  tmp="$(mktemp)"
  strip_block "${target}" "${CSS_BEGIN}" "${CSS_END}" > "${tmp}"
  ensure_trailing_newline "${tmp}"
  {
    echo "${CSS_BEGIN}"
    cat "${CSS_SOURCE}"
    echo "${CSS_END}"
  } >> "${tmp}"

  run_write "${target}" cp -f "${tmp}" "${target}" || {
    warn "Não foi possível escrever em ${target}."
    rm -f "${tmp}"
    return 1
  }
  rm -f "${tmp}"

  ok "Tema macOS aplicado em ${target}"
}

apply_js() {
  local ext_dir="$1" backup_dir="$2"
  local target="${ext_dir}/extension.js"
  local module="${ext_dir}/${JS_MODULE_NAME}"
  local tmp class_name

  if [[ ! -f "${target}" ]]; then
    warn "extension.js não encontrado — a magnificação não será aplicada."
    return 0
  fi

  if ! command -v perl > /dev/null; then
    warn "perl não encontrado — a magnificação será pulada (o tema continua valendo)."
    return 0
  fi

  if [[ ! -f "${backup_dir}/extension.js.orig" ]]; then
    backup_file "${target}" "${backup_dir}/extension.js.orig"
    ok "Backup do extension.js original: ${backup_dir}/extension.js.orig"
  fi

  tmp="$(mktemp)"
  cat "${JS_SOURCE}" > "${tmp}"
  run_write "${module}" cp -f "${tmp}" "${module}"
  rm -f "${tmp}"

  class_name="$(detect_class_name "${target}")"

  tmp="$(mktemp)"
  strip_block "${target}" "${JS_BEGIN}" "${JS_END}" > "${tmp}"
  ensure_trailing_newline "${tmp}"

  if [[ -n "${class_name}" ]]; then
    cat >> "${tmp}" <<EOF
${JS_BEGIN}
import {WhitesurMagnification} from './${JS_MODULE_NAME}';

const __whitesurOriginalEnable = ${class_name}.prototype.enable;
const __whitesurOriginalDisable = ${class_name}.prototype.disable;

${class_name}.prototype.enable = function (...args) {
    const result = __whitesurOriginalEnable.apply(this, args);
    this._whitesurMagnification = WhitesurMagnification.enable();
    return result;
};

${class_name}.prototype.disable = function (...args) {
    if (this._whitesurMagnification) {
        this._whitesurMagnification.disable();
        this._whitesurMagnification = null;
    }
    return __whitesurOriginalDisable.apply(this, args);
};
${JS_END}
EOF
  else
    # Sem classe identificável o patch entra dentro dos métodos, então o
    # arquivo é sempre reconstruído a partir do original (sem marcadores).
    warn "Classe da extensão não identificada — usando o método alternativo."
    cp "${backup_dir}/extension.js.orig" "${tmp}"
    perl -0pi -e 's/(\benable\s*\(\s*\)\s*\{)/$1\n        this._whitesurMagnification = WhitesurMagnification.enable();/' "${tmp}"
    perl -0pi -e 's/(\bdisable\s*\(\s*\)\s*\{)/$1\n        if (this._whitesurMagnification) { this._whitesurMagnification.disable(); this._whitesurMagnification = null; }/' "${tmp}"
    perl -0pi -e "s|\A|import {WhitesurMagnification} from './${JS_MODULE_NAME}';\n|" "${tmp}"
  fi

  # Confere se o patch entrou de fato; se não, o arquivo original é mantido.
  if ! grep -qF "WhitesurMagnification.enable()" "${tmp}"; then
    warn "O patch da magnificação não pôde ser aplicado — a extensão ficou intacta."
    rm -f "${tmp}"
    return 0
  fi

  # Conferência de sintaxe, quando o node está disponível.
  if command -v node > /dev/null; then
    local check_file="${tmp}.mjs"
    cp "${tmp}" "${check_file}"

    if ! node --check "${check_file}" > /dev/null 2>&1; then
      warn "A extensão gerada tem erro de sintaxe — o arquivo original foi mantido."
      rm -f "${check_file}" "${tmp}"
      return 0
    fi

    rm -f "${check_file}"
  fi

  run_write "${target}" cp -f "${tmp}" "${target}" || {
    warn "Não foi possível escrever em ${target}."
    rm -f "${tmp}"
    return 1
  }
  rm -f "${tmp}"

  ok "Magnificação (zoom no hover) aplicada em ${target}"
}

save_old_value() {
  local schema="$1" key="$2" backup_dir="$3"
  local file="${backup_dir}/gsettings.txt"
  local current

  if [[ -f "${file}" ]] && grep -qF "${schema}|${key}|" "${file}"; then
    return 0
  fi

  current="$(gsettings get "${schema}" "${key}" 2>/dev/null || echo '')"
  printf '%s|%s|%s\n' "${schema}" "${key}" "${current}" >> "${file}"
}

set_setting() {
  local schema="$1" key="$2" value="$3" backup_dir="$4"

  if ! schema_has_key "${schema}" "${key}"; then
    return 0
  fi

  save_old_value "${schema}" "${key}" "${backup_dir}"

  if gsettings set "${schema}" "${key}" "${value}" 2>/dev/null; then
    ok "${key} = ${value}"
  else
    warn "Não foi possível alterar ${key}."
  fi
}

apply_settings() {
  local schema="$1" backup_dir="$2"
  local key value

  while IFS='|' read -r key value; do
    [[ -z "${key}" ]] && continue
    set_setting "${schema}" "${key}" "${value}" "${backup_dir}" < /dev/null
  done <<'EOF'
apply-custom-theme|true
custom-theme-shrink|false
running-indicator-style|'DOTS'
custom-theme-customize-running-dots|true
custom-theme-running-dots|true
custom-theme-running-dots-color|'#ffffff'
custom-theme-running-dots-border-width|0
animation-time|0.25
EOF
}

# --------------------------------------------------------------------------
# MAIN
# --------------------------------------------------------------------------

log "Procurando a dock nativa do Zorin OS"

EXT_DIR="$(detect_extension_dir)" || {
  warn "Nenhuma dock nativa (Zorin Dash / dash-to-dock) encontrada."
  warn "O tema da dock não foi aplicado — o resto do pacote continua funcionando."
  exit 0
}

ok "Dock nativa: ${EXT_DIR}"

BACKUP_DIR="${BACKUP_ROOT}/$(basename "${EXT_DIR}")"
mkdir -p "${BACKUP_DIR}"

{
  echo "ext_dir=${EXT_DIR}"
  echo "date=$(date '+%Y-%m-%d %H:%M:%S')"
} > "${BACKUP_DIR}/manifest.txt"

log "Aplicando o tema macOS"
apply_css "${EXT_DIR}" "${BACKUP_DIR}"
apply_js "${EXT_DIR}" "${BACKUP_DIR}"

log "Ajustando as animações nativas da dock"
if SCHEMA="$(detect_schema "${EXT_DIR}")"; then
  ok "Schema: ${SCHEMA}"
  apply_settings "${SCHEMA}" "${BACKUP_DIR}"
else
  warn "Schema gsettings da dock não encontrado — apenas o visual foi aplicado."
fi

ok "Backup do estado anterior: ${BACKUP_DIR}"
ok "Para desfazer: ./dock-theme/restore.sh"
