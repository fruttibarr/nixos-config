import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "root:/"
import "root:/services"

// Drag on an empty part of the desktop to draw a terminal: a live outline
// follows the cursor, and on release a kitty window opens floating at
// exactly that rectangle. Right-click mid-drag cancels.
//
// Two surfaces per output:
//  - `catcher` on the Bottom layer (above the wallpaper, below every
//    window), so it only ever receives presses that land on empty desktop.
//    Wayland's implicit grab keeps the drag's motion events coming to it even
//    when the cursor crosses a window.
//  - `preview` on the Overlay layer with an empty input region, so the
//    outline is drawn above windows without ever intercepting clicks.
//
// Placement uses a Hyprland window rule keyed on a dedicated class rather
// than exec rules: exec rules match the launched PID, and `kitty -1` hands
// the window to the already-running shared kitty, so they would be ignored.
Scope {
    id: root

    readonly property bool enabled: HyprSettings.get("shell.draw.enabled")
    readonly property int grid: HyprSettings.get("shell.draw.grid")
    readonly property int minSize: HyprSettings.get("shell.draw.minSize")
    // Which held key turns a desktop drag into a terminal ("none" = any drag).
    readonly property string modifier: HyprSettings.get("shell.draw.modifier")

    // ---- modifier drags ----------------------------------------------------
    // The desktop layer can't see held modifiers (Wayland only reports them
    // to the keyboard-focused surface, and it never takes focus), and
    // SUPER+click is consumed by Hyprland's window-move bind before any
    // client sees it. So Hyprland reports the combo itself: hyprland.nix binds
    // <MOD> + mouse:272 to these global shortcuts as *non-consuming* extra
    // binds — window dragging is untouched. pressed = button down with the
    // key held; released = button up. Each screen's desktop layer knows (via
    // hover) whether the pointer is over empty desktop, and where.
    function beginModDrag(mod) {
        if (!enabled || modifier !== mod) return;
        for (const s of screens.instances)
            if (s.overDesktop) {
                s.begin(s.hoverX, s.hoverY);
                // The hover position is only as fresh as the last motion
                // event the desktop got (a warped pointer sends none), so
                // pin the start to Hyprland's own cursor position.
                cursorProc.target = s;
                cursorProc.running = true;
                return;
            }
    }
    Process {
        id: cursorProc
        property var target: null
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = cursorProc.target;
                if (!s || !s.pressed) return;
                try {
                    const p = JSON.parse(text);
                    s.sx = p.x - s.modelData.x;
                    s.sy = p.y - s.modelData.y;
                } catch (e) {}
            }
        }
    }
    function endModDrag() {
        for (const s of screens.instances)
            if (s.pressed) s.finish();
    }

    GlobalShortcut {
        name: "drawTerminalSuper"
        description: "Draw a terminal (SUPER + drag on empty desktop)"
        onPressed: root.beginModDrag("super")
        onReleased: root.endModDrag()
    }
    GlobalShortcut {
        name: "drawTerminalAlt"
        description: "Draw a terminal (ALT + drag on empty desktop)"
        onPressed: root.beginModDrag("alt")
        onReleased: root.endModDrag()
    }
    GlobalShortcut {
        name: "drawTerminalCtrl"
        description: "Draw a terminal (CTRL + drag on empty desktop)"
        onPressed: root.beginModDrag("ctrl")
        onReleased: root.endModDrag()
    }
    readonly property string drawnClass: "kitty-drawn"

    function snap(v) {
        return grid > 0 ? Math.round(v / grid) * grid : Math.round(v);
    }

    // Lua string literal (ASCII-only inputs here, so JSON quoting is valid Lua).
    function lua(s) {
        return JSON.stringify(String(s));
    }

    function spawn(gx, gy, w, h) {
        const cmd = `sh -c 'exec kitty -1 --class ${drawnClass} 2>>"$HOME/.cache/kitty.log"'`;
        const code =
            `hl.window_rule({ name = "quickshell-drawn-terminal", match = { class = ${lua("^" + drawnClass + "$")} }, ` +
            `float = true, size = ${lua(w + " " + h)}, move = ${lua(gx + " " + gy)} })\n` +
            `hl.exec_cmd(${lua(cmd)})`;
        Quickshell.execDetached(["hyprctl", "eval", code]);
    }

    Variants {
        id: screens
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            // Pointer is over empty desktop on this output (no window above).
            readonly property bool overDesktop: catcherArea.containsMouse
            readonly property real hoverX: catcherArea.mouseX
            readonly property real hoverY: catcherArea.mouseY

            function begin(x, y) {
                if (launching) return;
                pressed = true;
                drawing = false;
                sx = cx = x;
                sy = cy = y;
            }
            function track(x, y, w, h) {
                if (!pressed) return;
                cx = Math.max(0, Math.min(w, x));
                cy = Math.max(0, Math.min(h, y));
                // A small dead zone so plain clicks never start a drag.
                if (!drawing && Math.hypot(cx - sx, cy - sy) > 12) drawing = true;
            }

            // ---- drag state (monitor-local logical px) --------------------
            property bool pressed: false
            property bool drawing: false
            property bool launching: false
            property real sx: 0
            property real sy: 0
            property real cx: 0
            property real cy: 0

            readonly property real rx: root.snap(Math.min(sx, cx))
            readonly property real ry: root.snap(Math.min(sy, cy))
            readonly property real rw: root.snap(Math.max(sx, cx)) - rx
            readonly property real rh: root.snap(Math.max(sy, cy)) - ry
            readonly property bool bigEnough: rw >= root.minSize && rh >= root.minSize * 0.5

            function finish() {
                pressed = false;
                if (!drawing) return;
                if (!bigEnough) {
                    drawing = false;
                    return;
                }
                launching = true;
                root.spawn(modelData.x + rx, modelData.y + ry, rw, rh);
                launchTimeout.restart();
            }
            function cancel() {
                pressed = false;
                drawing = false;
                launching = false;
            }

            // Hold the outline until the window actually appears, so the
            // hand-off from preview to terminal is seamless.
            Connections {
                target: Hyprland
                function onRawEvent(event) {
                    if (perScreen.launching && event.name === "openwindow"
                        && event.data.split(",")[2] === root.drawnClass)
                        perScreen.cancel();
                }
            }
            Timer {
                id: launchTimeout
                interval: 2000
                onTriggered: perScreen.cancel()
            }

            PanelWindow {
                id: catcher
                screen: perScreen.modelData
                visible: root.enabled

                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.namespace: "quickshell-draw"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusiveZone: 0
                color: "transparent"
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                MouseArea {
                    id: catcherArea
                    anchors.fill: parent
                    // Hover keeps overDesktop/hoverX/hoverY current for
                    // modifier drags, which start from a global shortcut.
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: perScreen.drawing ? Qt.CrossCursor : Qt.ArrowCursor

                    // Plain-drag mode ("Nothing" held) only; modifier drags
                    // never reach here (Hyprland consumes SUPER+click).
                    onPressed: e => {
                        if (e.button === Qt.RightButton) {
                            if (perScreen.pressed) perScreen.cancel();
                            return;
                        }
                        if (root.modifier === "none") perScreen.begin(e.x, e.y);
                    }
                    onPositionChanged: e => perScreen.track(e.x, e.y, width, height)
                    // Plain-drag mode only. In a modifier drag the press still
                    // reaches this layer, and when `preview` grabs the pointer
                    // Qt sends a synthetic release here that would end the
                    // drag at once; modifier drags end via the shortcut's
                    // release (or trackArea's fallback) instead.
                    onReleased: e => {
                        if (e.button === Qt.LeftButton && perScreen.pressed && root.modifier === "none") perScreen.finish();
                    }
                }
            }

            PanelWindow {
                id: preview
                screen: perScreen.modelData
                visible: perScreen.pressed || perScreen.drawing || outline.opacity > 0.01

                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-draw-preview"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusiveZone: 0
                color: "transparent"
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                // Click-through, except during a modifier drag: then it takes
                // the pointer so the outline can follow the cursor across
                // windows (the button press went to Hyprland's bind, so there
                // is no implicit grab on the desktop layer to rely on).
                readonly property bool tracking: perScreen.pressed && root.modifier !== "none"
                mask: tracking ? fullInput : noInput
                Region { id: noInput }
                Region { id: fullInput; item: trackArea }

                MouseArea {
                    id: trackArea
                    anchors.fill: parent
                    enabled: preview.tracking
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.CrossCursor
                    onPositionChanged: e => perScreen.track(e.x, e.y, width, height)
                    onPressed: e => {
                        if (e.button === Qt.RightButton) perScreen.cancel();
                    }
                    // Fallback end in case the shortcut's release is missed.
                    onReleased: e => {
                        if (e.button === Qt.LeftButton && perScreen.pressed) perScreen.finish();
                    }
                }

                Rectangle {
                    id: outline
                    x: perScreen.rx
                    y: perScreen.ry
                    width: perScreen.rw
                    height: perScreen.rh
                    radius: Math.min(HyprSettings.get("decoration.rounding"), width / 2, height / 2)
                    readonly property color accent: perScreen.bigEnough ? Colors.primary : Theme.textFaint

                    color: Theme.alpha(accent, perScreen.launching ? 0.20 : 0.10)
                    border.width: 2
                    border.color: accent
                    opacity: perScreen.drawing ? 1 : 0
                    scale: perScreen.drawing ? 1 : 0.97
                    Behavior on opacity {
                        NumberAnimation { duration: 140 }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 160 }
                    }

                    // Faint inner grid when snapping is on, to show the steps.
                    Canvas {
                        anchors.fill: parent
                        anchors.margins: 2
                        visible: root.grid > 0 && perScreen.bigEnough
                        opacity: 0.18
                        // Canvas repaints on resize even while hidden, so both
                        // the trigger and the loops must be guarded: with
                        // grid = 0 the loops below would never terminate.
                        onWidthChanged: if (visible) requestPaint()
                        onHeightChanged: if (visible) requestPaint()
                        onVisibleChanged: if (visible) requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            if (root.grid <= 0) return;
                            ctx.strokeStyle = outline.accent;
                            ctx.lineWidth = 1;
                            for (let x = root.grid; x < width; x += root.grid) {
                                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                            }
                            for (let y = root.grid; y < height; y += root.grid) {
                                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                            }
                        }
                    }

                    // Size readout, centred while there's room for it.
                    Rectangle {
                        anchors.centerIn: parent
                        visible: parent.width > 150 && parent.height > 70
                        width: label.implicitWidth + 28
                        height: label.implicitHeight + 16
                        radius: height / 2
                        color: Theme.island

                        Column {
                            id: label
                            anchors.centerIn: parent
                            spacing: 1

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8
                                Glyph {
                                    text: perScreen.launching ? "󰑓" : "󰆍"
                                    size: 15
                                    color: outline.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                    RotationAnimation on rotation {
                                        running: perScreen.launching
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 800
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: perScreen.bigEnough
                                        ? `${Math.round(perScreen.rw)} × ${Math.round(perScreen.rh)}`
                                        : "Too small"
                                    color: Colors.text
                                    font.family: Theme.mono
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                            }
                            // Rough terminal grid for an 11pt monospace cell
                            // (~8.8 × 18 px) inside kitty's 10 px padding.
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: perScreen.bigEnough
                                text: perScreen.launching ? "opening…"
                                    : `≈ ${Math.max(1, Math.floor((perScreen.rw - 20) / 8.8))} cols × ${Math.max(1, Math.floor((perScreen.rh - 20) / 18))} rows`
                                color: Theme.textSoft
                                font.family: Theme.sans
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }
}
