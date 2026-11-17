import QtQuick
import QtQuick.Layouts
import "root:/"

// Compact slider with a value readout. Emits `moved` continuously while
// dragging so changes preview live.
RowLayout {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 1
    property string unit: ""
    property bool percent: false
    signal moved(real v)

    spacing: 12

    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))

    function format(v) {
        if (percent) return Math.round(v * 100) + "%";
        const decimals = step >= 1 ? 0 : Math.min(3, Math.ceil(-Math.log10(step)));
        return v.toFixed(decimals) + unit;
    }

    Item {
        id: track
        Layout.fillWidth: true
        implicitHeight: 22

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.track

            Rectangle {
                width: knob.x + knob.width / 2
                height: parent.height
                radius: 2
                color: Colors.primary
            }
        }

        Rectangle {
            id: knob
            width: 16
            height: 16
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: root.frac * (track.width - width)
            color: Colors.text
            border.width: drag.pressed ? 4 : 0
            border.color: Colors.primary
            Behavior on border.width {
                NumberAnimation { duration: 120 }
            }
            Behavior on x {
                enabled: !drag.pressed
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function setFrom(x) {
                const f = Math.max(0, Math.min(1, (x - 6 - knob.width / 2) / (track.width - knob.width)));
                const raw = root.from + f * (root.to - root.from);
                root.moved(Math.round(raw / root.step) * root.step);
            }
            onPressed: e => setFrom(e.x)
            onPositionChanged: e => { if (pressed) setFrom(e.x); }
            onWheel: w => root.moved(Math.max(root.from, Math.min(root.to,
                root.value + (w.angleDelta.y > 0 ? root.step : -root.step))))
        }
    }

    Text {
        Layout.preferredWidth: 52
        horizontalAlignment: Text.AlignRight
        text: root.format(root.value)
        color: Colors.text
        font.family: Theme.mono
        font.pixelSize: 11
        font.weight: Font.Medium
    }
}
