pragma Singleton
import QtQuick
import Quickshell

// Shell-wide state that more than one surface needs to agree on.
Singleton {
    id: root

    // What the island is morphed into: "" (resting), "launcher" or "control".
    property string mode: ""
    // Output name of the monitor whose island owns `mode`.
    property string screen: ""

    // ---- toggles surfaced in the control center --------------------------
    property bool dnd: false
    property bool caffeine: false
    property bool nightLight: false

    // ---- notification history --------------------------------------------
    // Plain-object copies: the live Notification objects are destroyed once
    // dismissed, but history should outlive the toast.
    property var history: []

    function pushHistory(entry) {
        history = [entry, ...history].slice(0, 40);
    }
    function removeHistory(id) {
        history = history.filter(h => h.id !== id);
    }
    function clearHistory() {
        history = [];
    }

    // ---- island mode -----------------------------------------------------
    function toggle(m, screenName) {
        const target = screenName || (Quickshell.screens[0]?.name ?? "");
        if (mode === m && screen === target) {
            mode = "";
            return;
        }
        screen = target;
        mode = m;
    }
    function close() {
        mode = "";
    }
    // Morph from one open mode to another on the same monitor.
    function switchTo(m) {
        mode = m;
    }

    // Open the control center (if it isn't already) straight to a sub-page:
    // "wifi" or "bluetooth".
    signal pageRequested(string page)
    function openControlPage(page, screenName) {
        const target = screenName || (Quickshell.screens[0]?.name ?? "");
        if (!(mode === "control" && screen === target)) {
            screen = target;
            mode = "control";
        }
        pageRequested(page);
    }

    // ---- OSD -------------------------------------------------------------
    property string osdKind: ""
    property real osdValue: 0
    property bool osdMuted: false
    signal osdRequested

    function showOsd(kind, value, muted) {
        osdKind = kind;
        osdValue = value;
        osdMuted = !!muted;
        osdRequested();
    }
}
