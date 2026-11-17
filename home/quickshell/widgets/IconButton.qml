import QtQuick
import "root:/"

// Round icon button with a soft hover/press wash.
Rectangle {
    id: root

    property string icon: ""
    property real size: 32
    property real iconSize: size * 0.46
    property bool filled: false        // solid primary disc (e.g. play)
    property bool danger: false        // tints red on hover (e.g. power)
    property bool flat: false          // no resting background
    property color iconColor: filled ? Colors.textOnPrimary : Colors.text
    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 2

    color: {
        if (filled) return mouse.pressed ? Qt.darker(Colors.primary, 1.15) : Colors.primary;
        if (mouse.pressed) return Theme.cardPressed;
        if (mouse.containsMouse) return danger ? Theme.alpha(Colors.error, 0.16) : Theme.cardHover;
        return flat ? Theme.alpha(Colors.text, 0) : Theme.card;
    }
    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    scale: mouse.pressed ? 0.92 : 1
    Behavior on scale {
        NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
    }

    Glyph {
        anchors.centerIn: parent
        text: root.icon
        size: root.iconSize
        color: root.danger && mouse.containsMouse ? Colors.error : root.iconColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
