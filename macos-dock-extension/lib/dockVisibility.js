import Clutter from "gi://Clutter";
import GLib from "gi://GLib";
import St from "gi://St";
import * as Main from "resource:///org/gnome/shell/ui/main.js";
import { SignalManager } from "./signalManager.js";
/**
 * Reveals the dock through a reactive screen-edge actor and hides it after a
 * debounced pointer check. While shown, the dock stays visible under the
 * pointer and while its preview or context menu is active.
 *
 * Intellihide overlap changes are routed through the pointer-position check
 * so that a maximized window behind the dock does not cause a show/hide
 * feedback loop.
 *
 * Animations use translation_x/translation_y instead of modifying the
 * container's layout-owned position, avoiding conflicts with
 * DockManager._updatePosition().
 */
export class DockVisibility {
    _signals;
    _container;
    _intellihide;
    _monitor = null;
    _animationDuration;
    _showThreshold;
    _dockHeight;
    _magnificationScale;
    _edge;
    _dockBounds = null;
    _previewPopup = null;
    _contextMenuActor = null;
    _edgeActivator = null;
    _pointerX = 0;
    _pointerY = 0;
    _dragActive = false;
    _shown = false;
    _restingTranslationX = 0;
    _restingTranslationY = 0;
    _hideSourceId = null;
    _animationSourceId = null;
    _animationStartTime = 0;
    _animationFromX = 0;
    _animationFromY = 0;
    _animationFromOpacity = 0;
    _animationToX = 0;
    _animationToY = 0;
    _animationToOpacity = 0;
    constructor(container, intellihide, dockHeight, animationDuration = 200, showThreshold = 25, edge = 0, magnificationScale = 1.0) {
        this._signals = new SignalManager();
        this._container = container;
        this._intellihide = intellihide;
        this._animationDuration = animationDuration;
        this._showThreshold = showThreshold;
        this._dockHeight = dockHeight;
        this._magnificationScale = magnificationScale;
        this._edge = edge;
    }
    setPreviewPopup(popup) {
        this._previewPopup = popup;
    }
    setContextMenuActor(actor) {
        this._contextMenuActor = actor;
    }
    /**
     * Hold the dock in its shown state while a drag-reorder is in progress so
     * the delayed auto-hide check cannot slide the dock away underneath the pointer.
     */
    setDragActive(active) {
        if (active === this._dragActive)
            return;
        this._dragActive = active;
        if (active) {
            this._show();
        }
        else {
            this._updatePointerState();
        }
    }
    setEdge(edge) {
        this._edge = edge;
        this._updateEdgeActivatorBounds();
    }
    updateDockBounds(x, y, width, height) {
        this._monitor = Main.layoutManager.primaryMonitor;
        this._dockBounds = { x, y, width, height };
        this._updateEdgeActivatorBounds();
    }
    isShown() {
        return this._shown;
    }
    isAnimating() {
        return this._animationSourceId !== null;
    }
    isHidden() {
        return !this._shown;
    }
    updateShownY(_y) { }
    updateAnimationDuration(duration) {
        this._animationDuration = Math.max(0, Math.min(1000, duration));
    }
    start() {
        this._cancelHide();
        this._cancelAnimation();
        this._monitor = Main.layoutManager.primaryMonitor;
        if (!this._monitor) {
            console.error("[macos-dock] No primary monitor available");
            return;
        }
        this._container.visible = false;
        this._container.opacity = 0;
        this._shown = false;
        this._dragActive = false;
        this._restingTranslationX = 0;
        this._restingTranslationY = 0;
        const [offsetX, offsetY] = this._getSlideOffset();
        this._container.translation_x = offsetX;
        this._container.translation_y = offsetY;
        this._edgeActivator = new St.Widget({
            name: "macos-dock-edge-activator",
            reactive: true,
            track_hover: true,
            opacity: 0,
        });
        Main.layoutManager.addChrome(this._edgeActivator, {
            affectsStruts: false,
            trackFullscreen: false,
        });
        this._updateEdgeActivatorBounds();
        this._signals.connect(this._edgeActivator, "enter-event", () => {
            const [x, y] = global.get_pointer();
            this._pointerX = x;
            this._pointerY = y;
            this._show();
            return Clutter.EVENT_PROPAGATE;
        });
        this._signals.connect(this._edgeActivator, "motion-event", (_actor, event) => {
            const [x, y] = event.get_coords();
            this._pointerX = x;
            this._pointerY = y;
            this._show();
            return Clutter.EVENT_PROPAGATE;
        });
        this._signals.connect(this._container, "enter-event", () => {
            const [x, y] = global.get_pointer();
            this._pointerX = x;
            this._pointerY = y;
            this._updatePointerState();
            return Clutter.EVENT_PROPAGATE;
        });
        this._signals.connect(this._container, "motion-event", (_actor, event) => {
            const [x, y] = event.get_coords();
            this._pointerX = x;
            this._pointerY = y;
            this._updatePointerState();
            return Clutter.EVENT_PROPAGATE;
        });
        this._signals.connect(this._container, "leave-event", () => {
            const [x, y] = global.get_pointer();
            this._pointerX = x;
            this._pointerY = y;
            this._updatePointerState();
            return Clutter.EVENT_PROPAGATE;
        });
        this._intellihide.start((overlap) => {
            this._onIntellihideChanged(overlap);
        });
        this._signals.connect(global.stage, "motion-event", (_actor, event) => {
            const [px, py] = event.get_coords();
            this._pointerX = px;
            this._pointerY = py;
            this._updatePointerState();
            return Clutter.EVENT_PROPAGATE;
        });
        const [x, y] = global.get_pointer();
        this._pointerX = x;
        this._pointerY = y;
        this._updatePointerState();
    }
    stop() {
        this._cancelHide();
        this._signals.disconnectAll();
        if (this._edgeActivator) {
            Main.layoutManager.removeChrome(this._edgeActivator);
            this._edgeActivator.destroy();
            this._edgeActivator = null;
        }
        this._cancelAnimation();
        this._dragActive = false;
        this._container.translation_x = 0;
        this._container.translation_y = 0;
        this._container.visible = true;
        this._container.opacity = 255;
    }
    _updatePointerState() {
        if (!this._monitor)
            return;
        // The dock stays up for the whole duration of a drag-reorder; hiding it
        // mid-drag would pull the drop target out from under the pointer.
        if (this._dragActive) {
            this._cancelHide();
            return;
        }
        if (this._isPointerInPopupOrMenu()) {
            this._cancelHide();
            return;
        }
        if (this._isPointerInEdgeZone()) {
            this._show();
            return;
        }
        if (this._shown && this._isPointerInDockRegion()) {
            this._cancelHide();
            return;
        }
        if (this._shown)
            this._scheduleHide();
    }
    _isPointerInPopupOrMenu() {
        if (this._previewPopup?.isVisible()) {
            const bounds = this._previewPopup.getBounds();
            if (bounds &&
                this._pointerX >= bounds.x &&
                this._pointerX <= bounds.x + bounds.width &&
                this._pointerY >= bounds.y &&
                this._pointerY <= bounds.y + bounds.height) {
                return true;
            }
        }
        if (this._contextMenuActor?.mapped) {
            const [x, y] = this._contextMenuActor.get_transformed_position();
            const [width, height] = this._contextMenuActor.get_size();
            return (this._pointerX >= x &&
                this._pointerX <= x + width &&
                this._pointerY >= y &&
                this._pointerY <= y + height);
        }
        return false;
    }
    _isPointerInDockRegion() {
        return this._isPointerInDockBounds() || this._isPointerOverDockActor();
    }
    _scheduleHide() {
        if (this._hideSourceId !== null)
            return;
        this._hideSourceId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 120, () => {
            this._hideSourceId = null;
            const [x, y] = global.get_pointer();
            this._pointerX = x;
            this._pointerY = y;
            if (this._shown &&
                !this._dragActive &&
                !this._isPointerInPopupOrMenu() &&
                !this._isPointerInEdgeZone() &&
                !this._isPointerInDockRegion()) {
                this._hide();
            }
            return GLib.SOURCE_REMOVE;
        });
    }
    _cancelHide() {
        if (this._hideSourceId === null)
            return;
        GLib.Source.remove(this._hideSourceId);
        this._hideSourceId = null;
    }
    /**
     * Whether the pointer is inside the screen-edge activation zone.
     * The dock only shows when the pointer enters this narrow zone.
     */
    _isPointerInEdgeZone() {
        if (!this._monitor)
            return false;
        switch (this._edge) {
            case 0:
                return this._pointerY >= this._monitor.y + this._monitor.height - this._showThreshold;
            case 1:
                return this._pointerX <= this._monitor.x + this._showThreshold;
            case 2:
                return this._pointerX >= this._monitor.x + this._monitor.width - this._showThreshold;
            case 3:
                return this._pointerY <= this._monitor.y + this._showThreshold;
        }
        return false;
    }
    /**
     * Whether the pointer is over the dock's resting bounds extended by the
     * magnification envelope. Used to keep the dock visible while the pointer
     * is on the dock itself.
     */
    _isPointerInDockBounds() {
        const bounds = this._dockBounds;
        if (!bounds)
            return false;
        const magnificationExtra = Math.max(0, this._dockHeight * (this._magnificationScale - 1));
        const alongDockExtra = magnificationExtra / 2;
        switch (this._edge) {
            case 0: {
                return (this._pointerX >= bounds.x - alongDockExtra &&
                    this._pointerX <= bounds.x + bounds.width + alongDockExtra &&
                    this._pointerY >= bounds.y - magnificationExtra &&
                    this._pointerY <= bounds.y + bounds.height);
            }
            case 1: {
                return (this._pointerX >= bounds.x &&
                    this._pointerX <= bounds.x + bounds.width + magnificationExtra &&
                    this._pointerY >= bounds.y - alongDockExtra &&
                    this._pointerY <= bounds.y + bounds.height + alongDockExtra);
            }
            case 2: {
                return (this._pointerX >= bounds.x - magnificationExtra &&
                    this._pointerX <= bounds.x + bounds.width &&
                    this._pointerY >= bounds.y - alongDockExtra &&
                    this._pointerY <= bounds.y + bounds.height + alongDockExtra);
            }
            case 3: {
                return (this._pointerX >= bounds.x - alongDockExtra &&
                    this._pointerX <= bounds.x + bounds.width + alongDockExtra &&
                    this._pointerY >= bounds.y &&
                    this._pointerY <= bounds.y + bounds.height + magnificationExtra);
            }
        }
        return false;
    }
    _isPointerOverDockActor() {
        const actor = global.stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, this._pointerX, this._pointerY);
        return actor === this._container || (actor !== null && this._container.contains(actor));
    }
    _updateEdgeActivatorBounds() {
        const monitor = this._monitor;
        const bounds = this._dockBounds;
        const activator = this._edgeActivator;
        if (!monitor || !bounds || !activator)
            return;
        const thickness = Math.max(2, this._showThreshold);
        switch (this._edge) {
            case 0:
                activator.set_position(bounds.x, monitor.y + monitor.height - thickness);
                activator.set_size(bounds.width, thickness);
                break;
            case 1:
                activator.set_position(monitor.x, bounds.y);
                activator.set_size(thickness, bounds.height);
                break;
            case 2:
                activator.set_position(monitor.x + monitor.width - thickness, bounds.y);
                activator.set_size(thickness, bounds.height);
                break;
            case 3:
                activator.set_position(bounds.x, monitor.y);
                activator.set_size(bounds.width, thickness);
                break;
        }
    }
    /**
     * Whether the pointer is anywhere in the interaction region (edge zone or
     * dock bounds). Used by the intellihide callback to keep the dock visible
     * while the pointer is near it.
     */
    _isPointerInInteractionRegion() {
        return (this._isPointerInPopupOrMenu() || this._isPointerInEdgeZone() || this._isPointerInDockRegion());
    }
    _show() {
        this._cancelHide();
        if (this._shown)
            return;
        this._shown = true;
        this._animateVisibility(true);
    }
    _hide() {
        if (!this._shown)
            return;
        this._shown = false;
        this._animateVisibility(false);
    }
    _animateVisibility(show) {
        this._cancelAnimation();
        this._container.visible = true;
        const [offsetX, offsetY] = this._getSlideOffset();
        this._animationFromX = this._container.translation_x;
        this._animationFromY = this._container.translation_y;
        this._animationFromOpacity = this._container.opacity;
        this._animationToX = show ? this._restingTranslationX : this._restingTranslationX + offsetX;
        this._animationToY = show ? this._restingTranslationY : this._restingTranslationY + offsetY;
        this._animationToOpacity = show ? 255 : 0;
        if (this._animationDuration === 0) {
            this._finishVisibilityAnimation(show);
            return;
        }
        this._animationStartTime = GLib.get_monotonic_time();
        this._animationSourceId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 16, () => {
            const elapsedMs = (GLib.get_monotonic_time() - this._animationStartTime) / 1000;
            const progress = Math.min(1, elapsedMs / this._animationDuration);
            const easedProgress = show ? 1 - (1 - progress) ** 2 : progress ** 2;
            this._container.translation_x =
                this._animationFromX + (this._animationToX - this._animationFromX) * easedProgress;
            this._container.translation_y =
                this._animationFromY + (this._animationToY - this._animationFromY) * easedProgress;
            this._container.opacity = Math.round(this._animationFromOpacity +
                (this._animationToOpacity - this._animationFromOpacity) * easedProgress);
            if (progress < 1)
                return GLib.SOURCE_CONTINUE;
            this._animationSourceId = null;
            this._finishVisibilityAnimation(show);
            return GLib.SOURCE_REMOVE;
        });
    }
    _finishVisibilityAnimation(show) {
        this._container.translation_x = this._animationToX;
        this._container.translation_y = this._animationToY;
        this._container.opacity = this._animationToOpacity;
        this._container.visible = show;
    }
    _cancelAnimation() {
        if (this._animationSourceId === null)
            return;
        GLib.Source.remove(this._animationSourceId);
        this._animationSourceId = null;
    }
    _getSlideOffset() {
        const slideDistance = 20;
        switch (this._edge) {
            case 0:
                return [0, slideDistance];
            case 1:
                return [-slideDistance, 0];
            case 2:
                return [slideDistance, 0];
            case 3:
                return [0, -slideDistance];
        }
        return [0, slideDistance];
    }
    _onIntellihideChanged(overlap) {
        if (this._dragActive)
            return;
        if (!overlap) {
            this._show();
            return;
        }
        if (this._shown && !this._isPointerInInteractionRegion()) {
            this._scheduleHide();
        }
    }
}
