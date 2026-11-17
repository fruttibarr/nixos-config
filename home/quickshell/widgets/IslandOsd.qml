import QtQuick
import QtQuick.Layouts
import "root:/"

// Volume / brightness feedback — the island briefly turns into a level bar.
Item {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false

    implicitWidth: 290
    implicitHeight: 40

    readonly property string icon: {
        if (kind === "brightness") {
            if (value > 0.66) return "󰃠";
            if (value > 0.33) return "󰃟";
            return "󰃞";
        }
        if (muted || value <= 0.001) return "󰝟";
        if (value > 0.66) return "󰕾";
        if (value > 0.33) return "󰖀";
        return "󰕿";
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Glyph {
            text: root.icon
            size: 16
            color: root.muted ? Theme.textSoft : Colors.primary
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.track

            Rectangle {
                height: parent.height
                radius: 3
                width: parent.width * Math.max(0, Math.min(1, root.value))
                color: root.muted ? Theme.textFaint : Colors.primary
                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                // Soft glow at the leading edge.
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: 5
                    color: Colors.primary
                    opacity: root.muted ? 0 : 0.35
                    visible: parent.width > 6
                }
            }
        }

        Text {
            Layout.preferredWidth: 26
            horizontalAlignment: Text.AlignRight
            text: root.muted ? "off" : Math.round(root.value * 100)
            color: Colors.text
            font.family: Theme.mono
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
}
