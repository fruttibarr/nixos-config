import QtQuick
import "root:/"

// A Nerd Font icon, centred in a square box so icons of differing advance
// widths still line up in rows and buttons.
Text {
    property real size: 14

    color: Colors.text
    font.family: Theme.icons
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    width: Math.max(implicitWidth, size)
    height: size
}
