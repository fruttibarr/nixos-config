import QtQuick
import QtQuick.Layouts
import "root:/"

// Control-center toggle tile: an icon disc that lights up when active, a
// title, a status line, and an optional chevron that opens settings.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool available: true
    property bool hasMore: false
    signal toggled
    signal more

    implicitHeight: 62
    radius: Theme.radiusCard
    opacity: available ? 1 : 0.45

    color: {
        if (active) return Theme.alpha(Colors.primary, mouse.containsMouse ? 0.22 : 0.16);
        return mouse.containsMouse ? Theme.cardHover : Theme.card;
    }
    Behavior on color {
        ColorAnimation { duration: 180 }
    }

    border.width: 1
    border.color: active ? Theme.alpha(Colors.primary, 0.28) : "transparent"
    Behavior on border.color {
        ColorAnimation { duration: 180 }
    }

    scale: mouse.pressed ? 0.97 : 1
    Behavior on scale {
        NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 11
        anchors.rightMargin: 8
        spacing: 10

        Rectangle {
            implicitWidth: 38
            implicitHeight: 38
            radius: 19
            color: root.active ? Colors.primary : Theme.track
            Behavior on color {
                ColorAnimation { duration: 180 }
            }

            Glyph {
                anchors.centerIn: parent
                text: root.icon
                size: 17
                color: root.active ? Colors.textOnPrimary : Colors.text
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Colors.text
                font.family: Theme.sans
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.subtitle
                color: root.active ? Theme.alpha(Colors.primary, 0.9) : Theme.textSoft
                font.family: Theme.sans
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // Settings chevron — its own hit area so it doesn't toggle the tile.
        Rectangle {
            visible: root.hasMore
            implicitWidth: 24
            implicitHeight: 36
            radius: 10
            color: moreMouse.containsMouse ? Theme.cardHover : "transparent"

            Glyph {
                anchors.centerIn: parent
                text: "󰅂"
                size: 13
                color: Theme.textSoft
            }

            MouseArea {
                id: moreMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.more()
            }
        }
    }
}
