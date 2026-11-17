import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/services"

// The resting pill. Live activities hang off the ends like iOS "ears":
// album art on the left and a bouncing equalizer on the right while media
// is playing; status glyphs only appear when they have something to say.
Item {
    id: root

    required property var clock

    implicitWidth: row.implicitWidth + 30
    implicitHeight: 36

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12

        ArtThumb {
            visible: IslandConfig.showArt && Media.playing && Media.art !== ""
            source: Media.art
            size: 20
            radius: 6
            Layout.alignment: Qt.AlignVCenter
        }

        WorkspaceRail {
            visible: IslandConfig.showWorkspaces
            Layout.alignment: Qt.AlignVCenter
        }

        // Typographic anchor: hours carry the weight, minutes step back,
        // the colon breathes in the accent colour.
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Text {
                // Qt only uses 1-12 for "h" when AP is in the same format string.
                text: IslandConfig.clock12
                    ? Qt.formatDateTime(root.clock.date, "h AP").split(" ")[0]
                    : Qt.formatDateTime(root.clock.date, "HH")
                color: Colors.text
                font.family: Theme.mono
                font.pixelSize: 14
                font.weight: Font.Bold
            }
            Text {
                text: ":"
                color: Colors.primary
                font.family: Theme.mono
                font.pixelSize: 14
                font.weight: Font.Bold
                opacity: !IslandConfig.blinkColon || root.clock.date.getSeconds() % 2 === 0 ? 1 : 0.3
                Behavior on opacity {
                    NumberAnimation { duration: 450; easing.type: Easing.InOutSine }
                }
            }
            Text {
                text: Qt.formatDateTime(root.clock.date, "mm")
                color: Theme.textSoft
                font.family: Theme.mono
                font.pixelSize: 14
                font.weight: Font.Medium
            }
            Text {
                visible: IslandConfig.showSeconds
                text: ":" + Qt.formatDateTime(root.clock.date, "ss")
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 14
                font.weight: Font.Medium
            }
            Text {
                visible: IslandConfig.clock12
                anchors.baseline: parent.children[0].baseline
                leftPadding: 3
                text: Qt.formatDateTime(root.clock.date, "AP").toLowerCase()
                color: Theme.textSoft
                font.family: Theme.sans
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        Glyph {
            visible: IslandConfig.showIndicators && ShellState.dnd
            text: "󰂛"
            size: 12
            color: Theme.textSoft
            Layout.alignment: Qt.AlignVCenter
        }

        Glyph {
            visible: IslandConfig.showIndicators && ShellState.caffeine
            text: "󰅶"
            size: 12
            color: Colors.tertiary
            Layout.alignment: Qt.AlignVCenter
        }

        Glyph {
            visible: Battery.present && (IslandConfig.battery === "always" ? true : IslandConfig.battery === "low" && Battery.low)
            text: Battery.icon
            size: 13
            color: Battery.low ? Colors.error : (Battery.charging ? Colors.primary : Theme.textSoft)
            Layout.alignment: Qt.AlignVCenter
        }

        Equalizer {
            visible: IslandConfig.showEqualizer && Media.present
            playing: Media.playing
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
