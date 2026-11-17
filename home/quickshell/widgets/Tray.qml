import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "root:/"

Pill {
    id: root

    visible: SystemTray.items.values.length > 0

    RowLayout {
        spacing: 8

        Repeater {
            model: SystemTray.items

            Image {
                required property SystemTrayItem modelData

                source: modelData.icon
                // Image.implicitWidth/Height are read-only; sourceSize is what
                // drives implicit size (and renders the icon at native scale).
                sourceSize.width: 15
                sourceSize.height: 15
                fillMode: Image.PreserveAspectFit
                smooth: true

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        if (event.button === Qt.LeftButton) {
                            modelData.activate();
                        } else {
                            modelData.secondaryActivate();
                        }
                    }
                }
            }
        }
    }
}
