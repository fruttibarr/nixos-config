import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/services"

// One rebindable shortcut from keybinds.json: label, recorder, and buttons to
// unbind it or restore the default.
Item {
    id: root

    required property var bind
    property bool showSection: false   // prefix with "Keybinds ›" (search results)

    readonly property string keys: HyprSettings.bindKeys(bind.id)
    readonly property bool isDefault: HyprSettings.bindIsDefault(bind.id)
    readonly property var conflicts: keys === "" ? [] : HyprSettings.conflicts(keys, "bind:" + bind.id)

    implicitHeight: Math.max(52, row.implicitHeight + 20)

    HoverHandler {
        id: hover
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 10
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.showSection ? `Keybinds › ${root.bind.label}` : root.bind.label
                color: Colors.text
                font.family: Theme.sans
                font.pixelSize: 13
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: root.conflicts.length > 0 || !root.isDefault
                text: root.conflicts.length > 0
                    ? `Also bound to ${root.conflicts.join(", ")}`
                    : `Default: ${root.bind.keys}`
                color: root.conflicts.length > 0 ? Colors.error : Theme.textFaint
                font.family: Theme.sans
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        // Unbind (shown on hover while bound).
        IconButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "󰅖"
            size: 26
            flat: true
            danger: true
            opacity: hover.hovered && root.keys !== "" ? 1 : 0
            enabled: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }
            onClicked: HyprSettings.setBind(root.bind.id, "")
        }

        KeyRecorder {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 200
            keys: root.keys
            conflict: root.conflicts.length > 0
            placeholder: "Disabled"
            onRecorded: k => HyprSettings.setBind(root.bind.id, k)
        }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "󰑓"
            size: 26
            flat: true
            opacity: root.isDefault ? 0 : 1
            enabled: !root.isDefault
            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }
            onClicked: HyprSettings.resetBind(root.bind.id)
        }
    }
}
