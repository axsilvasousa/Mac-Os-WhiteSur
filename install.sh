#!/usr/bin/env bash
#
# WhiteSur Custom — instalador único
#
# Copyright (c) 2026 WhiteSur Custom contributors — MIT License.
# Veja o arquivo LICENSE na raiz do repositório.
#
# Instala, em um só comando:
#   1. O tema GTK/SHELL WhiteSur com os ajustes de legibilidade e
#      arredondamento deste repositório.
#   2. O tema de ícones WhiteSur (variantes normal, -light e -dark), com os
#      apps na versão alternativa: sem o rosto do Finder no gerenciador de
#      arquivos, mantendo as pastas (places) no estilo macOS.
#   3. O tema macOS na dock nativa do Zorin OS (Zorin Dash), com backup do
#      estado original para poder desfazer a qualquer momento.
#
# Uso:
#   ./install.sh              # instala tema + ícones + tema da dock
#   ./install.sh --theme      # instala apenas o tema GTK/Shell
#   ./install.sh --icons      # instala apenas os ícones
#   ./install.sh --dock       # instala apenas o tema da dock nativa
#   ./install.sh --uninstall  # remove tema, ícones e tema da dock
#
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GTK_DIR="${ROOT_DIR}/gtk-theme"
ICON_DIR="${ROOT_DIR}/icon-theme"
DOCK_DIR="${ROOT_DIR}/dock-theme"
SUPER_DIR="${ROOT_DIR}/super-app-grid"

# Extensão que troca a tecla Super (grade de aplicativos em vez de Atividades)
SUPER_UUID="super-app-grid@whitesur.local"

# Extensão antiga, mantida apenas como referência no repositório. Se estiver
# instalada na máquina, é removida para que a dock nativa do Zorin seja usada.
LEGACY_DOCK_UUID="macos-dock@vinnytherobot.github.io"
EXT_DIR="${HOME}/.local/share/gnome-shell/extensions"

do_theme=true
do_icons=true
do_dock=true
do_super=true
do_uninstall=false

usage() {
  cat << EOF

  WhiteSur Custom — tema + ícones + tema da dock em um comando

  Uso:
    ./install.sh              Instala o tema GTK/Shell, os ícones, o tema da dock e a tecla Super
    ./install.sh --theme      Instala apenas o tema GTK/Shell
    ./install.sh --icons      Instala apenas os ícones
    ./install.sh --dock       Instala apenas o tema da dock nativa
    ./install.sh --super      Instala apenas a extensão da tecla Super
    ./install.sh --uninstall  Remove tudo o que foi instalado
    ./install.sh --help       Mostra esta ajuda

  Observações:
    - O tema GTK/Shell é sempre instalado na configuração padrão
      (Dark/Light x normal/solid), sem opções extras.
    - Os ícones usam apps alternativos (-A): sem o rosto do Finder no
      gerenciador de arquivos, mas com as pastas (places) no estilo macOS.
    - O tema da dock é aplicado na dock nativa do Zorin (Zorin Dash), com
      backup do arquivo original em
      ~/.local/share/whitesur-custom/backups/dock/.
    - Para desfazer apenas o tema da dock: ./dock-theme/restore.sh
    - A tecla Super passa a abrir a grade de aplicativos. Para voltar ao
      comportamento original, desative a extensão em Extensões.

EOF
}

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m    %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*"; }

# Remove a extensão antiga (macos-dock), que não é mais usada.
remove_legacy_dock() {
  local legacy="${EXT_DIR}/${LEGACY_DOCK_UUID}"

  [[ -d "${legacy}" ]] || return 0

  log "Removendo a extensão antiga MacOS Dock"

  if command -v gnome-extensions > /dev/null && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    gnome-extensions disable "${LEGACY_DOCK_UUID}" 2>/dev/null || true
  fi

  rm -rf "${legacy}"
  ok "Extensão MacOS Dock removida"
}

install_theme() {
  log "Instalando tema GTK/Shell (WhiteSur + ajustes)"
  ( cd "${GTK_DIR}" && ./install.sh )
  ok "Tema instalado em ~/.themes"
}

install_icons() {
  log "Instalando ícones WhiteSur (apps alternativos, pastas estilo macOS)"
  # -A = alternativa só para apps: tira o rosto do Finder do gerenciador de
  # arquivos e usa os ícones genéricos de apps, mas mantém as pastas
  # (places) no estilo Big Sur do macOS.
  ( cd "${ICON_DIR}" && ./install.sh -A )
  ok "Ícones instalados em ~/.local/share/icons"
}

