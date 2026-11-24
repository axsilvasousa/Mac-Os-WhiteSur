/* ==========================================================================
   Super abre a grade de aplicativos
   ==========================================================================

   Copyright (c) 2026 WhiteSur Custom contributors — MIT License.
   Veja o arquivo LICENSE na raiz do repositório.

   O GNOME Shell registra a tecla Super com o keybinding "toggle-overview", cujo
   handler é fixo no shell (Overview.toggle()) e sempre abre as Atividades.
   Esta extensão troca o handler por um que abre a grade de aplicativos
   (Overview.showApps()).

   Se a extensão for desabilitada, o comportamento original (Atividades) volta
   automaticamente.
   ========================================================================== */

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const KEYBINDING = 'toggle-overview';
const WM_SCHEMA = 'org.gnome.desktop.wm.keybindings';

export default class SuperAppGridExtension extends Extension {
    enable() {
        this._wmSettings = new Gio.Settings({schema_id: WM_SCHEMA});
        this._settings = this.getSettings();

        this._installKeybinding();

        this._syncActivitiesButton();
        this._settings.connect('changed::override-activities-button',
            () => this._syncActivitiesButton());
    }

    disable() {
        this._settings.disconnectAll();

        this._restoreActivitiesButton();

        Main.wm.removeKeybinding(KEYBINDING);

        // Devolve o comportamento original do shell (Atividades).
        Main.wm.addKeybinding(
            KEYBINDING,
            this._wmSettings,
            Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
            Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW,
            () => Main.overview.toggle());

        this._wmSettings = null;
        this._settings = null;
    }

    /* --------------------------------------------------------------------
     * Tecla Super
     * ------------------------------------------------------------------ */
    _installKeybinding() {
        // Remove o handler registrado pelo próprio shell.
        Main.wm.removeKeybinding(KEYBINDING);

        Main.wm.addKeybinding(
            KEYBINDING,
            this._wmSettings,
            Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
            Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW,
            () => this._toggle());
    }

    _toggle() {
        if (Main.overview.visible)
            Main.overview.hide();
        else
            Main.overview.showApps();
    }

    /* --------------------------------------------------------------------
     * Botão "Atividades" do painel superior
     * ------------------------------------------------------------------ */
    _getActivitiesButton() {
        return Main.panel?.statusArea?.activities ?? null;
    }

    _syncActivitiesButton() {
        const button = this._getActivitiesButton();

        if (!button)
            return;

        const wanted = this._settings.get_boolean('override-activities-button');

        if (wanted && !this._buttonId) {
            /* O evento é interceptado antes do vfunc_event do botão (o sinal
               "event" do Clutter é RUN_LAST), então devolvemos EVENT_STOP
               para o shell não abrir as Atividades. */
            this._buttonId = button.connect('event', (actor, event) => {
                const type = event.type();

                if (type !== Clutter.EventType.BUTTON_RELEASE &&
                    type !== Clutter.EventType.TOUCH_END)
                    return Clutter.EVENT_PROPAGATE;

                this._toggle();
                return Clutter.EVENT_STOP;
            });
        } else if (!wanted && this._buttonId) {
            this._restoreActivitiesButton();
        }
    }

    _restoreActivitiesButton() {
        const button = this._getActivitiesButton();

        if (button && this._buttonId) {
            button.disconnect(this._buttonId);
            this._buttonId = 0;
        }
    }
}
