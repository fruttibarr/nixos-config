import QtQuick
import Quickshell
import "root:/"

Pill {
    id: root
    interactive: true

    readonly property var now: clock.date

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    property bool showDate: false

    onClicked: showDate = !showDate

    Text {
        text: root.showDate
            ? Qt.formatDateTime(root.now, "ddd d MMM  hh:mm")
            : Qt.formatDateTime(root.now, "hh:mm")
        color: Colors.text
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.weight: Font.Medium
    }
}
