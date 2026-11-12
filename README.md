# WhiteSur Custom — tema GTK/Shell + ícones

Pacote pessoal do [WhiteSur GTK Theme](https://github.com/vinceliuice/WhiteSur-gtk-theme)
e do [WhiteSur Icon Theme](https://github.com/vinceliuice/WhiteSur-icon-theme)
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
3. Os raios dos menus do **Blur my Shell**, se a extensão estiver instalada.

Ao terminar, selecione o tema e os ícones em **Ajustes → Aparência**.

### Opções

| Comando | O que faz |
|---|---|
| `./install.sh` | Instala tema + ícones |
| `./install.sh --theme` | Instala apenas o tema GTK/Shell |
| `./install.sh --icons` | Instala apenas os ícones |
| `./install.sh --uninstall` | Remove tema e ícones |
| `./install.sh --help` | Mostra a ajuda |

### Requisitos

- `sassc` — compila o tema (o instalador tenta instalar automaticamente);
- `glib-compile-resources` — parte do `glib2.0`;
- GNOME Shell 46+ (testado em Zorin OS 18.1, GNOME Shell 46.0, Wayland).

> Se `sassc` não estiver disponível e a instalação automática falhar:
> `sudo apt install sassc`

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
| Painel de resultados | branco 10% | **preto 55%** + borda branca 10% + sombra |
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

---

## Estrutura do repositório

```
WhiteSur-custom/
├── install.sh          # instalador único (tema + ícones + Blur)
├── README.md           # este arquivo
├── gtk-theme/          # WhiteSur GTK Theme (com os ajustes)
│   ├── install.sh
│   ├── libs/
│   ├── src/
│   └── other/
└── icon-theme/         # WhiteSur Icon Theme
    ├── install.sh
    ├── src/
    ├── colors/
    ├── links/
    ├── bold/
    ├── alternative/
    └── plasma/
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
