import QtQuick
import "root:/"

// Shared rounded container used by every bar widget so spacing, radius and
// hover feedback stay consistent across the bar.
Rectangle {
    id: root

    property bool interactive: false
    property bool active: false
    // `flat` drops the pill's own background so the widget can sit directly on
    // a shared surface (the dynamic island) without looking nested.
    property bool flat: false
    default property alias content: inner.data

    implicitWidth: inner.childrenRect.width + (root.flat ? 0 : 20)
    implicitHeight: root.flat ? inner.childrenRect.height : 26
    radius: root.flat ? 0 : 13

    color: root.active
        ? Colors.primary
        : (mouse.containsMouse && root.interactive && !root.flat
            ? Colors.surfaceBright
            : (root.flat ? "transparent" : Colors.surface))

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    signal clicked()

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.interactive
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    Item {
        id: inner
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }
}
