import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "root:/"
import "root:/services"

// "Out of the island" window opening: when Hyprland maps a new window, a
// shape in the island's colour detaches from the island, flies to the
// window's final frame while morphing into its size and corner radius, and
// dissolves as it lands, revealing the window underneath (which runs its own
// Hyprland open animation beneath this one).
//
// Lives inside the island's full-screen layer surface (one per monitor),
// stacked under the island so the shape appears to slide out from beneath
// it. Never part of the input mask, so it can't intercept clicks.
//
// Toggle: Settings › Animations › Motion › "Open windows out of the island".
Item {
    id: root

    required property Item source   // the island Rectangle
    required property var screen    // this panel's ShellScreen

    readonly property bool active: IslandConfig.windowLaunch
        && IslandConfig.animate
        && !!HyprSettings.get("animations.enabled")

    readonly property var monitor: Hyprland.monitorFor(screen)

    // Windows from DrawTerminal open where they were drawn, not from the
    // island, so the effect would fight that one.
    readonly property var skipClasses: ["kitty-drawn"]

    // Addresses ("0x…") seen in openwindow events, waiting for geometry.
    property var pending: []
    property bool requery: false

    Connections {
        target: Hyprland
        enabled: root.active

        function onRawEvent(event) {
            if (event.name !== "openwindow") return;
            // data: ADDRESS,WORKSPACE,CLASS,TITLE (title may contain commas)
            const parts = event.data.split(",");
            if (root.skipClasses.includes(parts[2])) return;
            root.pending = [...root.pending, "0x" + parts[0]];
            if (clientsProc.running) root.requery = true;
            else clientsProc.running = true;
        }
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: root.launchFrom(text)
        }
        onExited: {
            if (root.requery) {
                root.requery = false;
                running = true;
            }
        }
    }

    function launchFrom(json) {
        let clients;
        try {
            clients = JSON.parse(json);
        } catch (e) {
            pending = [];
            return;
        }
        const want = pending;
        pending = [];
        if (!active || !monitor) return;

        const activeWs = monitor.activeWorkspace?.id;
        for (const c of clients) {
            if (!want.includes(c.address)) continue;
            if (c.monitor !== monitor.id || c.hidden || c.mapped === false) continue;
            // Only windows that actually appear on screen right now: the
            // monitor's active workspace, or a special workspace (negative id).
            if (c.workspace?.id !== activeWs && !(c.workspace?.id < 0)) continue;
            const [w, h] = c.size ?? [0, 0];
            if (w < 8 || h < 8) continue;
            spawn(c.at[0] - screen.x, c.at[1] - screen.y, w, h);
        }
    }

    function spawn(x, y, w, h) {
        const p = source.mapToItem(root, 0, 0);
        ghost.createObject(root, {
            fromX: p.x, fromY: p.y,
            fromW: source.width, fromH: source.height,
            fromR: source.radius,
            toX: x, toY: y, toW: w, toH: h,
            toR: Number(HyprSettings.get("decoration.rounding")) || 0
        });
    }

    Component {
        id: ghost

        Rectangle {
            id: g

            property real fromX; property real fromY
            property real fromW; property real fromH; property real fromR
            property real toX; property real toY
            property real toW; property real toH; property real toR

            // Travel time scales gently with distance so a window opening
            // right under the island doesn't take as long as one in a corner.
            readonly property real dist: Math.hypot(toX + toW / 2 - (fromX + fromW / 2), toY - fromY)
            readonly property int travelMs: Math.round(Math.max(220, Theme.morphMs * (0.85 + dist / 2400)))
            readonly property int fadeMs: Math.max(120, Theme.fadeMs + 60)

            x: fromX; y: fromY
            width: fromW; height: fromH
            radius: fromR
            color: Theme.island
            border.width: 1
            border.color: Theme.alpha(Colors.primary, 0.28)
            antialiasing: true

            ParallelAnimation {
                running: true

                NumberAnimation { target: g; property: "x"; to: g.toX; duration: g.travelMs; easing.type: Easing.OutQuint }
                NumberAnimation { target: g; property: "y"; to: g.toY; duration: g.travelMs; easing.type: Easing.OutQuint }
                NumberAnimation {
                    target: g; property: "width"; to: g.toW; duration: g.travelMs
                    easing.type: Easing.OutBack; easing.overshoot: Theme.morphOvershoot * 0.5
                }
                NumberAnimation {
                    target: g; property: "height"; to: g.toH; duration: g.travelMs + 40
                    easing.type: Easing.OutBack; easing.overshoot: Theme.morphOvershoot * 0.4
                }
                NumberAnimation { target: g; property: "radius"; to: g.toR; duration: g.travelMs; easing.type: Easing.InOutCubic }

                // Start dissolving while still landing, so the window is
                // revealed as the shape settles rather than after a pause.
                SequentialAnimation {
                    PauseAnimation { duration: Math.round(g.travelMs * 0.55) }
                    NumberAnimation { target: g; property: "opacity"; to: 0; duration: g.fadeMs + Math.round(g.travelMs * 0.45); easing.type: Easing.InCubic }
                }

                onFinished: g.destroy()
            }
        }
    }
}
