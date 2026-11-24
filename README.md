# WhiteSur Custom — tema GTK/Shell + ícones + dock

Pacote pessoal do [WhiteSur GTK Theme](https://github.com/vinceliuice/WhiteSur-gtk-theme),
do [WhiteSur Icon Theme](https://github.com/vinceliuice/WhiteSur-icon-theme) e de um
**tema macOS aplicado na dock nativa do Zorin OS**, com ajustes de
**legibilidade da busca**, **arredondamento dos painéis** e **alinhamento
visual** com as janelas de aplicativos.

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
2. O tema de ícones (`WhiteSur`, `WhiteSur-dark` e `WhiteSur-light`), com os
   **apps na versão alternativa** (`-A`): sem o rosto do Finder no gerenciador
   de arquivos, mas **mantendo as pastas no estilo macOS**;
3. O tema macOS **na dock nativa do Zorin OS** (Zorin Dash), com backup do
   estado original para poder desfazer;
4. A extensão que faz a tecla **Super** abrir a grade de aplicativos.

Ao terminar, selecione o tema e os ícones em **Ajustes → Aparência**.

### Opções

| Comando | O que faz |
|---|---|
| `./install.sh` | Instala tema + ícones + tema da dock + tecla Super |
| `./install.sh --theme` | Instala apenas o tema GTK/Shell |
| `./install.sh --icons` | Instala apenas os ícones |
| `./install.sh --dock` | Instala apenas o tema da dock nativa |
| `./install.sh --super` | Instala apenas a extensão da tecla Super |
| `./install.sh --uninstall` | Remove tudo o que foi instalado |
| `./install.sh --help` | Mostra a ajuda |

O instalador do tema GTK/Shell roda sempre na **configuração padrão**
(Dark/Light × normal/solid) — sem opções de estilo.

### Requisitos

- `sassc` — compila o tema (o instalador tenta instalar automaticamente);
- `glib-compile-resources` — parte do `glib2.0`;
- `perl` — usado para conectar a magnificação na extensão da dock;
- GNOME Shell 46+ (testado em Zorin OS 18.1, GNOME Shell 46.0, Wayland).

> Se `sassc` não estiver disponível e a instalação automática falhar:
> `sudo apt install sassc`

### Ícones: apps alternativos (`-A`)

Os ícones são instalados com a flag `-A` (adicionada neste pacote ao instalador
do WhiteSur). Ela aplica a versão alternativa **somente nos apps**, mantendo as
pastas no estilo macOS:

| Ícone | Padrão | Com `-A` |
|---|---|---|
| Gerenciador de arquivos | rosto do **Finder** (dois olhos + sorriso) | pasta genérica |
| Apps de sistema (terminal, calculadora, calendário, central de software…) | estilo macOS | genéricos |
| Pastas (`places`: folder, folder-download, folder-code…) | pasta Big Sur | **mantidas (Big Sur)** |
| Dispositivos e tipos de arquivo (`devices`, `mimes`) | estilo macOS | **mantidos** |

Ícones de apps de terceiros (Firefox, Chrome, Spotify…) **não** são alterados.

Comparação com a flag original do upstream:

| Flag | Apps | Pastas | Dispositivos/Mimes |
|---|---|---|---|
| *(nenhuma)* | macOS | macOS | macOS |
| `-A` (este pacote) | genéricos | **macOS** | macOS |
| `-a` (upstream) | genéricos | genéricos | genéricos |

Para instalar com as pastas genéricas também (comportamento original do `-a`):

```bash
cd icon-theme && ./install.sh -a
```

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
Ventoy) tinham cantos muito mais arredondados e padding diferente do restante
do sistema.

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

### 3. Estilo do Nautilus

O instalador usa o estilo de sidebar do Nautilus `mojave`, que é o visual
validado neste pacote. O padrão do projeto upstream é `stable`.

Como o instalador do tema GTK/Shell não tem mais opções, esse valor virou o
padrão em `gtk-theme/libs/lib-core.sh`:

```bash
# Estilo do Nautilus usado e validado neste pacote (o padrão upstream é 'stable')
nautilus_style="mojave"
```

### 4. Tema macOS na dock nativa do Zorin OS

A dock do Zorin OS é a extensão **Zorin Dash** (fork do `dash-to-dock`),
instalada em `/usr/share/gnome-shell/extensions/zorin-dash@zorinos.com`.

Este pacote **não substitui mais a dock do sistema**. Ele aplica o visual e as
animações da antiga extensão `macos-dock-extension` por cima da dock nativa,
sempre com backup do estado anterior.

#### 4.1 Visual (CSS)

O CSS foi portado do `macos-dock-extension/stylesheet.css` para os seletores
que a dock nativa realmente usa:

| Visual | Onde é aplicado |
|---|---|
| Fundo translúcido, cantos arredondados e borda clara | `.dash-background` |
| Respiro de 8px entre a dock e a borda da tela | margem do `.dash-background` |
| Espaçamento compacto entre os ícones (≈6px) | `.dash-item-container` |
| Ponto de app em execução (4px, branco) | `.app-well-app-running-dot` |
| Ícones com sombra suave | `StIcon` / `.overview-icon` |
| Hover discreto, sem o quadrado cinza do GNOME | `.overview-icon:hover` |
| Botão de aplicativos com hover arredondado | `.show-apps` |
| Separador translúcido | `.dash-separator` |
| Tooltip no formato de etiqueta do macOS | `.dash-label` |
| Prévia de janelas arredondada | `.dashtodock-app-well-preview-menu-item` |

O arquivo é **acrescentado** ao `stylesheet.css` da extensão (entre marcadores),
e não substitui o original — o layout do dash-to-dock continua intacto.

> O CSS do dash-to-dock usa seletores muito específicos
> (`#dashtodockContainer.dashtodock #dash .dash-background`), então as regras
> do WhiteSur repetem a mesma estrutura para vencer o cascateamento.

#### 4.2 Animações (JavaScript)

A dock nativa **não tem** magnificação — o dash-to-dock não implementa zoom no
hover. O que existia era o código da extensão `macos-dock-extension`.

O módulo `dock-theme/whitesur-magnification.js` foi portado para:

1. encontrar a dock pronta na tela (`dashtodockContainer`);
2. localizar a fileira de ícones;
3. a 60 fps, ler a posição do ponteiro e interpolar a escala de cada ícone
   (suavização 0.25, pivô na borda da tela, escala máxima 1.55).

O botão de aplicativos fica travado em escala 1.0, como no macOS.

Ele é conectado na extensão com um patch pequeno no `extension.js`:

```js
const __whitesurOriginalEnable = ZorinDashExtension.prototype.enable;
const __whitesurOriginalDisable = ZorinDashExtension.prototype.disable;
```

#### 4.3 Preferências nativas ajustadas

| Chave | Valor | Efeito |
|---|---|---|
| `apply-custom-theme` | `true` | A extensão usa o `stylesheet.css` (o nosso) em vez do estilo do shell |
| `custom-theme-shrink` | `false` | Dock em tamanho cheio, sem encolher |
| `running-indicator-style` | `DOTS` | Indicador de app em execução no formato de ponto |
| `custom-theme-running-dots-color` | `#ffffff` | Cor do ponto |
| `custom-theme-running-dots-border-width` | `0` | Sem borda no ponto |
| `animation-time` | `0.25` | Animação de mostrar/esconder a dock |

Chaves que não existirem na versão instalada são ignoradas: o script consulta
`gsettings list-keys` antes de alterar qualquer coisa.

#### 4.4 Backup e como desfazer

Antes de qualquer alteração, o script guarda o estado original em:

```
~/.local/share/whitesur-custom/backups/dock/<nome-da-extensão>/
├── manifest.txt          # caminho da extensão + data
├── stylesheet.css.orig   # stylesheet original
├── extension.js.orig     # extension.js original
└── gsettings.txt         # valores anteriores das preferências
```

Para desfazer:

```bash
./dock-theme/restore.sh
```

O `restore.sh` remove o bloco que o pacote adicionou (preservando
atualizações do Zorin) e, se preciso, devolve o arquivo original do backup.
As preferências também voltam ao valor anterior.

O `./install.sh --uninstall` faz a mesma restauração, junto com a remoção do
tema e dos ícones.

#### Reaplicar após atualizar o Zorin

Atualizações do sistema podem sobrescrever o `stylesheet.css` e o
`extension.js` da extensão. Basta rodar de novo:

```bash
./install.sh --dock
```

E sair/entar na sessão — no Wayland, `Alt+F2 → r` não recarrega o shell, e os
módulos ES do GNOME ficam em cache mesmo depois de desabilitar/habilitar a
extensão.

### 5. Super abre a grade de aplicativos

Em vez das **Atividades**, a tecla **Super** passa a abrir a **grade de
aplicativos**.

**Por que não dá para resolver só com `gsettings`:** o shell registra a tecla
Super com o keybinding `toggle-overview`, cujo handler é fixo no código do
GNOME Shell (`js/ui/overview.js`):

```js
Main.wm.addKeybinding(
    'toggle-overview',
    new Gio.Settings({schema_id: 'org.gnome.desktop.wm.keybindings'}),
    Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
    Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW,
    this.toggle.bind(this));      // ← toggle() sempre abre as Atividades
```

A grade de aplicativos é outro estado do overview (`Overview.showApps()`), que
só existe em código — nenhuma chave de `gsettings` troca esse comportamento.

**Solução:** a extensão `super-app-grid/` remove o handler original e
registra o mesmo keybinding com um handler próprio:

| Situação | Antes | Depois |
|---|---|---|
| Super (overview fechado) | Atividades | **grade de aplicativos** |
| Super (overview aberto) | fecha | fecha |

O mesmo vale para o **botão "Atividades"** do painel superior, que pode ser
desligado com:

```bash
gsettings set org.gnome.shell.extensions.super-app-grid override-activities-button false
```

Ao desabilitar a extensão em Extensões, o comportamento original (Atividades)
volta automaticamente.

```bash
./install.sh --super
```

---

## Estrutura do repositório

```
WhiteSur-custom/
├── install.sh                 # instalador único (tema + ícones + dock)
├── LICENSE                    # licenças de todos os componentes
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
├── dock-theme/                # tema macOS para a dock nativa do Zorin
│   ├── stylesheet.css         # o visual (portado da extensão antiga)
│   ├── whitesur-magnification.js  # a animação de zoom no hover
│   ├── apply.sh               # aplica (com backup)
│   ├── restore.sh             # desfaz
│   ├── LICENSE                # MIT, com os créditos da obra original
│   └── README.md
├── super-app-grid/            # extensão que troca o comportamento do Super
│   ├── metadata.json
│   ├── extension.js
│   ├── schemas/
│   └── README.md
└── macos-dock-extension/      # referência: a extensão antiga, não é instalada
    ├── README.md              # como surgiu o patch e como atualizá-lo
    ├── patches.patch          # diff contra o upstream
    ├── metadata.json
    ├── extension.js
    ├── prefs.js
    ├── stylesheet.css
    ├── lib/
    └── schemas/
```

A pasta `macos-dock-extension/` **não é mais instalada** — ela fica no
repositório apenas como referência do visual e das animações que foram
portados para `dock-theme/`. O `install.sh` remove a extensão da máquina, caso
ela esteja instalada de versões anteriores do pacote.

---

## Testado em

| Item | Versão |
|---|---|
| Distribuição | Zorin OS 18.1 |
| GNOME Shell | 46.0 (Wayland) |

---

## Créditos e licença

Este repositório é um pacote agregador: cada componente tem sua própria
licença, preservada na pasta correspondente. O mapa completo está no
[`LICENSE`](LICENSE) da raiz.

| Componente | Projeto | Licença | Arquivo |
|---|---|---|---|
| `gtk-theme/` | WhiteSur GTK Theme — Vince Liuice | MIT | `gtk-theme/COPYING` |
| `icon-theme/` | WhiteSur Icon Theme — Vince Liuice | GPL-3.0 | `icon-theme/COPYING` |
| `macos-dock-extension/` | MacOS Dock — vinnytherobot | MIT | `macos-dock-extension/LICENSE` |
| `dock-theme/` | MacOS Dock (port) — vinnytherobot | MIT | `dock-theme/LICENSE` |
| `super-app-grid/` | WhiteSur Custom (código próprio) | MIT | `LICENSE` |
| `install.sh` | WhiteSur Custom (código próprio) | MIT | `LICENSE` |

As licenças originais estão preservadas e os cabeçalhos de copyright foram
mantidos nos arquivos derivados — inclusive nos de `dock-theme/`, que são
portas da extensão MacOS Dock.

> Como o pacote inclui `icon-theme/` (GPL-3.0), a **distribuição agregada**
> observa os termos da GPL-3.0; as partes MIT permanecem MIT para seus
> autores originais.

Créditos:

- **WhiteSur GTK Theme** — Vince Liuice —
  [vinceliuice/WhiteSur-gtk-theme](https://github.com/vinceliuice/WhiteSur-gtk-theme) — MIT
- **WhiteSur Icon Theme** — Vince Liuice —
  [vinceliuice/WhiteSur-icon-theme](https://github.com/vinceliuice/WhiteSur-icon-theme) — GPL-3.0
- **MacOS Dock** — vinnytherobot —
  [vinnytherobot/MacOSDock](https://github.com/vinnytherobot/MacOSDock) — MIT
- **dash-to-dock** — micheleg —
  [micheleg/dash-to-dock](https://github.com/micheleg/dash-to-dock) — GPL-2.0+
  (as folhas de estilo da dock adaptadas já vêm no upstream do WhiteSur, em
  `gtk-theme/other/dash-to-dock/`)
