import QtQuick
import Quickshell.Hyprland
import "root:/"

// Workspace indicator built as a single continuous rail. Slots run from 1 to
// the highest workspace in use (empty ones in between drawn faint), so the
// rail — and the island around it — grows and shrinks as you use the machine
// instead of always reserving room for ten slots. One highlighted capsule slides between
// positions; a shared moving element reads far calmer than N dots resizing.
Item {
    id: root

    property real tickSize: 5
    property real activeWidth: 20
    property real gap: 8

    readonly property int activeId: Hyprland.focusedWorkspace?.id ?? 1

    // Every slot from 1 up to the highest workspace in use (or the focused
    // one), so skipping ahead never leaves a gap: a terminal on 1 and focus on
    // 3 shows 1 · 2 · 3, with 2 drawn as an empty slot.
    readonly property var wsList: {
        let top = activeId >= 1 && activeId <= 10 ? activeId : 1;
        for (const w of Hyprland.workspaces.values)
            if (w.id >= 1 && w.id <= 10) top = Math.max(top, w.id);
        const ids = [];
        for (let i = 1; i <= top; i++) ids.push(i);
        return ids;
    }

    // Workspaces with at least one window, for dimming the empty slots.
    readonly property var occupied: {
        const s = {};
        for (const w of Hyprland.workspaces.values)
            if (w.toplevels.values.length > 0) s[w.id] = true;
        return s;
    }

    readonly property int activeIndex: Math.max(0, wsList.indexOf(activeId))
    readonly property int count: wsList.length

    implicitWidth: count > 0
        ? count * tickSize + (count - 1) * gap + (activeWidth - tickSize)
        : activeWidth
    implicitHeight: 10

    Behavior on implicitWidth {
        NumberAnimation { duration: 380; easing.type: Easing.OutQuint }
    }

    // Slots are tickSize wide except the active one, which expands; slots
    // after it shift right by the extra width.
    function slotX(i) {
        var x = i * (tickSize + gap);
        if (i > activeIndex) x += (activeWidth - tickSize);
        return x;
    }

    Repeater {
        model: root.wsList

        Rectangle {
            required property int index
            required property var modelData

            readonly property bool isActive: modelData === root.activeId

            x: root.slotX(index)
            anchors.verticalCenter: parent.verticalCenter

            width: root.tickSize
            height: root.tickSize
            radius: height / 2

            // The active slot is drawn by the sliding capsule below.
            opacity: isActive ? 0 : root.occupied[modelData] ? 1 : 0.35
            color: Colors.textDim

            Behavior on x {
                NumberAnimation { duration: 340; easing.type: Easing.OutQuint }
            }
            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                // Hyprland 0.55 dispatch takes Lua (the old "workspace N" text form errors).
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${modelData} })`)
            }
        }
    }

    // The one moving element.
    Rectangle {
        x: root.slotX(root.activeIndex)
        anchors.verticalCenter: parent.verticalCenter

        width: root.activeWidth
        height: root.tickSize
        radius: height / 2
        color: Colors.primary

        Behavior on x {
            NumberAnimation { duration: 380; easing.type: Easing.OutQuint }
        }

        // Tight rim-light so the marker reads as emitting, not smudged.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 6
            height: parent.height + 6
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Colors.primary
            opacity: 0.25
            z: -1
        }
    }
}
