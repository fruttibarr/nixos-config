import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/services"

// Now-playing card for the control center.
Rectangle {
    id: root

    implicitHeight: 104
    radius: Theme.radiusCard
    color: Theme.card
    clip: true

    // Album art bleeding faintly into the card gives it the wallpaper-y
    // tint Apple's media widgets have, without an effects pipeline.
    Image {
        anchors.fill: parent
        source: Media.art
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 128
        sourceSize.height: 128
        opacity: status === Image.Ready ? 0.10 : 0
        asynchronous: true
        Behavior on opacity {
            NumberAnimation { duration: 400 }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14

        ArtThumb {
            source: Media.art
            size: 80
            radius: 14
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: Media.title || "Nothing playing"
                color: Colors.text
                font.family: Theme.sans
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: Media.artist || (Media.player?.identity ?? "")
                color: Theme.textSoft
                font.family: Theme.sans
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            // Progress
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Theme.track
                visible: Media.length > 0

                Rectangle {
                    height: parent.height
                    radius: 2
                    color: Colors.primary
                    width: parent.width * Math.min(1, Media.position / Math.max(1, Media.length))
                    Behavior on width {
                        NumberAnimation { duration: 900; easing.type: Easing.Linear }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: Media.player?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => {
                        const frac = Math.max(0, Math.min(1, e.x / width));
                        Media.player.position = frac * Media.length;
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    visible: Media.length > 0
                    text: Media.fmt(Media.position)
                    color: Theme.textFaint
                    font.family: Theme.mono
                    font.pixelSize: 10
                }
                Item { Layout.fillWidth: true }
                IconButton {
                    icon: "󰒮"; size: 30; flat: true
                    onClicked: Media.previous()
                }
                IconButton {
                    icon: Media.playing ? "󰏤" : "󰐊"; size: 34; filled: true
                    onClicked: Media.toggle()
                }
                IconButton {
                    icon: "󰒭"; size: 30; flat: true
                    onClicked: Media.next()
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: Media.length > 0
                    text: Media.fmt(Media.length)
                    color: Theme.textFaint
                    font.family: Theme.mono
                    font.pixelSize: 10
                }
            }
        }
    }
}
