import QtQuick
import Quickshell.Widgets
import "root:/"

// Album art with a rounded clip and a glyph fallback while loading / absent.
ClippingRectangle {
    id: root

    property string source: ""
    property real size: 36

    implicitWidth: size
    implicitHeight: size
    radius: size * 0.28
    color: Theme.card

    Glyph {
        anchors.centerIn: parent
        text: "󰎆"
        size: root.size * 0.45
        color: Theme.textFaint
        visible: img.status !== Image.Ready
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 250 }
        }
    }
}
