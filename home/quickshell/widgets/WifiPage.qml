import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import "root:/"
import "root:/services"

// Wi-Fi sub-page of the control center.
//
// Tap a saved or open network to join it; tap a secured new one to reveal an
// inline password field. Tap the connected network (or right-click a saved
// one) for Disconnect / Connect / Forget.
FocusScope {
    id: root

    property bool active: false
    signal back

    implicitHeight: column.implicitHeight

    readonly property var device: Net.wifiDevice

    // Rounded action button used in an expanded row.
    component ActionPill: Rectangle {
        property string label: ""
        property bool danger: false
        signal activated
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 17
        color: pillMouse.containsMouse
            ? (danger ? Theme.alpha(Colors.error, 0.18) : Theme.cardPressed)
            : Theme.track
        Text {
            anchors.centerIn: parent
            text: parent.label
            color: parent.danger ? Colors.error : Colors.text
            font.family: Theme.sans
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.activated()
        }
    }

    // Scan only while the page is on screen.
    Binding {
        target: root.device
        property: "scannerEnabled"
        value: true
        when: root.active && root.device !== null && Net.wifiOn
    }

    // One row per SSID (strongest AP wins), hidden networks dropped.
    readonly property var networks: {
        if (!device) return [];
        const best = {};
        for (const n of device.networks.values) {
            if (!n.name) continue;
            const cur = best[n.name];
            if (!cur || n.connected || (!cur.connected && n.signalStrength > cur.signalStrength))
                best[n.name] = n;
        }
        // Sort by signal *band*, then name: raw strength jitters during a
        // scan and would shuffle rows out from under the cursor.
        const band = n => Math.round(n.signalStrength * 3);
        return Object.values(best).sort((a, b) =>
            (b.connected - a.connected) || (b.known - a.known)
            || (band(b) - band(a)) || a.name.localeCompare(b.name));
    }

    // Name of the row whose actions/password field are open.
    property string expanded: ""
    // SSID -> message from the last failed attempt.
    property var errors: ({})

    onActiveChanged: if (!active) { expanded = ""; errors = {}; }

    function setError(name, msg) {
        const e = Object.assign({}, errors);
        if (msg) e[name] = msg; else delete e[name];
        errors = e;
    }

    function isSecured(n) {
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
    }

    function signalIcon(s) {
        if (s > 0.75) return "󰤨";
        if (s > 0.5) return "󰤥";
        if (s > 0.25) return "󰤢";
        return "󰤟";
    }

    function failText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets: return "Password required";
        case ConnectionFailReason.WifiAuthTimeout: return "Wrong password?";
        case ConnectionFailReason.WifiNetworkLost: return "Network out of range";
        default: return "Couldn't connect";
        }
    }

    function activate(n) {
        setError(n.name, "");
        if (n.connected) {
            expanded = expanded === n.name ? "" : n.name;
        } else if (n.known || !isSecured(n)) {
            expanded = "";
            n.connect();
        } else {
            expanded = expanded === n.name ? "" : n.name;
        }
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 14

        PageHeader {
            Layout.fillWidth: true
            title: "Wi-Fi"
            status: !Net.wifiOn ? "Off"
                : Net.wifiNetwork ? `Connected to ${Net.wifiNetwork.name}`
                : (root.device?.scannerEnabled ? "Scanning…" : "Not connected")
            working: Net.wifiOn && (root.device?.scannerEnabled ?? false)
            checked: Net.wifiOn
            onBack: root.back()
            onToggled: Net.toggleWifi()
        }

        // ---- off / no hardware ---------------------------------------------
        Item {
            Layout.fillWidth: true
            implicitHeight: 120
            visible: !Net.wifiOn || !root.device

            Column {
                anchors.centerIn: parent
                spacing: 8
                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰤮"
                    size: 28
                    color: Theme.textFaint
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: !root.device ? "No Wi-Fi adapter" : "Wi-Fi is off"
                    color: Theme.textSoft
                    font.family: Theme.sans
                    font.pixelSize: 12
                }
            }
        }

        // ---- network list --------------------------------------------------
        ListView {
            id: list
            Layout.fillWidth: true
            visible: Net.wifiOn && root.device !== null
            implicitHeight: Math.min(contentHeight, 380)
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: root.networks

            Behavior on implicitHeight {
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }

            delegate: Rectangle {
                id: row
                required property var modelData

                readonly property var net: modelData
                readonly property bool open: root.expanded === net.name
                readonly property bool secured: root.isSecured(net)
                readonly property bool needsPassword: open && !net.connected && !net.known && secured
                readonly property bool busy: net.stateChanging
                    || net.state === ConnectionState.Connecting
                    || net.state === ConnectionState.Disconnecting
                readonly property string error: root.errors[net.name] ?? ""

                width: ListView.view.width
                implicitHeight: content.implicitHeight + 20
                radius: Theme.radiusCard
                color: net.connected ? Theme.alpha(Colors.primary, 0.14)
                    : hover.hovered || open ? Theme.cardHover : Theme.card
                border.width: net.connected ? 1 : 0
                border.color: Theme.alpha(Colors.primary, 0.25)

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
                Behavior on implicitHeight {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                HoverHandler {
                    id: hover
                }

                Connections {
                    target: row.net
                    function onConnectionFailed(reason) {
                        root.setError(row.net.name, root.failText(reason));
                        if (reason === ConnectionFailReason.NoSecrets && row.secured)
                            root.expanded = row.net.name;
                    }
                    function onConnectedChanged() {
                        if (row.net.connected) {
                            root.setError(row.net.name, "");
                            if (root.expanded === row.net.name) root.expanded = "";
                        }
                    }
                }

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 50
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    // Right-click a saved network for Connect / Forget.
                    onClicked: e => {
                        if (e.button === Qt.RightButton && row.net.known)
                            root.expanded = root.expanded === row.net.name ? "" : row.net.name;
                        else
                            root.activate(row.net);
                    }
                }

                ColumnLayout {
                    id: content
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    anchors.leftMargin: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 15
                            color: row.net.connected ? Colors.primary : Theme.track

                            Glyph {
                                anchors.centerIn: parent
                                text: root.signalIcon(row.net.signalStrength)
                                size: 15
                                color: row.net.connected ? Colors.textOnPrimary : Colors.text
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: row.net.name
                                color: Colors.text
                                font.family: Theme.sans
                                font.pixelSize: 13
                                font.weight: row.net.connected ? Font.DemiBold : Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: {
                                    if (row.busy) return row.net.connected ? "Disconnecting…" : "Connecting…";
                                    if (row.error) return row.error;
                                    if (row.net.connected) return "Connected";
                                    if (row.net.known) return "Saved";
                                    return row.secured ? "Secured" : "Open";
                                }
                                color: row.error && !row.busy ? Colors.error
                                    : row.net.connected || row.busy ? Colors.primary : Theme.textSoft
                                font.family: Theme.sans
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        Glyph {
                            visible: row.secured
                            text: "󰌾"
                            size: 12
                            color: Theme.textFaint
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
                    }

                    // ---- password entry ------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        visible: row.needsPassword
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: 18
                            color: Theme.track
                            border.width: 1
                            border.color: pw.activeFocus ? Theme.alpha(Colors.primary, 0.45) : "transparent"

                            TextInput {
                                id: pw
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 36
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: reveal.shown ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "•"
                                color: Colors.text
                                selectionColor: Theme.alpha(Colors.primary, 0.4)
                                font.family: Theme.sans
                                font.pixelSize: 13
                                clip: true

                                onVisibleChanged: {
                                    text = "";
                                    if (visible) forceActiveFocus();
                                }
                                Keys.onReturnPressed: joinBtn.join()
                                Keys.onEnterPressed: joinBtn.join()
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                visible: pw.text.length === 0
                                text: "Password"
                                color: Theme.textFaint
                                font.family: Theme.sans
                                font.pixelSize: 13
                            }

                            Glyph {
                                id: reveal
                                property bool shown: false
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: shown ? "󰈈" : "󰈉"
                                size: 14
                                color: Theme.textSoft
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: reveal.shown = !reveal.shown
                                }
                            }
                        }

                        Rectangle {
                            id: joinBtn
                            implicitWidth: joinText.implicitWidth + 28
                            implicitHeight: 36
                            radius: 18
                            readonly property bool ready: pw.text.length >= 8
                                || row.net.security === WifiSecurityType.StaticWep
                            color: ready ? Colors.primary : Theme.track
                            opacity: ready ? 1 : 0.6

                            function join() {
                                if (!ready) return;
                                root.setError(row.net.name, "");
                                row.net.connectWithPsk(pw.text);
                            }

                            Text {
                                id: joinText
                                anchors.centerIn: parent
                                text: "Join"
                                color: joinBtn.ready ? Colors.textOnPrimary : Colors.text
                                font.family: Theme.sans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: joinBtn.join()
                            }
                        }
                    }

                    // ---- actions for connected / saved ---------------------
                    RowLayout {
                        Layout.fillWidth: true
                        visible: row.open && (row.net.connected || row.net.known) && !row.needsPassword
                        spacing: 8

                        ActionPill {
                            label: row.net.connected ? "Disconnect" : "Connect"
                            onActivated: {
                                if (row.net.connected) row.net.disconnect();
                                else row.net.connect();
                                root.expanded = "";
                            }
                        }
                        ActionPill {
                            label: "Forget"
                            danger: true
                            onActivated: {
                                row.net.forget();
                                root.expanded = "";
                            }
                        }
                    }
                }
            }
        }

        // ---- escape hatch -----------------------------------------------------
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Advanced network settings…"
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
                    Quickshell.execDetached(["sh", "-c", "nm-connection-editor || kitty -e nmtui"]);
                }
            }
        }
    }
}
