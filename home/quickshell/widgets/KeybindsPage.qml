import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/services"

// Settings › Keybinds: every bind from keybinds.json grouped as listed there,
// the workspace modifiers (ordinary fields) after the Focus group, and the
// user's own command shortcuts at the end.
ColumnLayout {
    id: root

    spacing: 10

    // [{ title, rows: [{ bind } | { field }] }]
    readonly property var groups: {
        const d = HyprSettings.bindDefaults;
        const out = [];
        for (const g of d.groups) {
            out.push({ title: g, rows: d.binds.filter(b => b.group === g).map(b => ({ bind: b })) });
            if (g === "Focus") out.push({ title: "Workspaces", rows: [
                { field: "bind.wsFocus" }, { field: "bind.wsMove" }
            ]});
        }
        return out.filter(g => g.rows.length > 0);
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        text: "Click a shortcut and press the new keys. Esc cancels; changes apply instantly."
        color: Theme.textSoft
        font.family: Theme.sans
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    component GroupTitle: Text {
        Layout.leftMargin: 6
        Layout.topMargin: 6
        color: Theme.textSoft
        font.family: Theme.sans
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
    }
    component Separator: Rectangle {
        width: parent.width - 32
        x: 16
        height: 1
        color: Theme.hairline
    }

    Repeater {
        model: root.groups

        ColumnLayout {
            id: group
            required property var modelData
            Layout.fillWidth: true
            spacing: 8

            GroupTitle {
                text: group.modelData.title
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rows.implicitHeight
                radius: Theme.radiusCard
                color: Theme.card

                Column {
                    id: rows
                    width: parent.width
                    Repeater {
                        model: group.modelData.rows
                        Column {
                            id: rowItem
                            required property var modelData
                            required property int index
                            width: rows.width
                            Separator {
                                visible: rowItem.index > 0
                            }
                            Loader {
                                width: parent.width
                                sourceComponent: rowItem.modelData.bind ? bindRow : fieldRow
                            }
                            Component {
                                id: bindRow
                                KeybindRow {
                                    bind: rowItem.modelData.bind
                                }
                            }
                            Component {
                                id: fieldRow
                                SettingRow {
                                    field: HyprSettings.fieldMap[rowItem.modelData.field]
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- custom shortcuts --------------------------------------------------
    GroupTitle {
        text: "Custom shortcuts"
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: customCol.implicitHeight
        radius: Theme.radiusCard
        color: Theme.card

        Column {
            id: customCol
            width: parent.width

            // Keyed by count, not the array: editing a row then must not
            // rebuild it (that would drop a click on its recorder).
            Repeater {
                model: HyprSettings.customBinds.length
                Column {
                    id: customItem
                    required property int index
                    width: customCol.width
                    Separator {
                        visible: customItem.index > 0
                    }
                    CustomBindRow {
                        width: parent.width
                        index: customItem.index
                        entry: HyprSettings.customBinds[customItem.index] ?? { keys: "", exec: "" }
                    }
                }
            }

            Separator {
                visible: HyprSettings.customBinds.length > 0
            }

            // Add button row
            Item {
                width: parent.width
                implicitHeight: 48

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: addRow.implicitWidth + 24
                    implicitHeight: 32
                    radius: 16
                    color: addMouse.containsMouse ? Theme.alpha(Colors.primary, 0.16) : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }

                    RowLayout {
                        id: addRow
                        anchors.centerIn: parent
                        spacing: 8
                        Glyph {
                            text: "󰐕"
                            size: 14
                            color: Colors.primary
                        }
                        Text {
                            text: "Add shortcut"
                            color: Colors.primary
                            font.family: Theme.sans
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: HyprSettings.addCustomBind()
                    }
                }
            }
        }
    }
}
