import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/services"

// Resolution / refresh / scale for one output. Changes apply immediately and
// revert by themselves after a countdown unless confirmed — a bad mode must
// never strand you on a black screen.
Rectangle {
    id: root

    required property var monitor   // one entry of `hyprctl -j monitors`

    implicitHeight: col.implicitHeight + 28
    radius: Theme.radiusCard
    color: Theme.card

    readonly property string name: monitor.name
    readonly property string liveMode:
        `${monitor.width}x${monitor.height}@${Number(monitor.refreshRate).toFixed(2)}`

    // "1920x1080@60.00Hz" -> { value: "1920x1080@60.00", label: "1920 × 1080 · 60 Hz" }
    readonly property var modeOptions: (monitor.availableModes ?? []).map(m => {
        const v = m.replace(/Hz$/, "");
        const [res, hz] = v.split("@");
        return { value: v, label: `${res.replace("x", " × ")} · ${Math.round(Number(hz))} Hz` };
    })
    readonly property var scaleOptions: [1, 1.25, 1.5, 2].map(s => ({ value: s, label: `${Math.round(s * 100)}%` }))

    // Find the option matching what's actually running.
    readonly property string currentMode: {
        const hit = modeOptions.find(o => o.value === liveMode)
            ?? modeOptions.find(o => o.value.split("@")[0] === liveMode.split("@")[0]);
        return hit?.value ?? liveMode;
    }
    readonly property real currentScale: Math.round(Number(monitor.scale) * 100) / 100

    // ---- confirm / revert (state lives in HyprSettings) ------------------
    readonly property bool pending: HyprSettings.monitorPending?.name === name

    function change(cfg) {
        HyprSettings.changeMonitor(name, cfg, { mode: currentMode, scale: currentScale });
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        anchors.leftMargin: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 12
                color: Theme.alpha(Colors.primary, 0.16)
                Glyph {
                    anchors.centerIn: parent
                    text: root.name.startsWith("eDP") ? "󰌢" : "󰍹"
                    size: 18
                    color: Colors.primary
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: root.monitor.description || root.name
                    color: Colors.text
                    font.family: Theme.sans
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    text: `${root.name} · ${root.monitor.width}×${root.monitor.height} @ ${Math.round(root.monitor.refreshRate)} Hz · ${Math.round(root.currentScale * 100)}%`
                    color: Theme.textSoft
                    font.family: Theme.sans
                    font.pixelSize: 11
                }
            }
            IconButton {
                visible: root.name in HyprSettings.monitorOverrides
                icon: "󰑓"
                size: 26
                flat: true
                onClicked: root.change({ mode: HyprSettings.monitorBase.mode, scale: HyprSettings.monitorBase.scale })
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 14
            rowSpacing: 10

            Text {
                text: "Resolution"
                color: Colors.text
                font.family: Theme.sans
                font.pixelSize: 13
                font.weight: Font.Medium
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 7
            }
            ChoiceMenu {
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                Layout.alignment: Qt.AlignRight
                options: root.modeOptions
                value: root.currentMode
                onPicked: v => root.change({ mode: v })
            }

            Text {
                text: "Scale"
                color: Colors.text
                font.family: Theme.sans
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Segmented {
                Layout.preferredWidth: 300
                Layout.alignment: Qt.AlignRight
                options: root.scaleOptions
                value: root.currentScale
                onPicked: v => root.change({ scale: v })
            }
        }

        // Confirmation banner
        Rectangle {
            Layout.fillWidth: true
            visible: root.pending
            implicitHeight: 46
            radius: 14
            color: Theme.alpha(Colors.primary, 0.14)
            border.width: 1
            border.color: Theme.alpha(Colors.primary, 0.3)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: `Keep these display settings? Reverting in ${HyprSettings.monitorCountdown}s`
                    color: Colors.text
                    font.family: Theme.sans
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Rectangle {
                    implicitWidth: 72
                    implicitHeight: 30
                    radius: 15
                    color: Theme.card
                    Text {
                        anchors.centerIn: parent
                        text: "Revert"
                        color: Colors.text
                        font.family: Theme.sans
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: HyprSettings.revertMonitor()
                    }
                }
                Rectangle {
                    implicitWidth: 64
                    implicitHeight: 30
                    radius: 15
                    color: Colors.primary
                    Text {
                        anchors.centerIn: parent
                        text: "Keep"
                        color: Colors.textOnPrimary
                        font.family: Theme.sans
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: HyprSettings.keepMonitor()
                    }
                }
            }
        }
    }
}
