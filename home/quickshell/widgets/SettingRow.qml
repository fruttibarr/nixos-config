import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/services"

// One setting: label + hint on the left, a control chosen from the field's
// type on the right, and a reset button once it differs from the default.
Item {
    id: root

    required property var field
    readonly property var value: HyprSettings.get(field.key)
    readonly property bool isDefault: HyprSettings.isDefault(field.key)
    readonly property bool active: HyprSettings.enabled(field.key)
    property bool showSection: false   // prefix with section name (search results)

    implicitHeight: Math.max(52, row.implicitHeight + 20)
    opacity: active ? 1 : 0.4
    enabled: active
    Behavior on opacity {
        NumberAnimation { duration: 180 }
    }

    // Short choice lists fit a segmented control; long ones get a dropdown.
    readonly property bool segmented: field.type === "choice"
        && field.options.length <= 4
        && field.options.reduce((n, o) => n + o.label.length, 0) <= 30

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 10
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.showSection
                    ? `${HyprSettings.sections.find(s => s.id === root.field.section)?.label} › ${root.field.label}`
                    : root.field.label
                color: Colors.text
                font.family: Theme.sans
                font.pixelSize: 13
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: !!root.field.hint
                text: root.field.hint ?? ""
                color: Theme.textFaint
                font.family: Theme.sans
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        // ---- control ------------------------------------------------------
        Item {
            Layout.preferredWidth: root.field.type === "bool" ? toggle.implicitWidth : 260
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            implicitHeight: loader.item ? loader.item.implicitHeight : 32

            Loader {
                id: loader
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: {
                    switch (root.field.type) {
                    case "bool": return boolC;
                    case "int":
                    case "float": return sliderC;
                    case "text": return textC;
                    default: return root.segmented ? segC : menuC;
                    }
                }
            }

            Toggle {
                id: toggle
                visible: false
            }
        }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "󰑓"
            size: 26
            flat: true
            opacity: root.isDefault ? 0 : 1
            enabled: !root.isDefault
            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }
            onClicked: HyprSettings.reset(root.field.key)
        }
    }

    Component {
        id: boolC
        Item {
            implicitHeight: 26
            Toggle {
                anchors.right: parent.right
                checked: !!root.value
                onToggled: HyprSettings.set(root.field.key, !root.value)
            }
        }
    }

    Component {
        id: sliderC
        SettingSlider {
            value: root.value
            from: root.field.min
            to: root.field.max
            step: root.field.step ?? 1
            unit: root.field.unit ?? ""
            percent: !!root.field.percent
            onMoved: v => HyprSettings.set(root.field.key, v)
        }
    }

    Component {
        id: segC
        Segmented {
            options: root.field.options
            value: root.value
            onPicked: v => HyprSettings.set(root.field.key, v)
        }
    }

    Component {
        id: menuC
        ChoiceMenu {
            options: root.field.options
            value: root.value
            onPicked: v => HyprSettings.set(root.field.key, v)
        }
    }

    Component {
        id: textC
        Rectangle {
            implicitHeight: 32
            radius: 16
            color: Theme.track
            border.width: 1
            border.color: input.activeFocus ? Theme.alpha(Colors.primary, 0.45) : "transparent"

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                text: root.value ?? ""
                color: Colors.text
                selectionColor: Theme.alpha(Colors.primary, 0.4)
                font.family: Theme.mono
                font.pixelSize: 12
                clip: true
                // Applied on Enter / focus loss — a half-typed layout name
                // would otherwise flip the keyboard mid-word.
                onEditingFinished: HyprSettings.set(root.field.key, text)

                // Typing breaks the `text` binding, so follow resets by hand.
                Connections {
                    target: root
                    function onValueChanged() {
                        if (!input.activeFocus) input.text = root.value ?? "";
                    }
                }
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0 && !input.activeFocus
                text: root.field.placeholder ?? ""
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 12
            }
        }
    }
}
