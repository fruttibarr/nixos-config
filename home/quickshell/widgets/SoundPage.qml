import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/"
import "root:/services"

// Sound sub-page of the control center: pick the output (playback) device
// and input (microphone), with their levels. Switching sets PipeWire's
// preferred default, so apps that follow the default move over live and the
// choice is remembered.
FocusScope {
    id: root

    property bool active: false
    signal back
    signal openEq

    implicitHeight: column.implicitHeight

    component SectionLabel: Text {
        color: Theme.textSoft
        font.family: Theme.sans
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
    }

    component DeviceRow: Rectangle {
        id: row
        required property var modelData
        property bool input: false
        readonly property var node: modelData
        readonly property bool current: input ? Audio.source === node : Audio.sink === node

        Layout.fillWidth: true
        implicitHeight: 52
        radius: Theme.radiusCard
        color: current ? Theme.alpha(Colors.primary, 0.14)
            : hover.hovered ? Theme.cardHover : Theme.card
        border.width: current ? 1 : 0
        border.color: Theme.alpha(Colors.primary, 0.25)
        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        HoverHandler {
            id: hover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: row.current ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                if (row.current) return;
                if (row.input) Audio.setSource(row.node);
                else Audio.setSink(row.node);
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 14
            spacing: 12

            Rectangle {
                implicitWidth: 30
                implicitHeight: 30
                radius: 15
                color: row.current ? Colors.primary : Theme.track
                Glyph {
                    anchors.centerIn: parent
                    text: Audio.deviceIcon(row.node, row.input)
                    size: 15
                    color: row.current ? Colors.textOnPrimary : Colors.text
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: Audio.deviceName(row.node)
                    color: Colors.text
                    font.family: Theme.sans
                    font.pixelSize: 13
                    font.weight: row.current ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    // Card/driver line, only when it adds something.
                    text: {
                        const d = row.node?.description ?? "";
                        const n = Audio.deviceName(row.node);
                        if (row.current) return row.input ? "In use" : "Playing here";
                        return d && d !== n ? d : "";
                    }
                    color: row.current ? Colors.primary : Theme.textSoft
                    font.family: Theme.sans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Glyph {
                visible: row.current
                text: "󰄬"
                size: 15
                color: Colors.primary
            }
        }
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 12

        PageHeader {
            Layout.fillWidth: true
            title: "Sound"
            status: Audio.sink ? `Output: ${Audio.deviceName(Audio.sink)}` : "No output device"
            showToggle: false
            onBack: root.back()
        }

        // ---- output -----------------------------------------------------------
        SectionLabel {
            text: "Output"
        }
        LevelSlider {
            Layout.fillWidth: true
            icon: Audio.icon
            value: Audio.volume
            dimmed: Audio.muted
            onMoved: v => Audio.setVolume(v)
            onIconClicked: Audio.toggleMute()
        }
        Repeater {
            model: Audio.sinks
            DeviceRow {}
        }
        Text {
            visible: Audio.sinks.length === 0
            text: "No output devices"
            color: Theme.textFaint
            font.family: Theme.sans
            font.pixelSize: 11
        }
        Text {
            Layout.fillWidth: true
            visible: Audio.sinks.length === 1
            text: "Headphones on the jack switch automatically; HDMI and Bluetooth audio appear here when connected."
            color: Theme.textFaint
            font.family: Theme.sans
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        // ---- equalizer entry -------------------------------------------------
        Rectangle {
            id: eqRow
            Layout.fillWidth: true
            implicitHeight: 52
            radius: Theme.radiusCard
            color: eqHover.hovered ? Theme.cardHover : Theme.card
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            HoverHandler {
                id: eqHover
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openEq()
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12
                Rectangle {
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: 15
                    color: SoundEq.enabled ? Colors.primary : Theme.track
                    Glyph {
                        anchors.centerIn: parent
                        text: "󰺢"
                        size: 15
                        color: SoundEq.enabled ? Colors.textOnPrimary : Colors.text
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: "Equalizer"
                        color: Colors.text
                        font.family: Theme.sans
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                    Text {
                        Layout.fillWidth: true
                        text: !SoundEq.enabled ? "Off"
                            : SoundEq.preset === "custom" ? "Custom"
                            : SoundEq.presets.find(p => p.id === SoundEq.preset).label
                        color: SoundEq.enabled ? Colors.primary : Theme.textSoft
                        font.family: Theme.sans
                        font.pixelSize: 11
                    }
                }
                Glyph {
                    text: "󰅂"
                    size: 15
                    color: Theme.textSoft
                }
            }
        }

        // ---- input ------------------------------------------------------------
        SectionLabel {
            Layout.topMargin: 6
            text: "Input"
        }
        LevelSlider {
            Layout.fillWidth: true
            visible: Audio.source !== null
            icon: Audio.micMuted ? "󰍭" : "󰍬"
            value: Audio.micVolume
            dimmed: Audio.micMuted
            onMoved: v => Audio.setMicVolume(v)
            onIconClicked: Audio.toggleMic()
        }
        Repeater {
            model: Audio.sources
            DeviceRow {
                input: true
            }
        }

        // ---- escape hatch ------------------------------------------------------
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            text: "Advanced audio settings…"
            color: advMouse.containsMouse ? Colors.primary : Theme.textFaint
            font.family: Theme.sans
            font.pixelSize: 11
            MouseArea {
                id: advMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    ShellState.close();
                    Quickshell.execDetached(["sh", "-c", "pavucontrol || kitty -e alsamixer"]);
                }
            }
        }
    }
}
