import QtQuick
import "root:/"

// Three bars that bounce while audio is playing. This is the island's "live
// activity" tell: it shows something is happening without the island needing
// to expand. Bars are decorative motion, not real spectrum data.
Row {
    id: root

    property bool playing: false
    property color barColor: Colors.primary

    spacing: 2.5
    height: 13

    Repeater {
        model: [
            { base: 4, peak: 13, dur: 520 },
            { base: 7, peak: 10, dur: 380 },
            { base: 3, peak: 11, dur: 620 }
        ]

        Rectangle {
            required property var modelData
            required property int index

            width: 2.5
            radius: 1.25
            color: root.barColor
            anchors.verticalCenter: parent.verticalCenter

            height: modelData.base

            SequentialAnimation on height {
                running: root.playing
                loops: Animation.Infinite
                // Restores a calm, even state when playback stops.
                alwaysRunToEnd: false

                NumberAnimation {
                    to: modelData.peak
                    duration: modelData.dur
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: modelData.base
                    duration: modelData.dur
                    easing.type: Easing.InOutSine
                }
            }

            // Settle to a flat idle state when paused.
            Behavior on height {
                enabled: !root.playing
                NumberAnimation { duration: 240; easing.type: Easing.OutQuad }
            }

            opacity: root.playing ? 1 : 0.45
            Behavior on opacity {
                NumberAnimation { duration: 240 }
            }
        }
    }
}