install_dock() {
  if [[ ! -f "${DOCK_DIR}/apply.sh" ]]; then
    warn "Pasta dock-theme/ não encontrada — etapa da dock ignorada."
    return 0
  fi

  ( cd "${DOCK_DIR}" && bash ./apply.sh )
}

install_super() {
  if [[ ! -d "${SUPER_DIR}" ]]; then
    warn "Pasta super-app-grid/ não encontrada — etapa ignorada."
    return 0
  fi

  log "Instalando a extensão 'Super abre a grade de aplicativos'"

  mkdir -p "${EXT_DIR}"
  rm -rf "${EXT_DIR:?}/${SUPER_UUID:?}"
  mkdir -p "${EXT_DIR}/${SUPER_UUID}"
  cp -r "${SUPER_DIR}/." "${EXT_DIR}/${SUPER_UUID}/"

  if command -v glib-compile-schemas > /dev/null; then
    glib-compile-schemas "${EXT_DIR}/${SUPER_UUID}/schemas" 2>/dev/null || true
  fi

  ok "Extensão instalada em ~/.local/share/gnome-shell/extensions/${SUPER_UUID}"

  if command -v gnome-extensions > /dev/null && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    gnome-extensions enable "${SUPER_UUID}" 2>/dev/null \
      || warn "Não foi possível habilitar a extensão agora. Ative em Extensões."
  else
    warn "Ative a extensão 'Super abre a grade de aplicativos' em Extensões."
  fi
}

uninstall_all() {
  log "Removendo tema GTK/Shell"
  ( cd "${GTK_DIR}" && ./install.sh -r theme ) || warn "Falha ao remover o tema."

  log "Removendo ícones WhiteSur"
  ( cd "${ICON_DIR}" && ./install.sh -r ) || warn "Falha ao remover os ícones."

  log "Restaurando a dock nativa do Zorin OS"
  if [[ -f "${DOCK_DIR}/restore.sh" ]]; then
    ( cd "${DOCK_DIR}" && bash ./restore.sh ) || warn "Falha ao restaurar a dock."
  fi

  if [[ -d "${EXT_DIR}/${SUPER_UUID}" ]]; then
    log "Removendo a extensão da tecla Super"
    if command -v gnome-extensions > /dev/null && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
      gnome-extensions disable "${SUPER_UUID}" 2>/dev/null || true
    fi
    rm -rf "${EXT_DIR:?}/${SUPER_UUID:?}"
    ok "Extensão removida"
  fi

  remove_legacy_dock

  ok "Remoção concluída"
}

###############################################################################
#                                   MAIN                                      #
###############################################################################

while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme)  do_icons=false; do_dock=false; do_super=false ;;
    --icons)  do_theme=false; do_dock=false; do_super=false ;;
    --dock)   do_theme=false; do_icons=false; do_super=false ;;
    --super)  do_theme=false; do_icons=false; do_dock=false ;;
    --uninstall|-u|-r)
      do_uninstall=true ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      printf '\033[1;31m  Erro: opção desconhecida "%s".\033[0m\n' "$1"
      usage; exit 1 ;;
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
  install_theme
fi

if [[ "${do_icons}" == 'true' ]]; then
  install_icons
fi

if [[ "${do_dock}" == 'true' ]]; then
  remove_legacy_dock
  install_dock
fi

if [[ "${do_super}" == 'true' ]]; then
  install_super
fi

log "Concluído"
cat << EOF

  Próximos passos:
    1. Abra o app "Ajustes" (ou Tweaks) e selecione o tema WhiteSur-Dark.
    2. Em Aparência, selecione o tema de ícones WhiteSur-dark.
    3. Em Extensões, confira que a "Zorin Dash" e a "Super abre a grade de
       aplicativos" estão ativadas.

  IMPORTANTE — reinicie a sessão (sair e entrar) para ver os ajustes:
    - A busca e os menus do tema só mudam quando o shell recarrega o CSS.
    - A dock usa módulos ES, que ficam em cache: desabilitar e habilitar a
      extensão NÃO recarrega o código alterado.
    - No Wayland não existe atalho de reload (Alt+F2 -> r só funciona em X11).

  Para desfazer o tema da dock:
    ./dock-theme/restore.sh

  Para voltar a tecla Super ao normal (Atividades):
    desative a extensão "Super abre a grade de aplicativos" em Extensões,
    ou rode: ./install.sh --uninstall

EOF
