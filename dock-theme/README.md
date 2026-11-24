# dock-theme — tema macOS para a dock nativa do Zorin OS

Este diretório aplica o visual e as animações da antiga extensão
`macos-dock-extension` **por cima da dock que já vem do Zorin OS**, sem
substituir a dock do sistema.

---

## Como funciona

A dock do Zorin OS é a extensão **Zorin Dash** (um fork do `dash-to-dock`),
instalada em:

```
/usr/share/gnome-shell/extensions/zorin-dash@zorinos.com
```

O `apply.sh` faz quatro coisas:

| Passo | O que faz | Arquivo alterado |
|---|---|---|
| 1 | Faz o backup do arquivo original | `stylesheet.css`, `extension.js` |
| 2 | Acrescenta o tema macOS | `stylesheet.css` |
| 3 | Instala o módulo de magnificação e o conecta na extensão | `extension.js` + `whitesur-magnification.js` |
| 4 | Ajusta as animações/indicadores nativos | `gsettings` do schema da dock |

Os backups ficam em:

```
~/.local/share/whitesur-custom/backups/dock/<nome-da-extensão>/
├── manifest.txt          # caminho da extensão + data
├── stylesheet.css.orig   # stylesheet original
├── extension.js.orig     # extension.js original
└── gsettings.txt         # valores anteriores das preferências
```

### Desfazer

```bash
./dock-theme/restore.sh
```

O `restore.sh` remove o bloco que o pacote adicionou (mantendo atualizações do
Zorin) e, se necessário, devolve o arquivo original do backup. As preferências
também voltam ao valor anterior.

---

## Conteúdo

| Arquivo | Função |
|---|---|
| `stylesheet.css` | O visual macOS (fundo translúcido, cantos arredondados, espaçamento, pontinho de app em execução, tooltip, separador, botão de aplicativos). |
| `whitesur-magnification.js` | A animação de zoom dos ícones no hover (a "magnificação" da extensão original). |
| `apply.sh` | Aplica tudo, com backup. |
| `restore.sh` | Desfaz tudo. |
| `LICENSE` | MIT, com os créditos da obra original. |

---

## Detalhes técnicos

### Por que o CSS é "colado" no stylesheet da extensão

O GNOME Shell carrega automaticamente o `stylesheet.css` que fica na pasta da
extensão. Em vez de sobrescrever o arquivo (o que quebraria o layout do
dash-to-dock), o bloco do WhiteSur é **acrescentado ao final**, entre marcadores:

```css
/* >>> WhiteSur Custom Dock Theme >>> */
...
/* <<< WhiteSur Custom Dock Theme <<< */
```

Assim o `restore.sh` consegue remover só o que foi nosso.

### Especificidade

O CSS do dash-to-dock usa seletores muito específicos, como:

```css
#dashtodockContainer.dashtodock #dash .dash-background { ... }
```

Por isso as regras do WhiteSur repetem a mesma estrutura de seletores — sem
isso, o upstream venceria o cascateamento.

### A magnificação

A dock nativa **não tem** magnificação (o dash-to-dock não implementa zoom no
hover). O que existia era o código da extensão `macos-dock-extension`, que
fazia o próprio controle de escala dos ícones.

O módulo `whitesur-magnification.js` foi portado para:

1. encontrar a dock já pronta na tela (`dashtodockContainer`);
2. localizar a fileira de ícones;
3. a 60 fps, ler a posição do ponteiro e interpolar a escala de cada ícone
   (fator de suavização 0.25, pivô na borda da tela, escala máxima 1.55).

O botão de aplicativos fica travado em 1.0, como no macOS.

O módulo é conectado na extensão por um patch pequeno no `extension.js`:

```js
const __whitesurOriginalEnable = ZorinDashExtension.prototype.enable;
...
```

Se a classe da extensão não for reconhecida, o script cai num método
alternativo que injeta as chamadas dentro de `enable()`/`disable()`.

### Preferências nativas ajustadas

| Chave | Valor | Efeito |
|---|---|---|
| `apply-custom-theme` | `true` | Faz a extensão usar o `stylesheet.css` (o nosso) em vez do estilo do shell |
| `custom-theme-shrink` | `false` | Dock em tamanho cheio, sem encolher |
| `running-indicator-style` | `DOTS` | Indicador de app em execução no formato de ponto (macOS) |
| `custom-theme-running-dots-color` | `#ffffff` | Cor do ponto |
| `custom-theme-running-dots-border-width` | `0` | Sem borda no ponto |
| `animation-time` | `0.25` | Animação de mostrar/esconder a dock |

Chaves que não existirem na versão instalada são simplesmente ignoradas —
o `apply.sh` consulta `gsettings list-keys` antes de alterar qualquer coisa.

---

## Licença

Esta pasta é obra derivada da extensão **MacOS Dock**
(<https://github.com/vinnytherobot/MacOSDock>, MIT — Copyright (c) 2026
vinnytherobot). O texto da licença e os créditos estão em `LICENSE`, e os
cabeçalhos de copyright foram mantidos em `stylesheet.css` e em
`whitesur-magnification.js`, como o MIT exige.

---

## Reaplicar após atualizar o Zorin

Atualizações do sistema podem sobrescrever o `stylesheet.css` e o
`extension.js` da extensão. Basta rodar de novo:

```bash
./install.sh --dock
```

E sair/entar na sessão (no Wayland, `Alt+F2 → r` não recarrega o shell, e os
módulos ES do GNOME ficam em cache mesmo depois de desabilitar/habilitar a
extensão).
