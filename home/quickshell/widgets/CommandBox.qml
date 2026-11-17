import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/"
import "root:/services"

// Run-a-command box that the island morphs into (press / on an empty
// workspace). Enter opens a kitty window that runs the command in fish and
// then stays at an interactive prompt, so output from short commands
// doesn't vanish the moment they exit.
//
//  - recent commands are listed below the field and filtered as you type
//  - ↑/↓, Ctrl+N/P, Ctrl+J/K move; Tab copies the highlighted one into the
//    field for editing; Enter runs the highlighted row; Esc closes
FocusScope {
    id: root

    readonly property int rowHeight: 44
    readonly property int maxRows: Math.min(IslandConfig.launcherRows, 6)

    implicitWidth: 600
    implicitHeight: column.implicitHeight + 28

    signal closeRequested

    function activate() {
        input.text = "";
        list.currentIndex = 0;
        input.forceActiveFocus();
    }

    // ---- history ----------------------------------------------------------
    property var history: []

    FileView {
        id: historyFile
        path: Quickshell.stateDir + "/command-history.json"
        printErrors: false
        onLoaded: {
            try {
                const h = JSON.parse(text());
                root.history = Array.isArray(h) ? h : [];
            } catch (e) {
                root.history = [];
            }
        }
    }

    function remember(cmd) {
        history = [cmd, ...history.filter(h => h !== cmd)].slice(0, 100);
        historyFile.setText(JSON.stringify(history));
    }

    readonly property string typed: input.text.trim()

    // Row 0 is always "run what I typed" (when there is something typed),
    // followed by matching history: prefix matches first, then substrings.
    readonly property var results: {
        const q = typed.toLowerCase();
        const out = [];
        if (typed !== "") out.push({ kind: "run", cmd: typed });
        const pre = [], sub = [];
        for (const h of history) {
            if (h === typed) continue;
            const l = h.toLowerCase();
            if (q === "" || l.startsWith(q)) pre.push(h);
            else if (l.includes(q)) sub.push(h);
        }
        for (const h of pre.concat(sub)) out.push({ kind: "history", cmd: h });
        return out;
    }

    onResultsChanged: list.currentIndex = 0

    // fish single-quoted string: only \ and ' need escaping inside.
    function fishQuote(s) {
        return "'" + s.replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'";
    }

    function run(item) {
        if (!item) return;
        const cmd = item.cmd;
        remember(cmd);
        // Echo the command dimmed so the terminal shows what ran, then run it
        // verbatim as fish code. -C keeps fish interactive afterwards.
        const init = `printf '\\e[2m❯ %s\\e[0m\\n' ${fishQuote(cmd)}; ${cmd}`;
        // The init script goes in as $1, so sh never re-parses it.
        Quickshell.execDetached(["sh", "-c",
            'exec kitty -1 fish -C "$1" 2>>"$HOME/.cache/kitty.log"', "sh", init]);
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

        // ---- command field -------------------------------------------------
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
                    text: "\uf120"
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
                        font.family: Theme.mono
                        font.pixelSize: 15
                        clip: true

                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            if (event.key === Qt.Key_Escape) {
                                root.closeRequested();
                            } else if (event.key === Qt.Key_Down
                                       || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) {
                                root.move(1);
                            } else if (event.key === Qt.Key_Up
                                       || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) {
                                root.move(-1);
                            } else if (event.key === Qt.Key_Tab) {
                                const item = root.results[list.currentIndex];
                                if (item) {
                                    input.text = item.cmd;
                                    input.cursorPosition = input.text.length;
                                }
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.run(root.results[list.currentIndex]);
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text.length === 0
                        text: "Run a command in kitty…"
                        color: Theme.textFaint
                        font.family: Theme.sans
                        font.pixelSize: 15
                    }
                }

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

        // ---- run row + history ---------------------------------------------
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

                readonly property bool isRun: modelData.kind === "run"
                readonly property bool current: ListView.isCurrentItem

                width: ListView.view.width
                height: root.rowHeight

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: list.currentIndex = row.index
                    onClicked: root.run(row.modelData)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 14

                    Glyph {
                        text: row.isRun ? "\uf120" : "󰋚"
                        size: 15
                        color: row.isRun ? Colors.primary : Theme.textSoft
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.cmd
                        color: Colors.text
                        font.family: Theme.mono
                        font.pixelSize: 13
                        font.weight: row.current ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: row.current
                        text: "run ↵"
                        color: Colors.primary
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
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
                text: root.history.length === 0 ? "No history yet" : "Recent commands"
                color: Theme.textFaint
                font.family: Theme.sans
                font.pixelSize: 10
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: [["↑↓", "navigate"], ["tab", "edit"], ["↵", "run in kitty"]]
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
