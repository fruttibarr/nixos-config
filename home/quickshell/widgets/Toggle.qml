import QtQuick
import "root:/"

// Pill switch.
Rectangle {
    id: root

    property bool checked: false
    property bool busy: false
    signal toggled

    implicitWidth: 44
    implicitHeight: 26
    radius: height / 2
    color: checked ? Colors.primary : Theme.track
    Behavior on color {
        ColorAnimation { duration: 180 }
    }

    Rectangle {
        id: knob
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Colors.textOnPrimary : Colors.text
        Behavior on x {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        Behavior on color {
            ColorAnimation { duration: 180 }
        }

        // Pulses while the backend is still catching up with the request.
        SequentialAnimation on opacity {
            running: root.busy
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.4; duration: 450 }
            NumberAnimation { to: 1; duration: 450 }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
