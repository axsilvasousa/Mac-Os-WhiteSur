#!/usr/bin/env bash
#
# WhiteSur Custom — instalador único
#
# Instala, em um só comando:
#   1. O tema GTK/SHELL WhiteSur com os ajustes de legibilidade e
#      arredondamento deste repositório.
#   2. O tema de ícones WhiteSur (variantes normal, -light e -dark).
#   3. A extensão MacOS Dock já corrigida (espaçamento simétrico e o botão
#      de aplicações sem magnificação).
#   4. Os ajustes de raio dos menus do Blur my Shell (se instalado).
#
# Uso:
#   ./install.sh              # instala tema + ícones + dock
#   ./install.sh --theme      # instala apenas o tema GTK/Shell
#   ./install.sh --icons      # instala apenas os ícones
#   ./install.sh --dock       # instala apenas a extensão MacOS Dock
#   ./install.sh --uninstall  # remove tema, ícones e dock
#
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GTK_DIR="${ROOT_DIR}/gtk-theme"
ICON_DIR="${ROOT_DIR}/icon-theme"
DOCK_DIR="${ROOT_DIR}/macos-dock-extension"

DOCK_UUID="macos-dock@vinnytherobot.github.io"
EXT_DIR="${HOME}/.local/share/gnome-shell/extensions"

# Flags fixas: estilo Nautilus "mojave", que é o visual validado neste pacote
# (o padrão upstream é "stable"). As 4 variantes Dark/Light x normal/solid são
# instaladas por padrão, sem precisar de flags.
THEME_FLAGS=(-N mojave)

do_theme=true
do_icons=true
do_dock=true
do_uninstall=false

usage() {
  cat << EOF

  WhiteSur Custom — tema + ícones + dock em um comando

  Uso:
    ./install.sh              Instala o tema GTK/Shell, os ícones e a dock
    ./install.sh --theme      Instala apenas o tema GTK/Shell
    ./install.sh --icons      Instala apenas os ícones
    ./install.sh --dock       Instala apenas a extensão MacOS Dock
    ./install.sh --uninstall  Remove tudo o que foi instalado
    ./install.sh --help       Mostra esta ajuda

  Observações:
    - O tema já inclui os ajustes de busca, menus e menu rápido documentados
      no README.md.
    - Requer 'sassc' e 'glib-compile-resources' (o instalador do tema tenta
      instalar automaticamente caso falte).
    - A extensão MacOS Dock é instalada já com as correções deste pacote,
      então não é preciso baixá-la da extensions.gnome.org.
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

# Instala a extensão MacOS Dock já corrigida (vendorizada neste repositório).
# Não baixa nada: o pacote em macos-dock-extension/ já contém o build com os
# ajustes de espaçamento e de magnificação do botão de aplicações.
install_dock() {
  if [[ ! -d "${DOCK_DIR}" ]]; then
    warn "Pasta macos-dock-extension/ não encontrada — etapa da dock ignorada."
    return 0
  fi

  log "Instalando extensão MacOS Dock (com ajustes)"
  mkdir -p "${EXT_DIR}/${DOCK_UUID}"
  rm -rf "${EXT_DIR:?}/${DOCK_UUID:?}"
  mkdir -p "${EXT_DIR}/${DOCK_UUID}"
  cp -r "${DOCK_DIR}/." "${EXT_DIR}/${DOCK_UUID}/"
  rm -f "${EXT_DIR}/${DOCK_UUID}/patches.patch"

  # Compila o schema local, exigido para a extensão carregar as preferências.
  if command -v glib-compile-schemas > /dev/null; then
    glib-compile-schemas "${EXT_DIR}/${DOCK_UUID}/schemas" 2>/dev/null || true
  fi

  ok "MacOS Dock instalada em ~/.local/share/gnome-shell/extensions/${DOCK_UUID}"

  # Habilita a extensão apenas se o gnome-shell estiver em execução, para não
  # falhar em instalações feitas por chroot/container.
  if command -v gnome-extensions > /dev/null && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    gnome-extensions enable "${DOCK_UUID}" 2>/dev/null \
      || warn "Não foi possível habilitar a dock agora. Ative em Extensões."
  else
    warn "Habilite a extensão 'MacOS Dock' em Extensões após entrar na sessão."
  fi
}

uninstall_all() {
  log "Removendo tema GTK/Shell"
  ( cd "${GTK_DIR}" && ./install.sh -r theme ) || warn "Falha ao remover o tema."

  log "Removendo ícones WhiteSur"
  ( cd "${ICON_DIR}" && ./install.sh -r ) || warn "Falha ao remover os ícones."

  if [[ -d "${EXT_DIR}/${DOCK_UUID}" ]]; then
    log "Removendo extensão MacOS Dock"
    if command -v gnome-extensions > /dev/null && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
      gnome-extensions disable "${DOCK_UUID}" 2>/dev/null || true
    fi
    rm -rf "${EXT_DIR:?}/${DOCK_UUID:?}"
    ok "MacOS Dock removida"
  fi

  ok "Remoção concluída"
}

###############################################################################
#                                   MAIN                                      #
###############################################################################

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme)  do_icons=false; do_dock=false ;;
    --icons)  do_theme=false; do_dock=false ;;
    --dock)   do_theme=false; do_icons=false ;;
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

if [[ "${do_dock}" == 'true' ]]; then
  install_dock
fi

if [[ "${do_theme}" == 'true' ]]; then
  apply_blur_my_shell
fi

log "Concluído"
cat << EOF

  Próximos passos:
    1. Abra o app "Ajustes" (ou Tweaks) e selecione o tema WhiteSur-Dark.
    2. Em Aparência, selecione o tema de ícones WhiteSur-dark.
    3. Ative a extensão "MacOS Dock" em Extensões, se ainda não estiver ativa.

  IMPORTANTE — reinicie a sessão (sair e entrar) para ver os ajustes:
    - A busca e os menus do tema só mudam quando o shell recarrega o CSS.
    - A dock usa módulos ES, que ficam em cache: desabilitar e habilitar a
      extensão NÃO recarrega o código alterado.
    - No Wayland não existe atalho de reload (Alt+F2 -> r só funciona em X11).

  Se atualizar a dock pela extensions.gnome.org, os ajustes se perdem.
  Reaplique com: ./install.sh --dock   (suas preferências são preservadas)

EOF
