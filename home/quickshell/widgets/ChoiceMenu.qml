import QtQuick
import QtQuick.Layouts
import "root:/"

// Dropdown that expands inline (no popup surface needed inside the island).
ColumnLayout {
    id: root

    property var options: []        // [{ value, label }]
    property var value
    property bool expanded: false
    signal picked(var v)

    spacing: 4

    readonly property var current: options.find(o => o.value === value)

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 16
        color: head.containsMouse || root.expanded ? Theme.cardHover : Theme.track

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            Text {
                Layout.fillWidth: true
                text: root.current?.label ?? String(root.value ?? "")
                elide: Text.ElideRight
                color: Colors.text
                font.family: Theme.sans
                font.pixelSize: 12
            }
            Glyph {
                text: "󰅀"
                size: 13
                color: Theme.textSoft
                rotation: root.expanded ? 180 : 0
                Behavior on rotation {
                    NumberAnimation { duration: 200 }
                }
            }
        }
        MouseArea {
            id: head
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Rectangle {
        Layout.fillWidth: true
        visible: root.expanded
        implicitHeight: list.implicitHeight + 8
        radius: 14
        color: Theme.track

        Column {
            id: list
            x: 4
            y: 4
            width: parent.width - 8
            Repeater {
                model: root.options
                Rectangle {
                    required property var modelData
                    width: list.width
                    height: 30
                    radius: 10
                    readonly property bool sel: modelData.value === root.value
                    color: sel ? Theme.alpha(Colors.primary, 0.18) : (m.containsMouse ? Theme.cardHover : "transparent")
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: parent.sel ? Colors.primary : Colors.text
                        font.family: Theme.sans
                        font.pixelSize: 12
                        font.weight: parent.sel ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: m
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.expanded = false;
                            root.picked(modelData.value);
                        }
                    }
                }
            }
        }
    }
}
