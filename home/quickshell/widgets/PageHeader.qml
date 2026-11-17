import QtQuick
import QtQuick.Layouts
import "root:/"

// Header for a control-center sub-page: back · title/status · switch.
RowLayout {
    id: root

    property string title: ""
    property string status: ""
    property bool checked: false
    property bool showToggle: true
    property bool working: false     // spins the refresh glyph (scanning)
    signal back
    signal toggled

    spacing: 10

    IconButton {
        icon: "󰁍"
        size: 34
        onClicked: root.back()
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -1

        // fillWidth on the children too: a nested layout can only stretch as
        // far as its children allow.
        Text {
            Layout.fillWidth: true
            text: root.title
            color: Colors.text
            font.family: Theme.sans
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: root.status !== ""

            Glyph {
                visible: root.working
                text: "󰑓"
                size: 11
                color: Colors.primary
                RotationAnimation on rotation {
                    running: root.working
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1100
                }
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.status
                color: Theme.textSoft
                font.family: Theme.sans
                font.pixelSize: 11
            }
        }
    }

    Toggle {
        visible: root.showToggle
        checked: root.checked
        onToggled: root.toggled()
    }
}
