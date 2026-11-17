import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "root:/"
import "root:/services"

// Wallpaper switcher that the island morphs into.
//
//  - type to filter by file or folder name; Tab / Shift+Tab cycle collections
//  - arrows move the highlight, Enter (or click) applies — the island stays
//    open so you can audition several while the palette re-themes live
//  - Esc clears the search first, then closes
FocusScope {
    id: root

    signal closeRequested

    readonly property int columns: 4
    readonly property int visibleRows: 3
    readonly property int pad: 18

    implicitWidth: 880
    implicitHeight: column.implicitHeight + pad * 2

    // "all", "recent", or a collection's absolute directory path.
    property string collection: "all"
    readonly property string query: search.text.trim().toLowerCase()

    function activate() {
        search.text = "";
        search.forceActiveFocus();
        if (Wallpapers.all.length === 0) Wallpapers.refresh();
        focusCurrent();
    }

    function focusCurrent() {
        const i = items.indexOf(Wallpapers.current);
        grid.currentIndex = Math.max(0, i);
        grid.positionViewAtIndex(grid.currentIndex, GridView.Center);
    }

    // ---- filtering: one pass over the library, never per delegate -------------
    readonly property var items: {
        const q = query;
        const c = collection;
        const all = Wallpapers.all;

        if (c === "recent") {
            return q === "" ? Wallpapers.recent
                : Wallpapers.recent.filter(p => p.toLowerCase().includes(q));
        }
        if (c === "all" && q === "") return all;

        const lower = Wallpapers.allLower;
        const dir = c === "all" ? "" : c + "/";
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const p = all[i];
            // A collection holds only the images *directly* in its folder.
            if (dir !== "" && (!p.startsWith(dir) || p.indexOf("/", dir.length) !== -1)) continue;
            if (q !== "" && !lower[i].includes(q)) continue;
            out.push(p);
        }
        return out;
    }

    onItemsChanged: {
        const i = items.indexOf(Wallpapers.current);
        grid.currentIndex = i >= 0 ? i : 0;
    }

    readonly property var chips: [
        { key: "all", label: "All", count: Wallpapers.all.length },
        { key: "recent", label: "Recent", count: Wallpapers.recent.length }
    ].concat(Wallpapers.collections.map(c => ({ key: c.path, label: c.label, count: c.count })))

    function cycleCollection(d) {
        const keys = chips.map(c => c.key);
        const i = keys.indexOf(collection);
        collection = keys[(i + d + keys.length) % keys.length];
        chipList.positionViewAtIndex(keys.indexOf(collection), ListView.Contain);
    }

    function fmtCount(n) {
        return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }

    function baseName(p) {
        const f = p.slice(p.lastIndexOf("/") + 1);
        const dot = f.lastIndexOf(".");
        return dot > 0 ? f.slice(0, dot) : f;
    }

    ColumnLayout {
        id: column
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.pad
        spacing: 12

        // ---- header ---------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                spacing: -1

                Text {
                    text: "Wallpapers"
                    color: Colors.text
                    font.family: Theme.sans
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Wallpapers.loading ? "Scanning…"
                        : `${root.fmtCount(root.items.length)} of ${root.fmtCount(Wallpapers.all.length)}`
                    color: Theme.textSoft
                    font.family: Theme.mono
                    font.pixelSize: 10
                }
            }

            // Search
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 20
                color: Theme.card
                border.width: 1
                border.color: search.activeFocus ? Theme.alpha(Colors.primary, 0.35) : Theme.hairline
                Behavior on border.color {
                    ColorAnimation { duration: 200 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Glyph {
                        text: "󰍉"
                        size: 16
                        color: search.text.length ? Colors.primary : Theme.textSoft
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: search.implicitHeight

                        TextInput {
                            id: search
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            focus: true
                            color: Colors.text
                            selectionColor: Theme.alpha(Colors.primary, 0.4)
                            selectedTextColor: Colors.text
                            font.family: Theme.sans
                            font.pixelSize: 14
                            clip: true

                            Keys.onPressed: event => {
                                switch (event.key) {
                                case Qt.Key_Escape:
                                    if (search.text.length) search.text = "";
                                    else root.closeRequested();
                                    break;
                                case Qt.Key_Left: grid.moveCurrentIndexLeft(); break;
                                case Qt.Key_Right: grid.moveCurrentIndexRight(); break;
                                case Qt.Key_Up: grid.moveCurrentIndexUp(); break;
                                case Qt.Key_Down: grid.moveCurrentIndexDown(); break;
                                case Qt.Key_Tab: root.cycleCollection(1); break;
                                case Qt.Key_Backtab: root.cycleCollection(-1); break;
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                    if (root.items.length) Wallpapers.apply(root.items[grid.currentIndex]);
                                    break;
                                default:
                                    return;
                                }
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text.length === 0
                            text: "Search by name or folder…"
                            color: Theme.textFaint
                            font: search.font
                        }
                    }
                }
            }

            IconButton {
                icon: "󰒝"
                size: 40
                onClicked: Wallpapers.random()
            }
        }

        // ---- collections ------------------------------------------------------
        ListView {
            id: chipList
            Layout.fillWidth: true
            implicitHeight: 30
            orientation: ListView.Horizontal
            spacing: 6
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.chips

            // Vertical wheel scrolls the strip sideways.
            WheelHandler {
                onWheel: e => chipList.flick(e.angleDelta.y * 6, 0)
            }

            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property bool selected: root.collection === modelData.key

                implicitWidth: chipRow.implicitWidth + 24
                height: 30
                radius: 15
                color: selected ? Theme.alpha(Colors.primary, 0.20)
                    : chipMouse.containsMouse ? Theme.cardHover : Theme.card
                border.width: selected ? 1 : 0
                border.color: Theme.alpha(Colors.primary, 0.35)
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: chip.modelData.label
                        color: chip.selected ? Colors.primary : Colors.text
                        font.family: Theme.sans
                        font.pixelSize: 12
                        font.weight: chip.selected ? Font.DemiBold : Font.Medium
                    }
                    Text {
                        text: chip.modelData.count
                        color: Theme.textFaint
                        font.family: Theme.mono
                        font.pixelSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.collection = chip.modelData.key
                }
            }
        }

        // ---- grid ---------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            implicitHeight: grid.cellHeight * root.visibleRows

            GridView {
                id: grid
                anchors.fill: parent
                visible: root.items.length > 0
                clip: true
                model: root.items
                cellWidth: Math.floor(width / root.columns)
                cellHeight: Math.round((cellWidth - 10) * 10 / 16) + 10
                cacheBuffer: cellHeight * 2
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                highlightFollowsCurrentItem: false
                currentIndex: 0
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                delegate: Item {
                    id: card
                    required property string modelData
                    required property int index

                    readonly property string path: modelData
                    readonly property bool isCurrent: path === Wallpapers.current
                    readonly property bool isApplying: path === Wallpapers.applying
                    readonly property bool highlighted: GridView.isCurrentItem

                    // Set imperatively (here and on thumbReady) rather than
                    // bound, so delegates never re-evaluate against the queue.
                    property string src: ""
                    Component.onCompleted: src = Wallpapers.thumb(path)

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Connections {
                        target: Wallpapers
                        function onThumbReady(p) {
                            if (p === card.path) card.src = Wallpapers.thumb(card.path);
                        }
                    }
                    // Scrolled away before its turn: don't burn CPU on it.
                    Component.onDestruction: if (src === "") Wallpapers.cancel(path)

                    Item {
                        id: frame
                        anchors.fill: parent
                        anchors.margins: 5
                        scale: hover.hovered ? 1.03 : 1
                        Behavior on scale {
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }

                        HoverHandler {
                            id: hover
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                grid.currentIndex = card.index;
                                Wallpapers.apply(card.path);
                            }
                        }

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: 14
                            color: Theme.card

                            // Placeholder while the thumbnail is generated.
                            Glyph {
                                anchors.centerIn: parent
                                visible: thumb.status !== Image.Ready
                                text: "󰋩"
                                size: 22
                                color: Theme.textFaint
                                SequentialAnimation on opacity {
                                    running: thumb.status !== Image.Ready
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                                }
                            }

                            Image {
                                id: thumb
                                anchors.fill: parent
                                source: card.src
                                sourceSize.width: 400
                                sourceSize.height: 250
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                smooth: true
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: 260 }
                                }
                            }

                            // Name on hover, over a bottom scrim.
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 40
                                opacity: hover.hovered || card.highlighted ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: 160 }
                                }
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.75) }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 9
                                    text: root.baseName(card.path)
                                    color: "white"
                                    font.family: Theme.sans
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                            }

                            // Applying: dim + spinner.
                            Rectangle {
                                anchors.fill: parent
                                visible: card.isApplying
                                color: Qt.rgba(0, 0, 0, 0.45)

                                Glyph {
                                    anchors.centerIn: parent
                                    text: "󰑓"
                                    size: 22
                                    color: "white"
                                    RotationAnimation on rotation {
                                        running: card.isApplying
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 900
                                    }
                                }
                            }
                        }

                        // Ring: primary for the active wallpaper, soft for the
                        // keyboard highlight.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: 17
                            color: "transparent"
                            border.width: card.isCurrent ? 2 : 1.5
                            border.color: card.isCurrent ? Colors.primary : Theme.alpha(Colors.text, 0.55)
                            visible: card.isCurrent || card.highlighted
                        }

                        // Check badge on the active wallpaper.
                        Rectangle {
                            visible: card.isCurrent
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            width: 22
                            height: 22
                            radius: 11
                            color: Colors.primary

                            Glyph {
                                anchors.centerIn: parent
                                text: "󰄬"
                                size: 13
                                color: Colors.textOnPrimary
                            }
                        }
                    }
                }
            }

            // ---- empty / loading states ---------------------------------------
            Column {
                anchors.centerIn: parent
                visible: root.items.length === 0
                spacing: 8

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Wallpapers.loading ? "󰑓" : (Wallpapers.missing ? "󰉖" : "󰍉")
                    size: 26
                    color: Theme.textFaint
                    RotationAnimation on rotation {
                        running: Wallpapers.loading
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Wallpapers.loading ? "Scanning wallpapers…"
                        : Wallpapers.missing ? "No images in ~/Pictures/Wallpapers"
                        : root.collection === "recent" && root.query === "" ? "No recent wallpapers yet"
                        : `Nothing matches “${search.text}”`
                    color: Theme.textSoft
                    font.family: Theme.sans
                    font.pixelSize: 12
                }
            }
        }

        // ---- footer -------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 14

            Text {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                text: Wallpapers.applying !== ""
                    ? `Applying ${root.baseName(Wallpapers.applying)} · updating palette…`
                    : (Wallpapers.current ? `Current: ${root.baseName(Wallpapers.current)}` : "")
                color: Wallpapers.applying !== "" ? Colors.primary : Theme.textFaint
                font.family: Theme.sans
                font.pixelSize: 10
            }
            Repeater {
                model: [["←↑↓→", "move"], ["↵", "apply"], ["tab", "collection"], ["esc", "close"]]
                Row {
                    required property var modelData
                    spacing: 5
                    Text {
                        text: modelData[0]
                        color: Theme.textSoft
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
                    Text {
                        text: modelData[1]
                        color: Theme.textFaint
                        font.family: Theme.sans
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
