#!/usr/bin/env bash
#
# WhiteSur Custom — instalador único
#
# Instala, em um só comando:
#   1. O tema GTK/SHELL WhiteSur com os ajustes de legibilidade e
#      arredondamento deste repositório.
#   2. O tema de ícones WhiteSur (variantes normal, -light e -dark).
#   3. Os ajustes de raio dos menus do Blur my Shell (se instalado).
#
# Uso:
#   ./install.sh              # instala tema + ícones
#   ./install.sh --theme      # instala apenas o tema GTK/Shell
#   ./install.sh --icons      # instala apenas os ícones
#   ./install.sh --uninstall  # remove tema e ícones
#
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GTK_DIR="${ROOT_DIR}/gtk-theme"
ICON_DIR="${ROOT_DIR}/icon-theme"

# Flags fixas: estilo Nautilus "mojave", que é o visual validado neste pacote
# (o padrão upstream é "stable"). As 4 variantes Dark/Light x normal/solid são
# instaladas por padrão, sem precisar de flags.
THEME_FLAGS=(-N mojave)

do_theme=true
do_icons=true
do_uninstall=false

usage() {
  cat << EOF

  WhiteSur Custom — tema + ícones em um comando

  Uso:
    ./install.sh              Instala o tema GTK/Shell e os ícones
    ./install.sh --theme      Instala apenas o tema GTK/Shell
    ./install.sh --icons      Instala apenas os ícones
    ./install.sh --uninstall  Remove tema e ícones instalados
    ./install.sh --help       Mostra esta ajuda

  Observações:
    - O tema já inclui os ajustes de busca, menus e menu rápido documentados
      no README.md.
    - Requer 'sassc' e 'glib-compile-resources' (o instalador do tema tenta
      instalar automaticamente caso falte).
    - Para aplicar os raios dos menus no Blur my Shell, a extensão precisa
      estar instalada; caso contrário, essa etapa é ignorada.

EOF
}

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m    %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*"; }

# Ajusta os raios que o Blur my Shell impõe por estilo inline nos menus.
# Sem isso, a extensão sobrepõe o raio definido pelo tema.
apply_blur_my_shell() {
  local schema_dir="${HOME}/.local/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas"
  local schema="org.gnome.shell.extensions.blur-my-shell.popup"

  if [[ ! -d "${schema_dir}" ]]; then
    warn "Blur my Shell não encontrado — etapa de raios ignorada."
    return 0
  fi

  if ! command -v gsettings > /dev/null; then
    warn "gsettings não encontrado — etapa de raios ignorada."
    return 0
  fi

  log "Ajustando raios dos menus no Blur my Shell"
  for key in quick-settings-corner-radius menu-corner-radius submenu-corner-radius calendar-corner-radius; do
    gsettings --schemadir "${schema_dir}" set "${schema}" "${key}" 12 2>/dev/null || true
  done
  ok "Raios dos menus definidos para 12px"

  # Recarrega o stylesheet do shell para aplicar sem reiniciar a sessão.
  if gsettings get org.gnome.shell.extensions.user-theme name > /dev/null 2>&1; then
    local current
    current="$(gsettings get org.gnome.shell.extensions.user-theme name | tr -d "'")"
    gsettings set org.gnome.shell.extensions.user-theme name 'Adwaita' 2>/dev/null || true
    sleep 1
    gsettings set org.gnome.shell.extensions.user-theme name "${current}" 2>/dev/null || true
    sleep 1
    ok "Tema recarregado"
  fi
}

install_theme() {
  log "Instalando tema GTK/Shell (WhiteSur + ajustes)"
  ( cd "${GTK_DIR}" && ./install.sh "${THEME_FLAGS[@]}" "$@" )
  ok "Tema instalado em ~/.themes"
}

install_icons() {
  log "Instalando ícones WhiteSur"
  ( cd "${ICON_DIR}" && ./install.sh "$@" )
  ok "Ícones instalados em ~/.local/share/icons"
}

uninstall_all() {
  log "Removendo tema GTK/Shell"
  ( cd "${GTK_DIR}" && ./install.sh -r theme ) || warn "Falha ao remover o tema."

  log "Removendo ícones WhiteSur"
  ( cd "${ICON_DIR}" && ./install.sh -r ) || warn "Falha ao remover os ícones."

  ok "Remoção concluída"
}

###############################################################################
#                                   MAIN                                      #
###############################################################################

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme)  do_icons=false ;;
    --icons)  do_theme=false ;;
    --uninstall|-u|-r)
      do_uninstall=true ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      EXTRA_ARGS+=("$1") ;;
  esac
  shift
done

if [[ ! -d "${GTK_DIR}" || ! -d "${ICON_DIR}" ]]; then
  printf '\n\033[1;31m  Erro: execute este script a partir da raiz do repositório.\033[0m\n'
  printf '  Esperado: %s/gtk-theme e %s/icon-theme\n\n' "${ROOT_DIR}" "${ROOT_DIR}"
  exit 1
fi

if [[ "${do_uninstall}" == 'true' ]]; then
  uninstall_all
  exit 0
fi

if [[ "${do_theme}" == 'true' ]]; then
  install_theme "${EXTRA_ARGS[@]}"
fi

if [[ "${do_icons}" == 'true' ]]; then
  install_icons
fi

if [[ "${do_theme}" == 'true' ]]; then
  apply_blur_my_shell
fi

log "Concluído"
cat << EOF

  Próximos passos:
    1. Abra o app "Ajustes" (ou Tweaks) e selecione o tema WhiteSur-Dark.
    2. Em Aparência, selecione o tema de ícones WhiteSur-dark.
    3. Se a busca ou os menus ainda estiverem com o visual antigo,
       feche e abra a sessão (ou rode: Alt+F2, digite 'r', Enter).

EOF
