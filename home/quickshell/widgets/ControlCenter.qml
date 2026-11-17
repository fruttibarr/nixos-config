import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "root:/"
import "root:/services"

// Control center that the island morphs into.
FocusScope {
    id: root

    signal closeRequested

    implicitWidth: 420
    implicitHeight: currentPage.implicitHeight + 36

    // "" (main grid), "wifi" or "bluetooth". The island tracks implicitHeight,
    // so switching pages also morphs the island to the new page's size.
    property string page: ""
    readonly property Item currentPage: page === "wifi" ? wifiPage
        : page === "bluetooth" ? btPage
        : page === "sound" ? soundPage : column

    function openPage(p) {
        page = p;
        root.forceActiveFocus();
    }

    // Esc steps back out of a sub-page before it closes the island.
    Keys.onEscapePressed: {
        if (page !== "") openPage("");
        else root.closeRequested();
    }

    // Main grid slides out left, sub-pages slide in from the right.
    WifiPage {
        id: wifiPage
        active: root.page === "wifi"
        x: active ? 18 : root.width + 18
        y: 18
        width: root.width - 36
        opacity: active ? 1 : 0
        visible: opacity > 0.01
        enabled: active
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.openPage("")
    }

    SoundPage {
        id: soundPage
        active: root.page === "sound"
        x: active ? 18 : root.width + 18
        y: 18
        width: root.width - 36
        opacity: active ? 1 : 0
        visible: opacity > 0.01
        enabled: active
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.openPage("")
    }

    BluetoothPage {
        id: btPage
        active: root.page === "bluetooth"
        x: active ? 18 : root.width + 18
        y: 18
        width: root.width - 36
        opacity: active ? 1 : 0
        visible: opacity > 0.01
        enabled: active
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.openPage("")
    }

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
    // For actions that open something on screen, get out of the way first.
    function runAndClose(cmd) {
        root.closeRequested();
        run(cmd);
    }

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btConnected: bt ? bt.devices.values.filter(d => d.connected) : []

    component SectionLabel: Text {
        color: Theme.textSoft
        font.family: Theme.sans
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
    }

    ColumnLayout {
        id: column
        readonly property bool active: root.page === ""
        x: active ? 18 : -width - 18
        y: 18
        width: root.width - 36
        spacing: 14
        opacity: active ? 1 : 0
        visible: opacity > 0.01
        enabled: active
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }

        // ---- header ------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                implicitWidth: 42
                implicitHeight: 42
                radius: 21
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Colors.primary }
                    GradientStop { position: 1; color: Colors.tertiary }
                }
                Text {
                    anchors.centerIn: parent
                    text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                    color: Colors.textOnPrimary
                    font.family: Theme.sans
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: Quickshell.env("USER") || "user"
                    color: Colors.text
                    font.family: Theme.sans
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: SysStats.uptime ? `up ${SysStats.uptime}` : "NixOS"
                    color: Theme.textSoft
                    font.family: Theme.sans
                    font.pixelSize: 11
                }
            }

            // The island morphs straight from here into the larger panels.
            IconButton {
                icon: "󰸉"
                onClicked: ShellState.switchTo("wallpapers")
            }
            IconButton {
                icon: "󰒓"
                onClicked: ShellState.switchTo("settings")
            }
            IconButton {
                icon: "󰹑"
                onClicked: root.runAndClose("sleep 0.4; grim -g \"$(slurp)\" - | wl-copy")
            }
            IconButton {
                icon: "󰌾"
                onClicked: root.runAndClose("hyprlock")
            }
            IconButton {
                icon: "󰐥"
                danger: true
                onClicked: root.runAndClose("wlogout")
            }
        }

        // ---- toggles -----------------------------------------------------
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Net.icon
                title: Net.wifiDevice ? "Wi-Fi" : "Network"
                subtitle: Net.label
                active: Net.wifiDevice ? Net.wifiOn : Net.wiredUp
                hasMore: true
                onToggled: if (Net.wifiDevice) Net.toggleWifi()
                onMore: root.openPage("wifi")
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                available: root.bt !== null
                icon: root.bt?.enabled ? (root.btConnected.length ? "󰂱" : "󰂯") : "󰂲"
                title: "Bluetooth"
                subtitle: {
                    if (!root.bt) return "Unavailable";
                    if (!root.bt.enabled) return "Off";
                    if (root.btConnected.length === 1) return root.btConnected[0].name;
                    if (root.btConnected.length > 1) return `${root.btConnected.length} devices`;
                    return "On";
                }
                active: root.bt?.enabled ?? false
                hasMore: true
                onToggled: if (root.bt) root.bt.enabled = !root.bt.enabled
                onMore: root.openPage("bluetooth")
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: ShellState.dnd ? "󰂛" : "󰂚"
                title: "Do Not Disturb"
                subtitle: ShellState.dnd ? "Toasts silenced" : "Off"
                active: ShellState.dnd
                onToggled: ShellState.dnd = !ShellState.dnd
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: ShellState.caffeine ? "󰅶" : "󰛊"
                title: "Caffeine"
                subtitle: ShellState.caffeine ? "Staying awake" : "Off"
                active: ShellState.caffeine
                onToggled: ShellState.caffeine = !ShellState.caffeine
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "󰖔"
                title: "Night Light"
                subtitle: ShellState.nightLight ? "4500K" : "Off"
                active: ShellState.nightLight
                onToggled: ShellState.nightLight = !ShellState.nightLight
            }

            Tile {
                id: powerTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1

                readonly property var profiles: PowerProfiles.hasPerformanceProfile
                    ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
                    : [PowerProfile.PowerSaver, PowerProfile.Balanced]
                readonly property int current: PowerProfiles.profile

                icon: current === PowerProfile.Performance ? "󰓅"
                    : current === PowerProfile.PowerSaver ? "󰌪" : "󰾅"
                title: "Power Mode"
                subtitle: current === PowerProfile.Performance ? "Performance"
                    : current === PowerProfile.PowerSaver ? "Power saver" : "Balanced"
                active: current !== PowerProfile.Balanced
                onToggled: {
                    const i = profiles.indexOf(current);
                    PowerProfiles.profile = profiles[(i + 1) % profiles.length];
                }
            }
        }

        // ---- sliders -----------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            // Volume, with a chevron into the Sound page (output/input devices).
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                LevelSlider {
                    Layout.fillWidth: true
                    icon: Audio.icon
                    value: Audio.volume
                    dimmed: Audio.muted
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                }
                IconButton {
                    icon: "󰅂"
                    size: 40
                    iconSize: 15
                    onClicked: root.openPage("sound")
                }
            }

            LevelSlider {
                Layout.fillWidth: true
                visible: Brightness.available
                icon: Brightness.value > 0.5 ? "󰃠" : "󰃟"
                value: Brightness.value
                onMoved: v => Brightness.set(v)
            }
        }

        // ---- media -------------------------------------------------------
        MediaCard {
            Layout.fillWidth: true
            visible: Media.present
        }

        // ---- vitals ------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: [
                    { label: "CPU", glyph: "󰻠", value: SysStats.cpu, text: SysStats.cpu + "%", hot: SysStats.cpu > 85 },
                    { label: "RAM", glyph: "󰍛", value: SysStats.mem, text: SysStats.mem + "%", hot: SysStats.mem > 85 },
                    { label: "TEMP", glyph: "󰔏", value: Math.max(0, Math.min(100, (SysStats.temp - 20) * 1.33)),
                      text: SysStats.temp + "°", hot: SysStats.temp > 80 },
                    { label: "BAT", glyph: Battery.icon, value: Battery.percent, text: Battery.percent + "%",
                      hot: Battery.low, hide: !Battery.present }
                ]

                Rectangle {
                    required property var modelData
                    visible: !modelData.hide
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 64
                    radius: Theme.radiusCard
                    color: Theme.card

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        ArcGauge {
                            implicitWidth: 34
                            implicitHeight: 34
                            thickness: 3
                            value: modelData.value
                            label: modelData.glyph
                            labelSize: 11
                            labelColor: modelData.hot ? Colors.error : Colors.text
                            arcColor: modelData.hot ? Colors.error : Colors.primary
                        }

                        ColumnLayout {
                            spacing: -2
                            Text {
                                text: modelData.text
                                color: Colors.text
                                font.family: Theme.mono
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: modelData.label
                                color: Theme.textFaint
                                font.family: Theme.sans
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.5
                            }
                        }
                    }
                }
            }
        }

        // ---- notifications -----------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2

            SectionLabel {
                text: "Notifications"
            }
            Text {
                visible: ShellState.history.length > 0
                text: ShellState.history.length
                color: Colors.primary
                font.family: Theme.mono
                font.pixelSize: 11
                font.weight: Font.Bold
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: ShellState.history.length > 0
                text: "Clear all"
                color: clearMouse.containsMouse ? Colors.primary : Theme.textSoft
                font.family: Theme.sans
                font.pixelSize: 11
                font.weight: Font.Medium
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.clearHistory()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 72
            visible: ShellState.history.length === 0

            Column {
                anchors.centerIn: parent
                spacing: 6
                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰂚"
                    size: 20
                    color: Theme.textFaint
                }
                Text {
                    text: "You're all caught up"
                    color: Theme.textSoft
                    font.family: Theme.sans
                    font.pixelSize: 12
                }
            }
        }

        ListView {
            id: notifList
            Layout.fillWidth: true
            visible: count > 0
            implicitHeight: Math.min(contentHeight, 232)
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: ShellState.history

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
            }
            removeDisplaced: Transition {
                NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic }
            }

            delegate: Rectangle {
                id: card
                required property var modelData

                width: ListView.view.width
                implicitHeight: body.implicitHeight + 22
                radius: Theme.radiusSmall + 4
                color: cardHover.hovered ? Theme.cardHover : Theme.card
                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                // Passive, so it stays hovered while over the close button.
                HoverHandler {
                    id: cardHover
                }

                RowLayout {
                    id: body
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 11
                    spacing: 10

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 10
                        color: Theme.alpha(Colors.primary, 0.15)
                        clip: true

                        Glyph {
                            anchors.centerIn: parent
                            visible: notifImg.status !== Image.Ready
                            text: "󰂚"
                            size: 14
                            color: Colors.primary
                        }
                        Image {
                            id: notifImg
                            anchors.fill: parent
                            source: card.modelData.image || card.modelData.appIcon || ""
                            sourceSize.width: 60
                            sourceSize.height: 60
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.summary
                                color: Colors.text
                                font.family: Theme.sans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                text: card.modelData.appName
                                color: Theme.textFaint
                                font.family: Theme.sans
                                font.pixelSize: 10
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: card.modelData.body
                            color: Theme.textSoft
                            font.family: Theme.sans
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        icon: "󰅖"
                        size: 22
                        flat: true
                        opacity: cardHover.hovered ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 140 }
                        }
                        onClicked: ShellState.removeHistory(card.modelData.id)
                    }
                }
            }
        }
    }
}
