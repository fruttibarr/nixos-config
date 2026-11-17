import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "root:/"
import "root:/services"
import "root:/widgets"

// The dynamic island. One shape, five states — it never hands off to a
// separate popup; the launcher and control center are the island itself,
// grown downwards:
//
//   idle      resting pill: workspaces · clock · live-activity ears
//   peek      hover / track change: media controls, status, date
//   osd       volume / brightness level
//   launcher  app search            (SUPER+D, right-click the island)
//   control   control center        (SUPER+A, click the island)
//   settings  Hyprland settings     (SUPER+I)
//   wallpapers wallpaper switcher   (SUPER+SHIFT+W)
//   command   run a command in kitty (/ on an empty workspace)
Scope {
    id: scope

    // ---- "/" on an empty workspace -----------------------------------------
    // hyprland.nix binds a bare slash to this as a *non-consuming* global, so
    // the key still reaches whatever is focused. It only morphs the island
    // when there's nothing to type into: the focused workspace has no
    // windows, no window anywhere is focused (e.g. an open special
    // workspace), and the island isn't already open (its own text fields
    // receive the "/" as normal).
    function workspaceEmpty() {
        const ws = Hyprland.focusedWorkspace;
        if (!ws || ws.toplevels.values.length > 0) return false;
        // Only a focused window on a special workspace counts: `activated`
        // goes stale on a normal window after switching to an empty
        // workspace, so checking every toplevel blocked "/" everywhere.
        return !Hyprland.toplevels.values.some(t =>
            t.activated && (t.workspace?.name ?? "").startsWith("special"));
    }
    GlobalShortcut {
        name: "commandSlash"
        description: "Run a command (/ on an empty workspace)"
        onPressed: {
            if (ShellState.mode !== "" || !scope.workspaceEmpty()) return;
            ShellState.toggle("command", Hyprland.focusedMonitor?.name ?? "");
        }
    }

    // One state's content, pinned to the island's top-centre.
    component Layer: Item {
        property bool shown: false
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: implicitWidth
        height: implicitHeight

        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.94
        transformOrigin: Item.Top
        visible: opacity > 0.001
        enabled: shown

        Behavior on opacity {
            NumberAnimation { duration: Theme.fadeMs; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.morphMs; easing.type: Easing.OutQuint }
        }
    }

    // ---- IPC: `qs ipc call island <fn>` -----------------------------------
    IpcHandler {
        target: "island"

        function settings(): void {
            ShellState.toggle("settings", Hyprland.focusedMonitor?.name ?? "");
        }
        function wallpapers(): void {
            ShellState.toggle("wallpapers", Hyprland.focusedMonitor?.name ?? "");
        }
        function launcher(): void {
            ShellState.toggle("launcher", Hyprland.focusedMonitor?.name ?? "");
        }
        function command(): void {
            ShellState.toggle("command", Hyprland.focusedMonitor?.name ?? "");
        }
        function control(): void {
            ShellState.toggle("control", Hyprland.focusedMonitor?.name ?? "");
        }
        function close(): void {
            ShellState.close();
        }
        function wifi(): void {
            ShellState.openControlPage("wifi", Hyprland.focusedMonitor?.name ?? "");
        }
        function bluetooth(): void {
            ShellState.openControlPage("bluetooth", Hyprland.focusedMonitor?.name ?? "");
        }
        function sound(): void {
            ShellState.openControlPage("sound", Hyprland.focusedMonitor?.name ?? "");
        }
        function equalizer(): void {
            ShellState.openControlPage("eq", Hyprland.focusedMonitor?.name ?? "");
        }
        // Brightness keys call this after brightnessctl so the OSD shows.
        function brightness(): void {
            Brightness.refresh(true);
        }
    }

    // Night light: hyprsunset holds the gamma while it runs and restores it
    // when killed, so the toggle is just process lifetime.
    Process {
        running: ShellState.nightLight
        command: ["hyprsunset", "-t", String(HyprSettings.get("shell.nightTemp"))]
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData
            screen: modelData

            // ---- state ----------------------------------------------------
            readonly property bool owner: ShellState.screen === modelData.name
            readonly property string openMode: owner ? ShellState.mode : ""
            readonly property bool open: openMode !== ""

            property bool peeking: false
            property bool transientPeek: false
            property bool osdActive: false

            readonly property string view: open ? openMode
                : osdActive ? "osd"
                : (peeking || transientPeek) ? "peek"
                : "idle"

            // ---- surface --------------------------------------------------
            // Full-screen and transparent so the island can grow into any
            // shape without resizing the surface mid-animation. The input
            // mask keeps it click-through everywhere but the island, until
            // something is open — then the whole screen catches the
            // click-outside that closes it.
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-island"
            WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusiveZone: 0
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            mask: open ? fullMask : islandMask
            Region { id: fullMask; item: backdrop }
            Region { id: islandMask; item: island }

            // Caffeine: one inhibitor per output is harmless and keeps it
            // alive whichever monitor is connected.
            IdleInhibitor {
                window: panel
                enabled: ShellState.caffeine
            }

            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }

            // ---- transitions between states -------------------------------
            // Deferred: the layer's `enabled` binding has to flip first, or
            // the focus request lands on a disabled item and is dropped.
            //
            // Peek is reset on every open/close: when the island shrinks out
            // from under a stationary cursor, Wayland sends no pointer-leave
            // until the mouse moves, which would otherwise strand it in peek.
            onOpenModeChanged: {
                // Reset to the main grid on *every* mode change, closing
                // included: a sub-page left "open" behind a closed island kept
                // Bluetooth scanning (and pairable) running. A sub-page request
                // (if any) arrives right after via pageRequested.
                control.page = "";
                Qt.callLater(focusOpenLayer);
            }
            Connections {
                target: ShellState
                function onPageRequested(page) {
                    if (panel.openMode === "control") control.openPage(page);
                }
            }
            function focusOpenLayer() {
                peekIn.stop();
                peeking = false;
                if (openMode === "launcher") launcher.activate();
                else if (openMode === "control") control.forceActiveFocus();
                else if (openMode === "settings") settingsPanel.activate();
                else if (openMode === "wallpapers") wallpaperPicker.activate();
                else if (openMode === "command") commandBox.activate();
            }

            Timer {
                id: osdTimer
                interval: IslandConfig.osdSeconds * 1000
                onTriggered: panel.osdActive = false
            }
            Connections {
                target: ShellState
                function onOsdRequested() {
                    if (!IslandConfig.osd) return;
                    panel.osdActive = true;
                    osdTimer.restart();
                }
            }

            // Hover dwell before peeking, so flicking the cursor to a tab bar
            // doesn't make the island lunge at you.
            Timer {
                id: peekIn
                interval: IslandConfig.hoverDelay
                onTriggered: panel.peeking = true
            }
            Timer {
                id: peekOut
                interval: IslandConfig.collapseDelay
                onTriggered: panel.peeking = false
            }

            // Briefly show the peek on track changes.
            property bool ready: false
            Timer {
                interval: 2000
                running: true
                onTriggered: panel.ready = true
            }
            Timer {
                id: transientTimer
                interval: IslandConfig.trackPeekSeconds * 1000
                onTriggered: panel.transientPeek = false
            }
            Connections {
                target: Media
                function onTrackIdChanged() {
                    if (!IslandConfig.trackPeek || !panel.ready || Media.trackId === "" || Media.trackId === "·") return;
                    panel.transientPeek = true;
                    transientTimer.restart();
                }
            }

            // ---- geometry per state ---------------------------------------
            readonly property Item activeLayer: ({
                idle: idleLayer, peek: peekLayer, osd: osdLayer,
                launcher: launcherLayer, control: controlLayer,
                settings: settingsLayer, wallpapers: wallpaperLayer,
                command: commandLayer
            })[view]

            readonly property real targetW: activeLayer.implicitWidth
            readonly property real targetH: activeLayer.implicitHeight
            readonly property real targetRadius: open ? Theme.radiusPanel : 100

            // ---- backdrop -------------------------------------------------
            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: "black"
                opacity: panel.openMode === "control" ? IslandConfig.dim * 0.47 : panel.open ? IslandConfig.dim : 0
                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: panel.open
                    onClicked: ShellState.close()
                }
            }

            // ---- window launch ----------------------------------------------
            // New windows fly out from under the island (stacked below it).
            WindowLaunch {
                anchors.fill: parent
                source: island
                screen: panel.modelData
            }

            // ---- shadow ---------------------------------------------------
            RectangularShadow {
                anchors.fill: island
                radius: island.radius
                blur: panel.open ? 48 : 22
                spread: 0
                offset.y: panel.open ? 14 : 5
                color: Qt.rgba(0, 0, 0, Math.min(1, IslandConfig.shadow * (panel.open ? 1.2 : 1)))
                Behavior on blur {
                    NumberAnimation { duration: 400 }
                }
            }

            // Accent halo: a breath of the palette colour under the island,
            // brighter while something is live.
            RectangularShadow {
                anchors.fill: island
                radius: island.radius
                blur: 26
                spread: -4
                color: Colors.primary
                opacity: panel.open ? IslandConfig.glow * 0.7 : (Media.playing || panel.view !== "idle" ? IslandConfig.glow : 0.0)
                Behavior on opacity {
                    NumberAnimation { duration: 500 }
                }
            }

            // ---- the island -----------------------------------------------
            Rectangle {
                id: island

                anchors.horizontalCenter: parent.horizontalCenter
                y: IslandConfig.attached ? 0 : IslandConfig.offset

                width: panel.targetW
                height: panel.targetH
                radius: Math.min(height / 2, animRadius)
                property real animRadius: panel.targetRadius

                color: Theme.island
                border.width: IslandConfig.rim && !IslandConfig.attached ? 1 : 0
                border.color: Theme.islandRim
                antialiasing: true

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.morphMs
                        easing.type: Easing.OutBack
                        easing.overshoot: Theme.morphOvershoot
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Theme.morphMs > 0 ? Theme.morphMs + 40 : 0
                        easing.type: Easing.OutBack
                        easing.overshoot: Theme.morphOvershoot * 0.8
                    }
                }
                Behavior on animRadius {
                    NumberAnimation { duration: Theme.morphMs; easing.type: Easing.OutCubic }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            peekOut.stop();
                            if (panel.peeking || panel.open || !IslandConfig.hoverExpand) return;
                            if (IslandConfig.hoverDelay <= 0) panel.peeking = true;
                            else peekIn.restart();
                        } else {
                            peekIn.stop();
                            peekOut.restart();
                        }
                    }
                }

                // Base input layer: click / right / middle / scroll actions are
                // user-configurable (Settings › Dynamic Island). While open it
                // just swallows clicks so they don't reach the backdrop.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: panel.open ? Qt.ArrowCursor : Qt.PointingHandCursor

                    function run(action) {
                        if (action === "playpause") Media.toggle();
                        else if (action && action !== "none") ShellState.toggle(action, panel.modelData.name);
                    }
                    onClicked: e => {
                        if (panel.open) return;
                        run(e.button === Qt.RightButton ? IslandConfig.rightClickAction
                            : e.button === Qt.MiddleButton ? IslandConfig.middleClickAction
                            : IslandConfig.clickAction);
                    }
                    onWheel: w => {
                        if (panel.open) return;
                        const up = w.angleDelta.y > 0;
                        switch (IslandConfig.scrollAction) {
                        case "volume":
                            Audio.nudge(up ? 0.05 : -0.05);
                            break;
                        case "brightness":
                            if (!Brightness.available) break;
                            Brightness.set(Brightness.value + (up ? 0.05 : -0.05));
                            ShellState.showOsd("brightness", Brightness.value, false);
                            break;
                        case "workspace":
                            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${up ? "e-1" : "e+1"}" })`);
                            break;
                        }
                    }
                }

                // Notch style: square off the top corners so the island reads
                // as hanging from the screen edge.
                Rectangle {
                    visible: IslandConfig.attached
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.min(parent.radius, parent.height / 2)
                    color: parent.color
                }

                // Glass sheen: a hairline along the top inner edge that fades
                // at both ends, so the island reads as a lit object.
                Rectangle {
                    visible: IslandConfig.sheen && !IslandConfig.attached
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(0, parent.width - island.radius * 2)
                    height: 1
                    z: 10
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Theme.islandSheen }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // ---- content layers ---------------------------------------
                // Every layer is pinned to the island's top-centre at its own
                // natural size, so as the shape grows the content is
                // *uncovered* from under the notch rather than stretched.
                // The clip follows the rounded outline, so content mid-fade never
                // pokes past the curve while the shape is still morphing.
                ClippingRectangle {
                    id: viewport
                    anchors.fill: parent
                    radius: island.radius
                    color: "transparent"

                    Layer {
                        id: idleLayer
                        shown: panel.view === "idle"
                        implicitWidth: idleContent.implicitWidth
                        implicitHeight: idleContent.implicitHeight
                        IslandIdle {
                            id: idleContent
                            anchors.fill: parent
                            clock: clock
                        }
                    }

                    Layer {
                        id: peekLayer
                        shown: panel.view === "peek"
                        implicitWidth: peekContent.implicitWidth
                        implicitHeight: peekContent.implicitHeight
                        IslandPeek {
                            id: peekContent
                            anchors.fill: parent
                            clock: clock
                        }
                    }

                    Layer {
                        id: osdLayer
                        shown: panel.view === "osd"
                        implicitWidth: osdContent.implicitWidth
                        implicitHeight: osdContent.implicitHeight
                        IslandOsd {
                            id: osdContent
                            anchors.fill: parent
                            kind: ShellState.osdKind
                            value: ShellState.osdValue
                            muted: ShellState.osdMuted
                        }
                    }

                    Layer {
                        id: launcherLayer
                        shown: panel.view === "launcher"
                        implicitWidth: launcher.implicitWidth
                        implicitHeight: launcher.implicitHeight
                        Launcher {
                            id: launcher
                            anchors.fill: parent
                            onCloseRequested: ShellState.close()
                        }
                    }

                    Layer {
                        id: controlLayer
                        shown: panel.view === "control"
                        implicitWidth: control.implicitWidth
                        implicitHeight: control.implicitHeight
                        ControlCenter {
                            id: control
                            anchors.fill: parent
                            onCloseRequested: ShellState.close()
                        }
                    }

                    Layer {
                        id: settingsLayer
                        shown: panel.view === "settings"
                        implicitWidth: settingsPanel.implicitWidth
                        implicitHeight: settingsPanel.implicitHeight
                        SettingsPanel {
                            id: settingsPanel
                            anchors.fill: parent
                            onCloseRequested: ShellState.close()
                        }
                    }

                    Layer {
                        id: wallpaperLayer
                        shown: panel.view === "wallpapers"
                        implicitWidth: wallpaperPicker.implicitWidth
                        implicitHeight: wallpaperPicker.implicitHeight
                        WallpaperPicker {
                            id: wallpaperPicker
                            anchors.fill: parent
                            onCloseRequested: ShellState.close()
                        }
                    }

                    Layer {
                        id: commandLayer
                        shown: panel.view === "command"
                        implicitWidth: commandBox.implicitWidth
                        implicitHeight: commandBox.implicitHeight
                        CommandBox {
                            id: commandBox
                            anchors.fill: parent
                            onCloseRequested: ShellState.close()
                        }
                    }
                }
            }
        }
    }
}
