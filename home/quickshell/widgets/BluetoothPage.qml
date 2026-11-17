import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "root:/"

// Bluetooth sub-page of the control center.
//
// Paired devices: click to connect / disconnect, hover for Forget.
// Nearby devices: click to pair — the device is then trusted (so it can
// reconnect on its own later) and connected in one go.
FocusScope {
    id: root

    property bool active: false
    signal back

    implicitHeight: column.implicitHeight

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false

    // Discover only while the page is on screen.
    Binding {
        target: root.adapter
        property: "discovering"
        value: true
        when: root.active && root.on
    }
    // Likewise pairable: the bt-agent user service (chasec.nix) accepts
    // pairing without prompting, so only open that window while you're here.
    Binding {
        target: root.adapter
        property: "pairable"
        value: true
        when: root.active && root.on
    }

    // Unnamed devices advertise their MAC as their name; they're noise.
    function hasRealName(d) {
        return d.name && !/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(d.name);
    }

    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var paired: devices.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: devices.filter(d => !d.paired && !d.bonded && hasRealName(d))
        .sort((a, b) => a.name.localeCompare(b.name))

    // Devices we asked to pair; once pairing lands they get trusted + connected.
    property var pendingPair: ({})

    function pair(d) {
        const p = Object.assign({}, pendingPair);
        p[d.address] = true;
        pendingPair = p;
        d.pair();
    }

    function deviceIcon(icon) {
        const i = icon ?? "";
        if (i.includes("headset") || i.includes("headphone")) return "󰋋";
        if (i.includes("audio") || i.includes("speaker")) return "󰓃";
        if (i.includes("mouse")) return "󰍽";
        if (i.includes("keyboard")) return "󰌌";
        if (i.includes("gaming") || i.includes("joystick")) return "󰊗";
        if (i.includes("phone")) return "󰏲";
        if (i.includes("computer")) return "󰟀";
        if (i.includes("watch")) return "󰖉";
        return "󰂯";
    }

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
        readonly property var dev: modelData
        readonly property bool busy: dev.pairing
            || dev.state === BluetoothDeviceState.Connecting
            || dev.state === BluetoothDeviceState.Disconnecting
        readonly property bool isPaired: dev.paired || dev.bonded

        Layout.fillWidth: true
        implicitHeight: 52
        radius: Theme.radiusCard
        color: dev.connected ? Theme.alpha(Colors.primary, 0.14)
            : hover.hovered ? Theme.cardHover : Theme.card
        border.width: dev.connected ? 1 : 0
        border.color: Theme.alpha(Colors.primary, 0.25)
        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        HoverHandler {
            id: hover
        }

        Connections {
            target: row.dev
            function onPairedChanged() {
                if (!row.dev.paired || !root.pendingPair[row.dev.address]) return;
                const p = Object.assign({}, root.pendingPair);
                delete p[row.dev.address];
                root.pendingPair = p;
                row.dev.trusted = true;
                row.dev.connect();
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (row.busy) return;
                if (!row.isPaired) root.pair(row.dev);
                else if (row.dev.connected) row.dev.disconnect();
                else row.dev.connect();
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 12

            Rectangle {
                implicitWidth: 30
                implicitHeight: 30
                radius: 15
                color: row.dev.connected ? Colors.primary : Theme.track
                Glyph {
                    anchors.centerIn: parent
                    text: root.deviceIcon(row.dev.icon)
                    size: 15
                    color: row.dev.connected ? Colors.textOnPrimary : Colors.text
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: row.dev.name
                    color: Colors.text
                    font.family: Theme.sans
                    font.pixelSize: 13
                    font.weight: row.dev.connected ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: {
                        if (row.dev.pairing) return "Pairing…";
                        if (row.dev.state === BluetoothDeviceState.Connecting) return "Connecting…";
                        if (row.dev.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
                        if (row.dev.connected)
                            return row.dev.batteryAvailable
                                ? `Connected · ${Math.round(row.dev.battery * 100)}%` : "Connected";
                        return row.isPaired ? "Not connected" : "Click to pair";
                    }
                    color: row.dev.connected || row.busy ? Colors.primary : Theme.textSoft
                    font.family: Theme.sans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Glyph {
                visible: row.busy
                text: "󰑓"
                size: 13
                color: Colors.primary
                RotationAnimation on rotation {
                    running: row.busy
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 900
                }
            }

            IconButton {
                visible: row.isPaired && !row.busy
                opacity: hover.hovered ? 1 : 0
                icon: "󰆴"
                size: 28
                flat: true
                danger: true
                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }
                onClicked: row.dev.forget()
            }
        }
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 12

        PageHeader {
            Layout.fillWidth: true
            title: "Bluetooth"
            status: !root.adapter ? "Unavailable"
                : !root.on ? "Off"
                : root.adapter.discovering ? "Searching for devices…" : "On"
            working: root.on && (root.adapter?.discovering ?? false)
            checked: root.on
            showToggle: root.adapter !== null
            onBack: root.back()
            onToggled: root.adapter.enabled = !root.adapter.enabled
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 120
            visible: !root.on

            Column {
                anchors.centerIn: parent
                spacing: 8
                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰂲"
                    size: 28
                    color: Theme.textFaint
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.adapter ? "Bluetooth is off" : "No Bluetooth adapter"
                    color: Theme.textSoft
                    font.family: Theme.sans
                    font.pixelSize: 12
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            visible: root.on
            implicitHeight: Math.min(lists.implicitHeight, 400)
            contentHeight: lists.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Behavior on implicitHeight {
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: lists
                width: parent.width
                spacing: 6

                SectionLabel {
                    visible: root.paired.length > 0
                    text: "My devices"
                }
                Repeater {
                    model: root.paired
                    DeviceRow {}
                }

                SectionLabel {
                    Layout.topMargin: root.paired.length > 0 ? 8 : 0
                    text: "Nearby"
                }
                Repeater {
                    model: root.nearby
                    DeviceRow {}
                }
                Text {
                    visible: root.nearby.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Layout.bottomMargin: 4
                    text: root.adapter?.discovering
                        ? "Looking for devices in pairing mode…"
                        : "No devices found"
                    color: Theme.textFaint
                    font.family: Theme.sans
                    font.pixelSize: 11
                }
            }
        }
    }
}
