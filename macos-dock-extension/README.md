# MacOS Dock — build corrigido

Extensão [MacOS Dock](https://github.com/vinnytherobot/MacOSDock) de
`vinnytherobot`, vendorizada neste repositório **já compilada e com os ajustes
aplicados**. Assim, `./install.sh` instala a dock pronta, sem depender de
`node`, `npm` nem da extensions.gnome.org.

- **Versão base:** 18 (mesma publicada na extensions.gnome.org)
- **Licença:** MIT (`LICENSE`)
- **Pasta de instalação:** `~/.local/share/gnome-shell/extensions/macos-dock@vinnytherobot.github.io`

---

## Ajustes aplicados

### 1. Espaçamento vertical simétrico

O container declara `padding: 4px 10px`, mas cada slot de ícone tinha altura
fixa de `48 + 12 + 4 = 64px` enquanto o conteúdo ocupa 54px (ícone + linha de
pontinhos). Os 10px excedentes eram empacotados no fim do slot, deixando o vão
de baixo maior que o de cima (medido na tela: 7px acima, 14px abaixo).

A altura passou a derivar do conteúdo:

```js
_getIconActorHeight() {
    return this._iconSize + (this._runningIndicatorsEnabled ? 6 : 0);
}
```

Altura da barra: **72px → 62px**, com vãos de 4px/4px.

Arquivos: `lib/iconManager.js` (3 chamadas + o novo método) e
`lib/dockManager.js` (`_dockHeight`).

### 2. Botão de aplicações sem magnificação

O primeiro ícone (grade de aplicações) crescia no hover. Agora slots com a
classe `macos-dock-app-button` ficam em escala 1.0 — mantendo hover, tooltip e
clique — sem afetar os demais ícones.

A detecção é por **classe de estilo**, não por índice, então continua correta
se o botão for movido para o fim da dock.

Arquivo: `lib/magnification.js`.

---

## Reaplicar após uma atualização

Se a dock for atualizada pela extensions.gnome.org, os arquivos desta pasta
serão substituídos pela versão oficial e os ajustes se perdem. Para reaplicar:

```bash
./install.sh --dock
```

Suas preferências (posição, tamanho dos ícones, opacidade, favoritos) ficam no
`dconf` e **não** são afetadas.

---

## Como o patch foi feito

O diff contra o upstream está em `patches.patch` e foi gerado a partir do
código-fonte TypeScript, não dos arquivos compilados:

```bash
git clone https://github.com/vinnytherobot/MacOSDock.git
cd MacOSDock
git apply /caminho/para/patches.patch
npm ci
npm run build          # gera dist/
glib-compile-schemas schemas/
```

Depois copie para esta pasta os arquivos de `dist/` (`extension.js`, `prefs.js`,
`lib/`), mais `metadata.json`, `stylesheet.css` e `schemas/`.

## Atualizar para uma versão nova do upstream

1. Atualize o clone do projeto e rebaseie os dois ajustes (arquivos listados
   acima são poucos e independentes);
2. Rode `npm ci && npm run build`;
3. Regenere `patches.patch` com `git diff`;
4. Substitua os arquivos desta pasta e ajuste `version` no `metadata.json`;
5. Rode `./install.sh --dock` para instalar e **saia/entre na sessão** — no
   Wayland, `Alt+F2 → r` não recarrega o shell, e o GNOME mantém os módulos ES
   em cache mesmo após desabilitar/habilitar a extensão.
