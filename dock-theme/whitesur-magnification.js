/* ==========================================================================
   WhiteSur Custom — magnificação estilo macOS para a dock nativa do Zorin
   ==========================================================================

   Copyright (c) 2026 WhiteSur Custom contributors
   Copyright (c) 2026 vinnytherobot (MacOS Dock)

   Obra derivada de macos-dock-extension/lib/magnification.js, da extensão
   MacOS Dock (https://github.com/vinnytherobot/MacOSDock), sob licença MIT.
   Veja o arquivo LICENSE desta pasta.

   Este módulo é carregado dentro da extensão da dock nativa do Zorin
   (Zorin Dash / dash-to-dock) e aplica nela o efeito de "zoom" que a
   extensão macos-dock-extension fazia na dock própria: os ícones crescem
   suavemente quando o ponteiro passa por cima.

   Ele não substitui a dock do sistema — apenas trabalha nos ícones que já
   existem, do mesmo jeito que a extensão original fazia.

   Código original (referência): macos-dock-extension/lib/magnification.js
   ========================================================================== */

import GLib from 'gi://GLib';
import St from 'gi://St';

const MIN_SCALE = 1.0;
const LERP_FACTOR = 0.25;        // suavização por tick
const MAX_SCALE = 1.55;          // tamanho máximo do ícone no hover
const FALLOFF_DISTANCE = 110;     // alcance do efeito, em px
const FRAMERATE = 60;
const POINTER_MARGIN = 30;        // tolerância fora da fileira de ícones

/* Classes de estilo dos ícones da dock nativa. */
const ICON_STYLE_CLASSES = ['app-well-app', 'show-apps'];

/* Slots que nunca crescem: o botão de aplicativos continua fixo, como no
   macOS e como era na extensão original. */
const NO_MAGNIFICATION_STYLE_CLASSES = ['show-apps'];

function hasStyleClass(actor, name) {
    return typeof actor?.has_style_class_name === 'function' &&
           actor.has_style_class_name(name);
}

function getChildren(actor) {
    try {
        return actor.get_children() ?? [];
    } catch (error) {
        return [];
    }
}

/** Procura um ator pelo nome, em profundidade. */
function findByName(actor, name) {
    if (!actor)
        return null;

    if (actor.name === name)
        return actor;

    for (const child of getChildren(actor)) {
        const found = findByName(child, name);
        if (found)
            return found;
    }

    return null;
}

/** Procura o contêiner que guarda os ícones da dock. */
function findIconsContainer(root) {
    if (!root)
        return null;

    let result = null;

    const walk = actor => {
        if (result)
            return;

        for (const child of getChildren(actor)) {
            const hasIcon = getChildren(child).some(grandChild =>
                ICON_STYLE_CLASSES.some(name => hasStyleClass(grandChild, name)));

            if (hasIcon) {
                result = child;
                return;
            }

            walk(child);
        }
    };

    walk(root);

    return result;
}

/**Raiz da dock nativa ("dashtodockContainer"). */
function findDockRoot() {
    return findByName(global.stage, 'dashtodockContainer');
}

/**
 * Aplica a magnificação nos ícones de um contêiner.
 *
 * O laço é o mesmo da extensão original: lê a posição do ponteiro, calcula a
 * escala de cada ícone a partir da distância até o ícone focal e interpola
 * o valor a cada tick (60 fps), o que dá o movimento suave do macOS.
 */
export class Magnification {
    constructor(container, options = {}) {
        this._container = container;
        this._enabled = true;
        this._maxScale = options.maxScale ?? MAX_SCALE;
        this._falloffDistance = options.falloffDistance ?? FALLOFF_DISTANCE;
        this._framerate = options.framerate ?? FRAMERATE;
        this._pollId = null;
        this._scales = new Map();
    }

    start() {
        this._startPoll();
    }

    stop() {
        this._stopPoll();
        this._resetAll();
        this._scales.clear();
    }

