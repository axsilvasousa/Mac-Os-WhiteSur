#!/usr/bin/env bash

# WARNING: Please make this shell not working-directory dependent, for example
# instead of using 'ls blabla', use 'ls "${REPO_DIR}/blabla"'
#
# WARNING: Don't use "cd" in this shell, use it in a subshell instead,
# for example ( cd blabla && do_blabla ) or $( cd .. && do_blabla )
#
# SUGGESTION: Please don't put any dependency installation here
#
# Este instalador roda a instalação PADRÃO do tema WhiteSur:
# variantes Dark/Light x normal/solid, com os ajustes deste repositório.
# Não há opções de estilo — para mudar algo, edite os arquivos do tema.
#
# Derivado do instalador do WhiteSur GTK Theme (MIT — ver gtk-theme/COPYING),
# com as opções de estilo removidas.

###############################################################################
#                             VARIABLES & HELP                                #
###############################################################################

readonly REPO_DIR="$(dirname "$(readlink -m "${0}")")"
source "${REPO_DIR}/libs/lib-install.sh"

# Customization, default values
colors=("${COLOR_VARIANTS[@]}")
opacities=("${OPACITY_VARIANTS[@]}")

usage() {
  helpify_title
  helpify "-r, --remove, -u, --uninstall" "[theme|app]"  "  Remove os temas instalados" ""
  helpify "-h, --help"                    ""               "  Mostra esta ajuda"            ""
}

###############################################################################
#                                  MAIN                                       #
###############################################################################

#-----------------------------PARSE ARGUMENTS---------------------------------#

echo

while [[ $# -gt 0 ]]; do
  # Don't show any dialog here. Let this loop checks for errors or shows help
  # We can only show dialogs when there's no error and no -r parameter

  case "${1}" in
    # Parameters that don't require a value
    -r|--remove|-u|--uninstall)
      uninstall='true'; shift
      for type in "${@}"; do
      case "${type}" in
        theme)
          remove_theme="true"; shift ;;
        app)
          remove_app="true"; shift ;;
      esac
      done
      ;;
    --silent-mode)
      full_sudo "${1}"; silent_mode='true'; shift ;;
    -h|--help)
      need_help="true"; shift ;;
    *)
      prompt -e "ERROR: Unrecognized installation option '${1}'."
      has_any_error="true"; shift ;;
  esac
done

finalize_argument_parsing

#---------------------------START INSTALL THEMES-------------------------------#

if [[ "${uninstall}" == 'true' ]]; then
  prompt -i "Removing '${name}' gtk themes in '${dest}'... \n"
  prompt -w "REMOVAL: Non-file-related parameters will be ignored. \n"
  remove_themes; remove_libadwaita
  prompt -s "Done! All '${name}' gtk themes have been removed."

  if [[ "${remove_app}" == 'true' ]]; then
    prompt -i "\n  Uninstall 'gnome-theme-switcher' app..."
    rm -rf "${BIN_DIR}/gnome-theme-switcher"
    rm -rf "${APP_DIR}/org.gnome.GTK4ThemeSwitcher.desktop"
  fi

  if [[ -f "${MISC_GR_FILE}.bak" ]]; then
    prompt -e "Find installed GDM theme, you need to run: 'sudo ./tweaks.sh -g -r' to remove it!"
  fi
else
  clean_themes; customize_theme; avoid_variant_duplicates;

  prompt -w "Installing '${name}' themes in '${dest}'...\n";

  prompt -t "--->>> GTK | GNOME Shell | Cinnamon | Metacity | XFWM | Plank <<<---"
  prompt -i "Color variants   : $( IFS=';'; echo "${colors[*]}" )"
  prompt -i "Theme variants   : $( IFS=';'; echo "${themes[*]}" )"
  prompt -i "Opacity variants : $( IFS=';'; echo "${opacities[*]}" )"
  prompt -i "Alt variants     : $( IFS=';'; echo "${alts[*]}" )"
  prompt -i "Scheme variants  : $( IFS=';'; echo "${schemes[*]}" )"
  prompt -i "Start icon style : ${icon}"
  prompt -i "Nautilus style   : ${nautilus_style}"

  if has_command gnome-shell; then
    prompt -i "Desktop          : $(gnome-shell --version)"
  fi

  install_app

  echo; install_themes; echo; prompt -s "Done!"

  if (is_my_distro "solus") && (is_running "gnome-session"); then
    msg="GNOME: you may need to disable 'User Themes' extension to fix your dock."
  fi

  if [[ "${msg}" ]]; then
    echo; prompt -w "${msg}"
    notif_msg="${msg}\n\n${final_msg}"
  else
    notif_msg="${final_msg}"
  fi

  echo; prompt -i "${final_msg}"
fi

echo
