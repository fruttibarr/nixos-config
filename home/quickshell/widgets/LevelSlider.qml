import QtQuick
import "root:/"

// Chunky pill slider: the fill *is* the handle, with the icon riding inside
// it. Clicking the icon fires `iconClicked` (mute etc.); dragging anywhere
// else sets the level. Scroll nudges by 5%.
Rectangle {
    id: root

    property real value: 0          // 0..1
    property string icon: ""
    property bool dimmed: false     // e.g. muted
    signal moved(real v)
    signal iconClicked

    implicitHeight: 40
    radius: height / 2
    color: Theme.track
    clip: true

    readonly property real minFill: height
    readonly property real fillWidth: minFill + (width - minFill) * Math.max(0, Math.min(1, value))

    Rectangle {
        id: fill
        width: root.fillWidth
        height: parent.height
        radius: height / 2
        color: root.dimmed ? Theme.alpha(Colors.text, 0.28) : Colors.primary
        Behavior on width {
            enabled: !drag.pressed
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: 180 }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function setFrom(x) {
            const span = width - root.minFill;
            root.moved(Math.max(0, Math.min(1, (x - root.minFill / 2) / span)));
        }
        onPressed: e => setFrom(e.x)
        onPositionChanged: e => { if (pressed) setFrom(e.x); }
        onWheel: w => root.moved(Math.max(0, Math.min(1,
            root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }

    // Icon sits in the left cap of the fill.
    Item {
        width: root.minFill
        height: root.height

        Glyph {
            anchors.centerIn: parent
            text: root.icon
            size: 16
            color: root.dimmed ? Colors.text : Colors.textOnPrimary
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.value * 100)
        font.family: Theme.mono
        font.pixelSize: 11
        font.weight: Font.Medium
        // Flip to the on-primary colour once the fill runs under the label.
        color: root.fillWidth > root.width - 34 && !root.dimmed ? Colors.textOnPrimary : Theme.textSoft
    }
}
