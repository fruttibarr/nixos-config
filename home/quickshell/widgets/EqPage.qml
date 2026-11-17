import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/services"

// Equalizer sub-page of the control center (reached from Sound). Five
// vertical sliders over a 0 dB centre line; the fill grows up for a boost and
// down for a cut. Applies system-wide through services/SoundEq.qml.
FocusScope {
    id: root

    property bool active: false
    signal back

    implicitHeight: column.implicitHeight

    // One band: dB readout · slider · frequency.
    component BandSlider: ColumnLayout {
        id: band
        required property int index
        required property var modelData

        readonly property real db: SoundEq.gains[index]
        readonly property real maxDb: SoundEq.maxDb
        readonly property bool live: SoundEq.enabled

        spacing: 8
        Layout.fillWidth: true

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: (band.db > 0 ? "+" : "") + (band.db % 1 === 0 ? band.db.toFixed(0) : band.db.toFixed(1))
            color: band.db !== 0 && band.live ? Colors.primary : Theme.textSoft
            font.family: Theme.mono
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        Item {
            id: track
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 34
            implicitHeight: 168

            // value (dB) <-> y, with +max at the top.
            function yFor(v) {
                return (1 - (v + band.maxDb) / (2 * band.maxDb)) * height;
            }
            readonly property real zeroY: yFor(0)
            readonly property real knobY: yFor(band.db)

            Rectangle {
                id: rail
                anchors.horizontalCenter: parent.horizontalCenter
                width: 6
                height: parent.height
                radius: 3
                color: Theme.track
            }

            // 0 dB tick
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: track.zeroY - height / 2
                width: 16
                height: 2
                radius: 1
                color: Theme.alpha(Colors.text, 0.18)
            }

            // Fill from the centre line to the knob.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 6
                radius: 3
                y: Math.min(track.zeroY, track.knobY)
                height: Math.abs(track.knobY - track.zeroY)
                color: band.live ? Colors.primary : Theme.textFaint
                Behavior on y {
                    enabled: !drag.pressed
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    enabled: !drag.pressed
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                id: knob
                anchors.horizontalCenter: parent.horizontalCenter
                y: track.knobY - height / 2
                width: drag.pressed ? 22 : 18
                height: width
                radius: width / 2
                color: band.live ? Colors.primary : Theme.textSoft
                border.width: 3
                border.color: Theme.island
                Behavior on y {
                    enabled: !drag.pressed
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on width {
                    NumberAnimation { duration: 120 }
                }
            }

            MouseArea {
                id: drag
                anchors.fill: parent
                anchors.topMargin: -10
                anchors.bottomMargin: -10
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function set(my) {
                    const y = Math.max(0, Math.min(track.height, my - 10));
                    SoundEq.setGain(band.index, (1 - y / track.height) * 2 * band.maxDb - band.maxDb);
                }
                onPressed: e => set(e.y)
                onPositionChanged: e => { if (pressed) set(e.y); }
                onDoubleClicked: SoundEq.setGain(band.index, 0)
                onWheel: w => SoundEq.setGain(band.index, band.db + (w.angleDelta.y > 0 ? 1 : -1))
            }
        }

        Column {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: band.modelData.label
                color: Colors.text
                font.family: Theme.mono
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: band.modelData.name
                color: Theme.textFaint
                font.family: Theme.sans
                font.pixelSize: 9
            }
        }
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 14

        PageHeader {
            Layout.fillWidth: true
            title: "Equalizer"
            status: !SoundEq.available ? "Filter isn't running (restart PipeWire)"
                : !SoundEq.enabled ? "Off · sound is unchanged"
                : SoundEq.preset === "custom" ? "Custom curve"
                : `${SoundEq.presets.find(p => p.id === SoundEq.preset).label} preset`
            checked: SoundEq.enabled
            onToggled: SoundEq.setEnabled(!SoundEq.enabled)
            onBack: root.back()
        }

        Segmented {
            Layout.fillWidth: true
            options: SoundEq.presets.map(p => ({ value: p.id, label: p.label }))
            // No pill while off or on a custom curve.
            value: SoundEq.enabled ? SoundEq.preset : ""
            onPicked: v => SoundEq.setPreset(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: sliders.implicitHeight + 32
            radius: Theme.radiusCard
            color: Theme.card
            opacity: SoundEq.available ? 1 : 0.5

            // dB scale on the left edge.
            // Lines up with the tracks: 16 px margin + the readout row above them.
            Item {
                x: 10
                y: 16 + sliders.trackTop
                width: 22
                height: 168
                Repeater {
                    model: [["+12", 0], ["0", 0.5], ["−12", 1]]
                    Text {
                        required property var modelData
                        y: modelData[1] * parent.height - height / 2
                        text: modelData[0]
                        color: Theme.textFaint
                        font.family: Theme.mono
                        font.pixelSize: 9
                    }
                }
            }

            RowLayout {
                id: sliders
                // dB readout line height + spacing, i.e. where the tracks start.
                readonly property real trackTop: 15 + 8
                anchors.fill: parent
                anchors.margins: 16
                anchors.leftMargin: 36
                spacing: 0
                Repeater {
                    model: SoundEq.bands
                    BandSlider {}
                }
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Applies to every app · scroll to nudge · double-click to reset a band"
            color: Theme.textFaint
            font.family: Theme.sans
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }
    }
}
