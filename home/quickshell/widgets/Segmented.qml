import QtQuick
import "root:/"

// Segmented control with a sliding selection pill.
Rectangle {
    id: root

    property var options: []        // [{ value, label }]
    property var value
    signal picked(var v)

    readonly property int index: options.findIndex(o => o.value === value)

    implicitHeight: 32
    implicitWidth: 260
    radius: height / 2
    color: Theme.track

    readonly property real segW: options.length ? (width - 6) / options.length : 0

    Rectangle {
        visible: root.index >= 0
        x: 3 + root.index * root.segW
        y: 3
        width: root.segW
        height: parent.height - 6
        radius: height / 2
        color: Colors.primary
        Behavior on x {
            NumberAnimation { duration: 260; easing.type: Easing.OutQuint }
        }
    }

    Row {
        x: 3
        y: 3
        Repeater {
            model: root.options
            Item {
                required property var modelData
                required property int index
                width: root.segW
                height: root.height - 6

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.label
                    color: index === root.index ? Colors.textOnPrimary : Colors.text
                    font.family: Theme.sans
                    font.pixelSize: 11
                    font.weight: index === root.index ? Font.DemiBold : Font.Medium
                    Behavior on color {
                        ColorAnimation { duration: 160 }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData.value)
                }
            }
        }
    }
}
