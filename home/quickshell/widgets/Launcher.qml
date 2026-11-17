import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "root:/"
import "root:/services"

// App launcher that the island morphs into.
//
//  - type to filter (prefix > word-start > substring > initials > fuzzy)
//  - apps you launch often float up, both when idle and while searching
//  - a bare arithmetic expression shows its result; Enter copies it
//  - ↑/↓, Tab, Ctrl+N/P, Ctrl+J/K move; Enter launches; Esc closes
FocusScope {
    id: root

    readonly property int rowHeight: 52
    readonly property int maxRows: IslandConfig.launcherRows

    implicitWidth: 600
    implicitHeight: column.implicitHeight + 28

    signal closeRequested

    function activate() {
        input.text = "";
        list.currentIndex = 0;
        input.forceActiveFocus();
    }

    // ---- usage counts (frecency-lite) ----------------------------------
    property var usage: ({})

    FileView {
        id: usageFile
        path: Quickshell.stateDir + "/launcher-usage.json"
        printErrors: false
        onLoaded: {
            try {
                root.usage = JSON.parse(text()) ?? {};
            } catch (e) {
                root.usage = {};
            }
        }
    }

    function bump(id) {
        const u = Object.assign({}, usage);
        u[id] = (u[id] ?? 0) + 1;
        usage = u;
        usageFile.setText(JSON.stringify(u));
    }

    // ---- matching -------------------------------------------------------
    function score(entry, q) {
        const name = (entry.name ?? "").toLowerCase();
        if (!name) return -1;
        if (name === q) return 1000;
        if (name.startsWith(q)) return 800 - name.length;

        const words = name.split(/[\s\-_.]+/).filter(w => w.length);
        if (words.some(w => w.startsWith(q))) return 650 - name.length;
        if (name.includes(q)) return 520 - name.indexOf(q);

        const initials = words.map(w => w[0]).join("");
        if (q.length >= 2 && initials.startsWith(q)) return 480;

        const extra = [entry.genericName, String(entry.keywords ?? ""), entry.id, entry.comment]
            .join(" ").toLowerCase();
        if (extra.includes(q)) return 320;

        // In-order subsequence; tighter and earlier matches score higher.
        let qi = 0, gaps = 0, last = -1, first = -1;
        for (let i = 0; i < name.length && qi < q.length; i++) {
            if (name[i] === q[qi]) {
                if (last >= 0) gaps += i - last - 1;
                else first = i;
                last = i;
                qi++;
            }
        }
        if (qi === q.length) return Math.max(1, 200 - gaps * 8 - first * 3);
        return -1;
    }

    function calc(q) {
        if (!/^[\d\s+\-*/().%^,]+$/.test(q) || !/\d/.test(q) || !/[+\-*/%^]/.test(q))
            return null;
        try {
            const expr = q.replace(/\^/g, "**").replace(/,/g, "");
            const v = Function(`"use strict"; return (${expr});`)();
            if (typeof v !== "number" || !isFinite(v)) return null;
            return String(Math.round(v * 1e10) / 1e10);
        } catch (e) {
            return null;
        }
    }

    readonly property string query: input.text.trim().toLowerCase()

    readonly property var results: {
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const q = query;
        const use = id => usage[id] ?? 0;
        let out;

        if (q === "") {
            out = apps.slice().sort((a, b) =>
                (use(b.id) - use(a.id)) || a.name.localeCompare(b.name))
                .map(e => ({ kind: "app", entry: e }));
        } else {
            out = apps.map(e => ({ e, s: score(e, q) }))
                .filter(x => x.s >= 0)
                .map(x => ({ e: x.e, s: x.s + Math.min(use(x.e.id), 25) * 6 }))
                .sort((a, b) => (b.s - a.s) || a.e.name.localeCompare(b.e.name))
                .map(x => ({ kind: "app", entry: x.e }));
        }

        const c = IslandConfig.launcherCalc ? calc(input.text.trim()) : null;
        if (c !== null) out.unshift({ kind: "calc", value: c, expr: input.text.trim() });
        return out;
    }

    onResultsChanged: list.currentIndex = 0

    function launch(item) {
        if (!item) return;
        if (item.kind === "calc") {
            Quickshell.execDetached(["wl-copy", item.value]);
        } else {
            bump(item.entry.id);
            item.entry.execute();
        }
        root.closeRequested();
    }

    function move(d) {
        if (list.count === 0) return;
        list.currentIndex = (list.currentIndex + d + list.count) % list.count;
    }

    ColumnLayout {
        id: column
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 10

        // ---- search field ------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 24
            color: Theme.card
            border.width: 1
            border.color: input.activeFocus ? Theme.alpha(Colors.primary, 0.35) : Theme.hairline
            Behavior on border.color {
                ColorAnimation { duration: 200 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 10
                spacing: 12

                Glyph {
                    text: "󰍉"
                    size: 16
                    color: input.text.length ? Colors.primary : Theme.textSoft
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: input.implicitHeight

                    TextInput {
                        id: input
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        focus: true
                        color: Colors.text
                        selectionColor: Theme.alpha(Colors.primary, 0.4)
                        selectedTextColor: Colors.text
                        font.family: Theme.sans
                        font.pixelSize: 16
                        clip: true

                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            if (event.key === Qt.Key_Escape) {
                                root.closeRequested();
                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab
                                       || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) {
                                root.move(1);
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
                                       || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) {
                                root.move(-1);
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launch(root.results[list.currentIndex]);
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text.length === 0
                        text: "Search apps, or type a sum…"
                        color: Theme.textFaint
                        font: input.font
                    }
                }

                // Key-cap hint.
                Rectangle {
                    implicitWidth: escText.implicitWidth + 14
                    implicitHeight: 22
                    radius: 7
                    color: Theme.track

                    Text {
                        id: escText
                        anchors.centerIn: parent
                        text: "esc"
                        color: Theme.textSoft
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
                }
            }
        }

        // ---- results -------------------------------------------------------
        ListView {
            id: list
            Layout.fillWidth: true
            implicitHeight: Math.max(1, Math.min(count, root.maxRows)) * root.rowHeight
            visible: count > 0
            clip: true
            model: root.results
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 160
            highlightMoveVelocity: -1
            highlightResizeDuration: 0
            keyNavigationEnabled: false

            Behavior on implicitHeight {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            highlight: Rectangle {
                radius: 16
                color: Theme.alpha(Colors.primary, 0.13)
                border.width: 1
                border.color: Theme.alpha(Colors.primary, 0.18)
            }

            delegate: Item {
                id: row
                required property var modelData
                required property int index

                readonly property bool isCalc: modelData.kind === "calc"
                readonly property bool current: ListView.isCurrentItem

                width: ListView.view.width
                height: root.rowHeight

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: list.currentIndex = row.index
                    onClicked: root.launch(row.modelData)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    spacing: 14

                    Item {
                        implicitWidth: 32
                        implicitHeight: 32

                        IconImage {
                            anchors.fill: parent
                            visible: !row.isCalc
                            asynchronous: true
                            source: row.isCalc ? ""
                                : Quickshell.iconPath(row.modelData.entry.icon, "application-x-executable")
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: row.isCalc
                            radius: 10
                            color: Theme.alpha(Colors.primary, 0.18)
                            Glyph {
                                anchors.centerIn: parent
                                text: "󰃬"
                                size: 16
                                color: Colors.primary
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: row.isCalc ? row.modelData.value : row.modelData.entry.name
                            color: Colors.text
                            font.family: row.isCalc ? Theme.mono : Theme.sans
                            font.pixelSize: 14
                            font.weight: row.current ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.isCalc
                                ? `= ${row.modelData.expr}`
                                : (row.modelData.entry.genericName || row.modelData.entry.comment || "")
                            color: Theme.textSoft
                            font.family: Theme.sans
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: row.current
                        text: row.isCalc ? "copy ↵" : "open ↵"
                        color: Colors.primary
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
                }
            }
        }

        // ---- empty state -----------------------------------------------------
        Item {
            Layout.fillWidth: true
            implicitHeight: 84
            visible: list.count === 0

            Column {
                anchors.centerIn: parent
                spacing: 6
                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰍉"
                    size: 22
                    color: Theme.textFaint
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `Nothing matches “${input.text}”`
                    color: Theme.textSoft
                    font.family: Theme.sans
                    font.pixelSize: 12
                }
            }
        }

        // ---- footer ----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 14

            Text {
                text: list.count === 1 ? "1 result" : `${list.count} results`
                color: Theme.textFaint
                font.family: Theme.sans
                font.pixelSize: 10
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: [["↑↓", "navigate"], ["↵", "open"], ["1+1", "calc"]]
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
