import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/"
import "root:/services"

// Hyprland settings panel that the island morphs into (SUPER+I).
// Every control applies live; HyprSettings persists the overrides.
FocusScope {
    id: root

    signal closeRequested

    implicitWidth: 920
    implicitHeight: 640

    property string section: "appearance"
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var sectionObj: HyprSettings.sections.find(s => s.id === section)

    function activate() {
        search.text = "";
        HyprSettings.refreshMonitors();
        search.forceActiveFocus();
    }

    Keys.onEscapePressed: {
        if (search.text !== "") search.text = "";
        else root.closeRequested();
    }

    // Search across every section's labels, hints and keys.
    readonly property var matches: {
        if (query === "") return [];
        return Object.values(HyprSettings.fieldMap).filter(f =>
            `${f.label} ${f.hint ?? ""} ${f.key} ${f.group}`.toLowerCase().includes(query));
    }
    readonly property var bindMatches: {
        if (query === "") return [];
        return HyprSettings.bindDefaults.binds.filter(b =>
            `${b.label} ${b.group} keybind shortcut ${HyprSettings.bindKeys(b.id)}`.toLowerCase().includes(query));
    }

    onSectionChanged: content.contentY = 0
    onQueryChanged: content.contentY = 0

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        // ================= sidebar =================
        ColumnLayout {
            // A layout whose children fill defaults to filling itself, which
            // would starve the content pane — pin the sidebar's width.
            Layout.preferredWidth: 220
            Layout.maximumWidth: 220
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.topMargin: 4
                Layout.bottomMargin: 6
                spacing: 10

                Rectangle {
                    implicitWidth: 34
                    implicitHeight: 34
                    radius: 11
                    color: Theme.alpha(Colors.primary, 0.18)
                    Glyph {
                        anchors.centerIn: parent
                        text: "󰒓"
                        size: 17
                        color: Colors.primary
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: "Settings"
                    color: Colors.text
                    font.family: Theme.sans
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
            }

            // Search
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 18
                color: Theme.card
                border.width: 1
                border.color: search.activeFocus ? Theme.alpha(Colors.primary, 0.35) : Theme.hairline

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8
                    Glyph {
                        text: "󰍉"
                        size: 14
                        color: Theme.textSoft
                    }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: search.implicitHeight
                        TextInput {
                            id: search
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: Colors.text
                            selectionColor: Theme.alpha(Colors.primary, 0.4)
                            font.family: Theme.sans
                            font.pixelSize: 13
                            clip: true
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text.length === 0
                            text: "Search settings"
                            color: Theme.textFaint
                            font: search.font
                        }
                    }
                }
            }

            Item { implicitHeight: 4 }

            Repeater {
                model: HyprSettings.sections

                Rectangle {
                    id: navItem
                    required property var modelData
                    readonly property bool current: root.query === "" && root.section === modelData.id
                    readonly property int changed: HyprSettings.changedIn(modelData.id)

                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 14
                    color: current ? Theme.alpha(Colors.primary, 0.16)
                        : navMouse.containsMouse ? Theme.cardHover : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12
                        Glyph {
                            text: navItem.modelData.icon
                            size: 16
                            color: navItem.current ? Colors.primary : Theme.textSoft
                        }
                        Text {
                            Layout.fillWidth: true
                            text: navItem.modelData.label
                            color: navItem.current ? Colors.text : Theme.textSoft
                            font.family: Theme.sans
                            font.pixelSize: 13
                            font.weight: navItem.current ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                        }
                        // Count of settings changed from the defaults.
                        Rectangle {
                            visible: navItem.changed > 0
                            implicitWidth: Math.max(18, countText.implicitWidth + 10)
                            implicitHeight: 18
                            radius: 9
                            color: Theme.alpha(Colors.primary, 0.22)
                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: navItem.changed
                                color: Colors.primary
                                font.family: Theme.mono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                    }
                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            search.text = "";
                            root.section = navItem.modelData.id;
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Status
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: HyprSettings.lastError ? "Hyprland rejected a change" : "Changes apply instantly"
                    color: HyprSettings.lastError ? Colors.error : Theme.textSoft
                    font.family: Theme.sans
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
                Text {
                    Layout.fillWidth: true
                    text: HyprSettings.lastError || "Saved to ~/.config/hypr/settings.lua"
                    color: HyprSettings.lastError ? Theme.alpha(Colors.error, 0.8) : Theme.textFaint
                    font.family: HyprSettings.lastError ? Theme.mono : Theme.sans
                    font.pixelSize: 10
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }
        }

        // ================= content =================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 22
            color: Theme.alpha(Colors.text, 0.025)

            Flickable {
                id: content
                anchors.fill: parent
                anchors.margins: 6
                contentHeight: pageCol.implicitHeight + 24
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: pageCol
                    x: 14
                    y: 12
                    width: content.width - 28
                    spacing: 10

                    // ---- header --------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.query !== "" ? `Results for “${search.text.trim()}”` : (root.sectionObj?.label ?? "")
                            color: Colors.text
                            font.family: Theme.sans
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: root.query === "" && HyprSettings.changedIn(root.section) > 0
                            implicitWidth: resetText.implicitWidth + 26
                            implicitHeight: 30
                            radius: 15
                            color: resetMouse.containsMouse ? Theme.alpha(Colors.error, 0.16) : Theme.card
                            Text {
                                id: resetText
                                anchors.centerIn: parent
                                text: "Reset section"
                                color: resetMouse.containsMouse ? Colors.error : Theme.textSoft
                                font.family: Theme.sans
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: HyprSettings.resetSection(root.section)
                            }
                        }
                    }

                    // ---- displays (Display section only) --------------------
                    Repeater {
                        model: root.query === "" && root.sectionObj?.monitors ? HyprSettings.monitorList : []
                        MonitorCard {
                            required property var modelData
                            Layout.fillWidth: true
                            monitor: modelData
                        }
                    }

                    // ---- search results -------------------------------------
                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.query !== ""
                        implicitHeight: resultsCol.implicitHeight
                        radius: Theme.radiusCard
                        color: Theme.card

                        Column {
                            id: resultsCol
                            width: parent.width
                            Repeater {
                                model: root.matches
                                Column {
                                    required property var modelData
                                    required property int index
                                    width: resultsCol.width
                                    Rectangle {
                                        visible: index > 0
                                        width: parent.width - 32
                                        x: 16
                                        height: 1
                                        color: Theme.hairline
                                    }
                                    SettingRow {
                                        width: parent.width
                                        field: modelData
                                        showSection: true
                                    }
                                }
                            }
                            Repeater {
                                model: root.bindMatches
                                Column {
                                    required property var modelData
                                    required property int index
                                    width: resultsCol.width
                                    Rectangle {
                                        visible: index > 0 || root.matches.length > 0
                                        width: parent.width - 32
                                        x: 16
                                        height: 1
                                        color: Theme.hairline
                                    }
                                    KeybindRow {
                                        width: parent.width
                                        bind: modelData
                                        showSection: true
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        visible: root.query !== "" && root.matches.length === 0 && root.bindMatches.length === 0
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 40
                        text: "No settings match"
                        color: Theme.textSoft
                        font.family: Theme.sans
                        font.pixelSize: 13
                    }

                    // ---- keybinds (Keybinds section only) --------------------
                    KeybindsPage {
                        Layout.fillWidth: true
                        visible: root.query === "" && !!root.sectionObj?.keybinds
                    }

                    // ---- section groups -------------------------------------
                    Repeater {
                        model: root.query === "" && !root.sectionObj?.keybinds ? (root.sectionObj?.groups ?? []) : []

                        ColumnLayout {
                            id: group
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            spacing: 8

                            Text {
                                Layout.leftMargin: 6
                                text: group.modelData.title
                                color: Theme.textSoft
                                font.family: Theme.sans
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.6
                                font.capitalization: Font.AllUppercase
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
                                        model: group.modelData.fields
                                        Column {
                                            required property var modelData
                                            required property int index
                                            width: rows.width
                                            Rectangle {
                                                visible: index > 0
                                                width: parent.width - 32
                                                x: 16
                                                height: 1
                                                color: Theme.hairline
                                            }
                                            SettingRow {
                                                width: parent.width
                                                field: HyprSettings.fieldMap[modelData.key]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Scroll hint: a soft fade at the bottom while there's more.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 6
                height: 28
                radius: 16
                visible: content.contentY + content.height < content.contentHeight - 4
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Theme.alpha(Theme.island, 0.9) }
                }
            }
        }
    }
}
