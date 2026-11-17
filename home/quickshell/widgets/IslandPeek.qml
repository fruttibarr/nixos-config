import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "root:/"
import "root:/services"

// Hover state: a wider pill with now-playing controls, status and the date.
Item {
    id: root

    required property var clock

    implicitWidth: row.implicitWidth + 40
    implicitHeight: 58

    component Divider: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 22
        color: Theme.hairline
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 16

        WorkspaceRail {
            Layout.alignment: Qt.AlignVCenter
        }

        Divider {
            visible: IslandConfig.peekMedia && Media.present
        }

        // ---- now playing ----------------------------------------------
        RowLayout {
            visible: IslandConfig.peekMedia && Media.present
            spacing: 10
            Layout.alignment: Qt.AlignVCenter

            ArtThumb {
                source: Media.art
                size: 36
            }

            ColumnLayout {
                spacing: 0
                Layout.maximumWidth: 170
                Layout.preferredWidth: Math.min(170, Math.max(titleText.implicitWidth, artistText.implicitWidth))

                Text {
                    id: titleText
                    Layout.fillWidth: true
                    text: Media.title
                    color: Colors.text
                    font.family: Theme.sans
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    id: artistText
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Media.artist
                    color: Theme.textSoft
                    font.family: Theme.sans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Row {
                spacing: 2
                IconButton {
                    icon: "󰒮"; size: 26; flat: true
                    onClicked: Media.previous()
                }
                IconButton {
                    icon: Media.playing ? "󰏤" : "󰐊"; size: 30; filled: true
                    onClicked: Media.toggle()
                }
                IconButton {
                    icon: "󰒭"; size: 26; flat: true
                    onClicked: Media.next()
                }
            }
        }

        Divider {
            visible: IslandConfig.peekStatus
        }

        // ---- status ---------------------------------------------------
        RowLayout {
            visible: IslandConfig.peekStatus || (IslandConfig.peekTray && SystemTray.items.values.length > 0)
            spacing: 12
            Layout.alignment: Qt.AlignVCenter

            Glyph {
                visible: IslandConfig.peekStatus
                text: Net.icon
                size: 14
                color: Net.wifiNetwork || Net.wiredUp ? Colors.text : Theme.textFaint
            }

            Row {
                visible: IslandConfig.peekStatus
                spacing: 5
                Glyph {
                    text: Audio.icon
                    size: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Math.round(Audio.volume * 100)
                    color: Theme.textSoft
                    font.family: Theme.mono
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                visible: IslandConfig.peekStatus && Battery.present
                spacing: 5
                Glyph {
                    text: Battery.icon
                    size: 14
                    color: Battery.low ? Colors.error : (Battery.charging ? Colors.primary : Colors.text)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Battery.percent
                    color: Theme.textSoft
                    font.family: Theme.mono
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Tray {
                visible: IslandConfig.peekTray && SystemTray.items.values.length > 0
                flat: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Divider {}

        ColumnLayout {
            spacing: -1
            Layout.alignment: Qt.AlignVCenter

            Text {
                Layout.alignment: Qt.AlignRight
                text: Qt.formatDateTime(root.clock.date, IslandConfig.clock12 ? "h:mm AP" : "HH:mm")
                color: Colors.text
                font.family: Theme.mono
                font.pixelSize: 15
                font.weight: Font.Bold
            }
            Text {
                Layout.alignment: Qt.AlignRight
                visible: IslandConfig.peekDate
                text: Qt.formatDateTime(root.clock.date, "ddd d MMM")
                color: Theme.textSoft
                font.family: Theme.sans
                font.pixelSize: 10
                font.weight: Font.Medium
            }
        }
    }
}