    _startPoll() {
        this._stopPoll();

        const interval = Math.round(1000 / this._framerate);

        this._pollId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, interval, () => {
            this._update();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _stopPoll() {
        if (this._pollId !== null) {
            GLib.source_remove(this._pollId);
            this._pollId = null;
        }
    }

    _getIcons() {
        const icons = [];

        for (const child of getChildren(this._container)) {
            if (ICON_STYLE_CLASSES.some(name => hasStyleClass(child, name)))
                icons.push(child);
        }

        /* Fallback: se a extensão usar outras classes, usa os botões da fileira. */
        if (icons.length === 0) {
            for (const child of getChildren(this._container)) {
                if (child instanceof St.Button && !hasStyleClass(child, 'dash-separator'))
                    icons.push(child);
            }
        }

        return icons;
    }

    /** Os ícones crescem para longe da borda da tela (cima na dock de baixo). */
    _getPivotY() {
        const container = this._container;

        if (hasStyleClass(container, 'bottom'))
            return 1.0;
        if (hasStyleClass(container, 'top'))
            return 0.0;

        return 0.5;
    }

    _canMagnify(actor) {
        return !NO_MAGNIFICATION_STYLE_CLASSES.some(name => hasStyleClass(actor, name));
    }

    _update() {
        if (!this._enabled || !this._container)
            return;

        const icons = this._getIcons();

        if (icons.length === 0) {
            this._resetAll();
            return;
        }

        const [px, py] = global.get_pointer();
        const [cx, cy] = this._container.get_position();
        const [cw, ch] = this._container.get_size();

        const localX = px - cx;
        const localY = py - cy;

        if (localY < -POINTER_MARGIN || localY > ch + POINTER_MARGIN ||
            localX < -POINTER_MARGIN || localX > cw + POINTER_MARGIN) {
            this._resetAll();
            return;
        }

        /* Pivot: os ícones crescem a partir da borda da tela. */
        const pivotY = this._getPivotY();

        for (const icon of icons) {
            const pivot = icon.get_pivot_point();

            if (pivot[0] !== 0.5 || pivot[1] !== pivotY)
                icon.set_pivot_point(0.5, pivotY);
        }

        /* Ícone mais próximo do ponteiro. */
        let focal = icons[0];
        let bestDistance = Infinity;

        for (const icon of icons) {
            const [ix] = icon.get_position();
            const [iw] = icon.get_size();
            const distance = Math.abs(localX - (ix + iw / 2));

            if (distance < bestDistance) {
                bestDistance = distance;
                focal = icon;
            }
        }

        if (bestDistance > this._falloffDistance * 1.5) {
            this._resetAll();
            return;
        }

        const [fx] = focal.get_position();
        const [fw] = focal.get_size();
        const focalCenter = fx + fw / 2;

        for (const icon of icons) {
            const [ix] = icon.get_position();
            const [iw] = icon.get_size();
            const distance = Math.abs(ix + iw / 2 - focalCenter);
            const t = Math.max(0, 1 - distance / this._falloffDistance);
            const smooth = t * t * (3 - 2 * t);
            const target = this._canMagnify(icon)
                ? MIN_SCALE + (this._maxScale - MIN_SCALE) * smooth
                : MIN_SCALE;

            const previous = this._scales.get(icon) ?? MIN_SCALE;
            const next = previous + (target - previous) * LERP_FACTOR;

            this._scales.set(icon, next);
            icon.scale_x = next;
            icon.scale_y = next;
        }
    }

    /** Volta todos os ícones para o tamanho natural, sem interpolateção. */
    _resetAll() {
        for (const [icon, scale] of this._scales) {
            if (Math.abs(scale - MIN_SCALE) < 0.001)
                continue;

            const next = scale + (MIN_SCALE - scale) * LERP_FACTOR;

            this._scales.set(icon, next);
            icon.scale_x = next;
            icon.scale_y = next;
        }
    }
}

/**
 * Ponto de entrada usado pelo patch aplicado em extension.js.
 *
 * A dock pode ainda não existir no momento em que a extensão é habilitada,
 * então a busca é refeita algumas vezes antes de desistir.
 */
export class WhitesurMagnification {
    constructor() {
        this._magnification = null;
        this._retryId = null;
    }

    static enable() {
        const instance = new WhitesurMagnification();
        instance.enable();
        return instance;
    }

    enable() {
        if (this._start())
            return this;

        this._retryId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
            if (this._start()) {
                this._retryId = null;
                return GLib.SOURCE_REMOVE;
            }

            return GLib.SOURCE_CONTINUE;
        });

        return this;
    }

    disable() {
        if (this._retryId !== null) {
            GLib.source_remove(this._retryId);
            this._retryId = null;
        }

        if (this._magnification) {
            this._magnification.stop();
            this._magnification = null;
        }
    }

    _start() {
        const root = findDockRoot();
        const container = findIconsContainer(root);

        if (!container)
            return false;

        this._magnification = new Magnification(container);
        this._magnification.start();

        return true;
    }
}
