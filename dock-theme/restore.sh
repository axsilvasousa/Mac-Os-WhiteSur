#!/usr/bin/env bash
#
# WhiteSur Custom — desfaz o tema macOS da dock nativa do Zorin OS.
#
# Copyright (c) 2026 WhiteSur Custom contributors — MIT License.
# Veja o arquivo LICENSE nesta pasta.
#
# Restaura o stylesheet.css e o extension.js originais da extensão da dock e
# devolve as preferências (gsettings) ao estado anterior.
#
# Os backups ficam em:
#
#     ~/.local/share/whitesur-custom/backups/dock/<extensão>/
#
set -eo pipefail

BACKUP_ROOT="${HOME}/.local/share/whitesur-custom/backups/dock"

CSS_BEGIN="/* >>> WhiteSur Custom Dock Theme >>> */"
CSS_END="/* <<< WhiteSur Custom Dock Theme <<< */"
JS_BEGIN="// >>> WhiteSur Custom Dock Magnification >>>"
JS_END="// <<< WhiteSur Custom Dock Magnification <<<"
JS_MODULE_NAME="whitesur-magnification.js"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m    %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*"; }

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

run_remove() {
  local target="$1"

  if [[ -w "$(dirname "${target}")" ]]; then
    rm -f "${target}"
  elif command -v sudo > /dev/null; then
    sudo rm -f "${target}"
  else
    rm -f "${target}" 2>/dev/null || true
  fi
}

strip_block() {
  local file="$1" begin="$2" end="$3"

  awk -v b="${begin}" -v e="${end}" '
    index($0, b) { skip = 1; next }
    index($0, e) { skip = 0; next }
    skip != 1 { print }
  ' "${file}"
}

restore_file() {
  local target="$1" backup="$2" begin="$3" end="$4"
  local tmp

  if [[ ! -f "${target}" ]]; then
    return 0
  fi

  if grep -qF "${begin}" "${target}"; then
    tmp="$(mktemp)"
    strip_block "${target}" "${begin}" "${end}" > "${tmp}"
    run_write "${target}" cp -f "${tmp}" "${target}"
    rm -f "${tmp}"
    ok "Bloco do WhiteSur removido de ${target}"
  elif [[ -f "${backup}" ]]; then
    run_write "${target}" cp -f "${backup}" "${target}"
    ok "Arquivo original restaurado em ${target}"
  fi
}

restore_settings() {
  local backup_dir="$1"
  local file="${backup_dir}/gsettings.txt"
  local schema key value

  [[ -f "${file}" ]] || return 0

  while IFS='|' read -r schema key value; do
    [[ -z "${schema}" || -z "${key}" ]] && continue
    [[ -z "${value}" ]] && continue

    if gsettings set "${schema}" "${key}" "${value}" 2>/dev/null; then
      ok "${schema} ${key} = ${value}"
    else
      warn "Não foi possível restaurar ${schema} ${key}."
    fi
  done < "${file}"
}

restore_extension() {
  local backup_dir="$1"
  local manifest="${backup_dir}/manifest.txt"
  local ext_dir=""

  if [[ -f "${manifest}" ]]; then
    ext_dir="$(sed -n 's/^ext_dir=//p' "${manifest}" | head -n1)"
  fi

  if [[ -z "${ext_dir}" || ! -d "${ext_dir}" ]]; then
    warn "Extensão não encontrada para o backup ${backup_dir} — pulando."
    return 0
  fi

  ok "Restaurando ${ext_dir}"

  restore_file "${ext_dir}/stylesheet.css" "${backup_dir}/stylesheet.css.orig" "${CSS_BEGIN}" "${CSS_END}"
  restore_file "${ext_dir}/extension.js" "${backup_dir}/extension.js.orig" "${JS_BEGIN}" "${JS_END}"

  run_remove "${ext_dir}/${JS_MODULE_NAME}"

  restore_settings "${backup_dir}"
}

log "Restaurando a dock nativa do Zorin OS"

if [[ ! -d "${BACKUP_ROOT}" ]]; then
  warn "Nenhum backup encontrado em ${BACKUP_ROOT} — nada a fazer."
  exit 0
fi

FOUND=false

for backup_dir in "${BACKUP_ROOT}"/*/; do
  [[ -d "${backup_dir}" ]] || continue
  FOUND=true
  restore_extension "${backup_dir%/}"
done

if [[ "${FOUND}" == "false" ]]; then
  warn "Nenhum backup encontrado em ${BACKUP_ROOT} — nada a fazer."
  exit 0
fi

ok "Dock restaurada ao estado anterior."
