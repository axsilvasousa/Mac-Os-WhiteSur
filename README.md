# WhiteSur Custom — tema GTK/Shell + ícones + dock

Pacote pessoal do [WhiteSur GTK Theme](https://github.com/vinceliuice/WhiteSur-gtk-theme),
do [WhiteSur Icon Theme](https://github.com/vinceliuice/WhiteSur-icon-theme) e da
extensão [MacOS Dock](https://github.com/vinnytherobot/MacOSDock)
com ajustes de **legibilidade da busca**, **arredondamento dos painéis** e
**alinhamento visual** com as janelas de aplicativos.

Tudo se instala com **um comando**.

---

## Instalação

```bash
git clone <URL_DO_SEU_REPOSITORIO> WhiteSur-custom
cd WhiteSur-custom
./install.sh
```

O script instala, em sequência:

1. O tema GTK/Shell (variantes Dark e Light, `normal` e `solid`);
2. O tema de ícones (`WhiteSur`, `WhiteSur-dark` e `WhiteSur-light`);
3. A extensão **MacOS Dock**, já com as correções deste pacote;
4. Os raios dos menus do **Blur my Shell**, se a extensão estiver instalada.

Ao terminar, selecione o tema e os ícones em **Ajustes → Aparência**.

### Opções

| Comando | O que faz |
|---|---|
| `./install.sh` | Instala tema + ícones + dock |
| `./install.sh --theme` | Instala apenas o tema GTK/Shell |
| `./install.sh --icons` | Instala apenas os ícones |
| `./install.sh --dock` | Instala apenas a extensão MacOS Dock |
| `./install.sh --uninstall` | Remove tema, ícones e dock |
| `./install.sh --help` | Mostra a ajuda |

### Requisitos

- `sassc` — compila o tema (o instalador tenta instalar automaticamente);
- `glib-compile-resources` — parte do `glib2.0`;
- `glib-compile-schemas` — compila o schema da dock (parte do `glib2.0`);
- GNOME Shell 46+ (testado em Zorin OS 18.1, GNOME Shell 46.0, Wayland).

> Se `sassc` não estiver disponível e a instalação automática falhar:
> `sudo apt install sassc`

### Sobre a extensão MacOS Dock

A dock **não precisa ser baixada separadamente**. O repositório inclui o build
já corrigido em `macos-dock-extension/`, então `./install.sh` a instala
pronta. Versão base: **18** (a mesma da extensions.gnome.org).

Se você já tem a extensão instalada da loja, o instalador **substitui** pelos
arquivos corrigidos, mas **preserva suas preferências** (posição, tamanho de
ícone, opacidade, apps favoritos) — elas ficam no `dconf`, não na pasta da
extensão.

> **Atenção:** ao atualizar a dock pela extensions.gnome.org, os arquivos
> corrigidos serão substituídos pela versão oficial e os dois ajustes abaixo
> serão perdidos. Rode `./install.sh --dock` novamente para reaplicá-los.

---

## Ajustes feitos neste pacote

Todos os ajustes partem do código-fonte oficial (Sass), não de CSS editado à mão.
Assim, se o tema for recompilado, as correções continuam valendo.

### 1. Legibilidade da busca do Overview

**Problema:** o painel de resultados usava fundo branco a 10% de opacidade e o
texto era branco a 50–85%. Sobre o papel de parede desfocado, o contraste era
quase nulo. A caixa de digitação tinha o mesmo problema.

**Correção:**

| Elemento | Antes | Depois |
|---|---|---|
| Painel de resultados | branco 10% | **preto 55%** + borda branca 10% + sombra de painel (sem sombra no texto) |
| Texto dos resultados | branco 85% | **branco 100%** |
| Descrição do resultado | branco 85% | **branco 80%** |
| Rótulo do provedor | branco 50% | **branco 75%** |
| "Nenhum resultado" | branco 50% | **branco 75%** |
| Caixa de busca (normal) | branco 12% | **preto 45%** |
| Caixa de busca (hover/foco) | branco 20%/18% | **preto 55%/60%** |
| Texto e ícone da busca | branco 50% | **branco 100%** |
| Placeholder | branco 50% | **branco 70%** |
| Item em hover/seleção | branco 10% | **branco 12%** |
| Item ativo | branco 16% | **branco 20%** |

Arquivos: `_search-results.scss`, `_search-entry.scss`, `_drawing.scss`.

#### Sombra de texto vazada do tema base (Zorin)

**Problema:** mesmo com o painel escuro, os rótulos continuavam com um halo
cinza. A origem não era o WhiteSur: o tema base do modo Zorin
(`ZorinGrey-Light/gnome-shell-theme.gresource`) declara

```css
text-shadow: 0px 1.5px 3px rgba(238, 238, 238, 0.5);
```

em `.list-search-result`, `.overview-tile`, `.app-folder` e
`.switcher-list .item-box`. Como o WhiteSur não declarava `text-shadow` nesses
seletores, o valor do tema base **vazava** — e o St propaga a sombra para os
labels filhos.

Isso explica um detalhe que ajudou a diagnosticar: no **hover a sombra sumia**,
porque o próprio Zorin zera `text-shadow` no `:hover`/`:selected`.

**Correção:** `text-shadow: none` explícito em:

| Seletor | Onde aparece |
|---|---|
| `%search-section-content-item` | resultados da busca |
| `.overview-tile` | ícones da grade de apps |
| `.app-folder` | pastas de apps |
| `.switcher-list .item-box` | Alt+Tab |

Arquivos: `_search-results.scss`, `widgets-46-0/_app-grid.scss`,
`_switcher-popup.scss`.

> Isso só afeta ambientes cujo tema base define sombra de texto (Zorin, por
> exemplo). Em GNOME puro o `none` é inofensivo.

### 2. Raio e padding dos painéis da barra superior

**Problema:** o menu rápido e os menus da barra (relógio, indicadores como o
Ventoy) tinham cantos muito mais arredondados e padding diferente do restante do
sistema.

**Referência adotada:** os popovers das janelas GTK do próprio tema —
`popover > contents { padding: 6px; border-radius: 12px; }` — e
`window.csd { border-radius: 12px; }`.

| Elemento | Antes | Depois |
|---|---|---|
| Menu rápido — raio | 33px | **12px** |
| Menu rápido — padding | 12px | **11px** (6px + 5px) |
| Menus da barra — raio | 14px | **12px** |
| Menus da barra — padding | 4px | **6px** |
| Menu do relógio — raio | 22px | **12px** |
| Itens internos dos menus — raio | 8px | **6px** (concêntrico) |

Arquivos: `_quick-settings.scss`, `_popovers.scss`, `_calendar.scss`.

> O padding de 11px do menu rápido é intencional: 6px para manter a
> concentricidade com os itens internos, mais 5px de respiro extra.

### 3. Blur my Shell

O Blur my Shell desenha o fundo desfocado desses menus e aplica o arredondamento
por **estilo inline**, o que sobrepõe o CSS do tema. Por isso o `install.sh`
também ajusta as chaves da extensão:

| Chave | Antes | Depois |
|---|---|---|
| `quick-settings-corner-radius` | 36 | **12** |
| `menu-corner-radius` | 20 | **12** |
| `submenu-corner-radius` | 24 | **12** |
| `calendar-corner-radius` | 30 | **12** |

Isso é feito via `gsettings` e é ignorado com aviso caso a extensão não exista.

> **Convivência com o Blur my Shell:** estes valores valem enquanto forem esses.
> Se você abrir as preferências da extensão e mudar os raios, ela voltará a
> impor os valores próprios e o arredondamento do tema será sobreposto.

### 4. Estilo do Nautilus

O instalador usa `-N mojave` para manter o estilo de sidebar do Nautilus
(`mojave`), que é o visual em uso neste pacote. O padrão do projeto upstream é
`stable`.

Para trocar, edite `THEME_FLAGS` no `install.sh`:

```bash
THEME_FLAGS=(-N mojave)   # opções: stable, normal, mojave, glassy, right
```

### 5. Extensão MacOS Dock

Dois ajustes na extensão, ambos feitos **no código-fonte TypeScript** do
projeto e recompilados — não é CSS improvisado.

#### 5.1 Espaçamento vertical simétrico

**Problema:** embora o container declarasse `padding: 4px 10px` (4px em cima e
4px embaixo), cada ícone tinha altura fixa de `48 + 12 + 4 = 64px`, enquanto o
conteúdo real ocupa apenas 54px (ícone 48 + 6 da linha de pontinhos). Os 10px
que sobravam eram empacotados **no fim** do slot.

Resultado medido na tela: **7px** de vão acima do ícone contra **14px** abaixo.

**Correção:** a altura do slot passou a ser calculada pelo conteúdo real.

```js
_getIconActorHeight() {
    return this._iconSize + (this._runningIndicatorsEnabled ? 6 : 0);
}
```

A altura da barra caiu de 72px para **62px**, com os vãos agora simétricos
(4px/4px). Se os indicadores de apps rodando forem desativados, a altura
acompanha automaticamente (48px), sem espaço morto.

Arquivos: `lib/iconManager.js` (3 pontos) e `lib/dockManager.js` (`_dockHeight`).

#### 5.2 Botão de aplicações sem magnificação

**Problema:** o primeiro ícone (grade de aplicações) crescia junto com os
demais ao passar o mouse, o que deslocava a fileira inteira e descaracterizava
um lançador fixo.

**Correção:** slots com a classe `macos-dock-app-button` ficam travados em
escala 1.0, mas **continuam** reagindo a hover, tooltip e clique.

```js
const NO_MAGNIFICATION_STYLE_CLASSES = ["macos-dock-app-button"];

_canMagnify(actor) {
    return !NO_MAGNIFICATION_STYLE_CLASSES.some(styleClass =>
        actor.has_style_class_name(styleClass)
    );
}
```

A identificação é **por classe de estilo, não por posição** — então funciona
mesmo se você mover o botão de aplicações para o fim da dock
(`show-applications-button-position`).

Arquivo: `lib/magnification.js`.

#### Como reaplicar após atualizar a dock

Os dois ajustes estão em `macos-dock-extension/` (build pronto) e o diff
original em `macos-dock-extension/patches.patch`. Basta:

```bash
./install.sh --dock
```

Isso substitui os arquivos da extensão pela versão corrigida, mantendo suas
preferências.

Para atualizar o patch no futuro, veja `macos-dock-extension/README.md`.

---

## Estrutura do repositório

```
WhiteSur-custom/
├── install.sh                 # instalador único (tema + ícones + dock + Blur)
├── README.md                  # este arquivo
├── gtk-theme/                 # WhiteSur GTK Theme (com os ajustes)
│   ├── install.sh
│   ├── libs/
│   ├── src/
│   └── other/
├── icon-theme/                # WhiteSur Icon Theme
│   ├── install.sh
│   ├── src/
│   ├── colors/
│   ├── links/
│   ├── bold/
│   ├── alternative/
│   └── plasma/
└── macos-dock-extension/      # extensão MacOS Dock (build corrigido)
    ├── README.md              # como surgiu o patch e como atualizá-lo
    ├── patches.patch          # diff contra o upstream
    ├── metadata.json
    ├── extension.js
    ├── prefs.js
    ├── stylesheet.css
    ├── lib/
    └── schemas/
```

Cada subpasta mantém o `install.sh` original do projeto, então é possível usá-las
individualmente ou com as opções nativas de cada instalador.

---

## Testado em

| Item | Versão |
|---|---|
| Distribuição | Zorin OS 18.1 |
| GNOME Shell | 46.0 (Wayland) |
| Blur my Shell | 78 |

---

## Créditos e licença

- **WhiteSur GTK Theme** — Vince Liuice —
  [vinceliuice/WhiteSur-gtk-theme](https://github.com/vinceliuice/WhiteSur-gtk-theme) — MIT
- **WhiteSur Icon Theme** — Vince Liuice —
  [vinceliuice/WhiteSur-icon-theme](https://github.com/vinceliuice/WhiteSur-icon-theme) — GPL-3.0

As licenças originais estão preservadas em `gtk-theme/COPYING` e
`icon-theme/COPYING`. Os ajustes deste pacote seguem a mesma licença de cada
projeto de origem.
