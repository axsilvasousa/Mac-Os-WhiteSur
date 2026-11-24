# Super abre a grade de aplicativos

Extensão mínima que troca o comportamento da tecla **Super**: em vez de abrir
as **Atividades** (overview), abre a **grade de aplicativos**.

---

## Por que não dá para fazer só com `gsettings`

No GNOME Shell (40+), a tecla Super é registrada pelo próprio shell em
`js/ui/overview.js`:

```js
Main.wm.addKeybinding(
    'toggle-overview',
    new Gio.Settings({schema_id: 'org.gnome.desktop.wm.keybindings'}),
    Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
    Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW,
    this.toggle.bind(this));
```

O handler é `Overview.toggle()`, que é fixo no código do shell:

```js
toggle() {
    if (this.isDummy) return;
    if (this._visible) this.hide();
    else this.show();          // ← Atividades (WINDOW_PICKER)
}
```

Já a grade de aplicativos é outro estado do overview:

```js
showApps() {
    this.show(OverviewControls.ControlsState.APP_GRID);
}
```

Como `showApps()` só existe em código, **não há chave de `gsettings` que
troque o comportamento** — a única forma é registrar o handler de novo, o que
esta extensão faz.

---

## O que a extensão faz

1. Remove o handler original do shell (`Main.wm.removeKeybinding`);
2. Registra o mesmo keybinding (`toggle-overview`) com um handler próprio:
   - overview fechado → `Main.overview.showApps()` (grade de aplicativos);
   - overview aberto → `Main.overview.hide()` (fecha);
3. Opcionalmente faz o mesmo com o **botão "Atividades"** do painel superior.

Ao desabilitar a extensão, o comportamento original (Atividades) volta
sozinho — nada fica "quebrado" no shell.

---

## Opções

| Chave | Padrão | Efeito |
|---|---|---|
| `override-activities-button` | `true` | Trocar também o clique no botão "Atividades" do painel. |

Para deixar o botão do painel como era:

```bash
gsettings set org.gnome.shell.extensions.super-app-grid override-activities-button false
```

A tecla Super é sempre trocada.

---

## Instalação

Feita pelo `install.sh` do pacote:

```bash
./install.sh --super
```

Ou manualmente:

```bash
cp -r super-app-grid ~/.local/share/gnome-shell/extensions/super-app-grid@whitesur.local
glib-compile-schemas ~/.local/share/gnome-shell/extensions/super-app-grid@whitesur.local/schemas
gnome-extensions enable super-app-grid@whitesur.local
```

Depois é preciso **sair e entrar na sessão** (no Wayland não existe reload do
shell).

---

## Licença

MIT — Copyright (c) 2026 WhiteSur Custom contributors.
Veja o `LICENSE` na raiz do repositório.
