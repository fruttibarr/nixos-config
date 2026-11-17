import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/services"

// A user-added shortcut: a shell command plus the keys that run it.
Item {
    id: root

    required property int index
    required property var entry   // { keys, exec }

    readonly property var conflicts: entry.keys === "" || entry.exec.trim() === ""
        ? [] : HyprSettings.conflicts(entry.keys, "custom:" + index)

    implicitHeight: Math.max(52, col.implicitHeight + 20)

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 10
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 16
                color: Theme.track
                border.width: 1
                border.color: input.activeFocus ? Theme.alpha(Colors.primary, 0.45) : "transparent"

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.entry.exec
                    color: Colors.text
                    selectionColor: Theme.alpha(Colors.primary, 0.4)
                    font.family: Theme.mono
                    font.pixelSize: 12
                    clip: true
                    onEditingFinished: if (text !== root.entry.exec) HyprSettings.setCustomBind(root.index, { exec: text })

                    // Typing breaks the `text` binding; follow removals of
                    // rows above (which shift this row's entry) by hand.
                    Connections {
                        target: root
                        function onEntryChanged() {
                            if (!input.activeFocus) input.text = root.entry.exec;
                        }
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0 && !input.activeFocus
                    text: "Command, e.g. firefox"
                    color: Theme.textFaint
                    font.family: Theme.mono
                    font.pixelSize: 12
                }
            }

            KeyRecorder {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 200
                keys: root.entry.keys
                conflict: root.conflicts.length > 0
                placeholder: "Set shortcut"
                onRecorded: k => HyprSettings.setCustomBind(root.index, { keys: k })
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "󰅖"
                size: 26
                flat: true
                danger: true
                onClicked: HyprSettings.removeCustomBind(root.index)
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.conflicts.length > 0
            text: `Also bound to ${root.conflicts.join(", ")}`
            color: Colors.error
            font.family: Theme.sans
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }
}
