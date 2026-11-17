import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/services"

// A key combo drawn as keycaps. Click it (or focus it and press Enter), then
// press the new shortcut; Escape cancels. While listening, Hyprland is parked
// in an empty submap (HyprSettings.beginRecording) so the combo reaches us
// instead of firing.
//
// Emits combos as Hyprland key strings, modifiers first in SUPER, CTRL, ALT,
// SHIFT order — e.g. "SUPER + SHIFT + Return".
Rectangle {
    id: root

    property string keys: ""            // current combo, "" = not set
    property bool conflict: false
    property string placeholder: "Not set"
    signal recorded(string keys)

    property bool listening: false
    property var heldMods: []
    property string message: ""

    implicitWidth: Math.max(130, content.implicitWidth + 24)
    implicitHeight: 32
    radius: 16
    color: listening ? Theme.alpha(Colors.primary, 0.14)
        : mouse.containsMouse ? Theme.cardHover : Theme.track
    border.width: 1
    border.color: listening ? Theme.alpha(Colors.primary, 0.55)
        : conflict ? Theme.alpha(Colors.error, 0.6)
        : activeFocus ? Theme.alpha(Colors.primary, 0.35) : "transparent"
    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    function start() {
        listening = true;
        message = "";
        heldMods = [];
        forceActiveFocus();
        HyprSettings.beginRecording();
        timeout.restart();
    }
    function stop() {
        if (!listening) return;
        listening = false;
        heldMods = [];
        timeout.stop();
        HyprSettings.endRecording();
    }

    // Losing focus (panel closed, another recorder clicked) always cancels,
    // so Hyprland is never left in the recording submap.
    onActiveFocusChanged: if (!activeFocus) stop()
    Component.onDestruction: stop()

    Timer {
        id: timeout
        interval: 10000
        onTriggered: root.stop()
    }

    // ---- key names ---------------------------------------------------------
    function modsOf(m) {
        const out = [];
        if (m & Qt.MetaModifier) out.push("SUPER");
        if (m & Qt.ControlModifier) out.push("CTRL");
        if (m & Qt.AltModifier) out.push("ALT");
        if (m & Qt.ShiftModifier) out.push("SHIFT");
        return out;
    }
    function isModifierKey(k) {
        return [Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R,
                Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Shift, Qt.Key_CapsLock,
                Qt.Key_NumLock].includes(k);
    }
    // Qt reports the shifted symbol (SHIFT+1 is "!"); Hyprland binds the base
    // key, so map them back (US layout).
    readonly property var shiftedKeys: ({
        [Qt.Key_Exclam]: "1", [Qt.Key_At]: "2", [Qt.Key_NumberSign]: "3", [Qt.Key_Dollar]: "4",
        [Qt.Key_Percent]: "5", [Qt.Key_AsciiCircum]: "6", [Qt.Key_Ampersand]: "7", [Qt.Key_Asterisk]: "8",
        [Qt.Key_ParenLeft]: "9", [Qt.Key_ParenRight]: "0", [Qt.Key_Underscore]: "minus", [Qt.Key_Plus]: "equal",
        [Qt.Key_BraceLeft]: "bracketleft", [Qt.Key_BraceRight]: "bracketright", [Qt.Key_Bar]: "backslash",
        [Qt.Key_Colon]: "semicolon", [Qt.Key_QuoteDbl]: "apostrophe", [Qt.Key_Less]: "comma",
        [Qt.Key_Greater]: "period", [Qt.Key_Question]: "slash", [Qt.Key_AsciiTilde]: "grave"
    })
    // Qt key -> xkb keysym name, as hl.bind expects.
    readonly property var namedKeys: ({
        [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "KP_Enter", [Qt.Key_Space]: "SPACE",
        [Qt.Key_Tab]: "Tab", [Qt.Key_Backtab]: "Tab", [Qt.Key_Backspace]: "BackSpace",
        [Qt.Key_Escape]: "Escape", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert",
        [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next",
        [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
        [Qt.Key_Print]: "Print", [Qt.Key_Pause]: "Pause", [Qt.Key_ScrollLock]: "Scroll_Lock",
        [Qt.Key_Comma]: "comma", [Qt.Key_Period]: "period", [Qt.Key_Slash]: "slash",
        [Qt.Key_Semicolon]: "semicolon", [Qt.Key_Apostrophe]: "apostrophe",
        [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BracketRight]: "bracketright",
        [Qt.Key_Backslash]: "backslash", [Qt.Key_Minus]: "minus", [Qt.Key_Equal]: "equal",
        [Qt.Key_QuoteLeft]: "grave",
        [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
        [Qt.Key_VolumeMute]: "XF86AudioMute", [Qt.Key_MicMute]: "XF86AudioMicMute",
        [Qt.Key_MediaPlay]: "XF86AudioPlay", [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay",
        [Qt.Key_MediaPause]: "XF86AudioPause", [Qt.Key_MediaStop]: "XF86AudioStop",
        [Qt.Key_MediaNext]: "XF86AudioNext", [Qt.Key_MediaPrevious]: "XF86AudioPrev",
        [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp", [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown",
        [Qt.Key_Calculator]: "XF86Calculator", [Qt.Key_LaunchMail]: "XF86Mail",
        [Qt.Key_Search]: "XF86Search", [Qt.Key_Explorer]: "XF86Explorer", [Qt.Key_HomePage]: "XF86HomePage",
        [Qt.Key_Tools]: "XF86Tools", [Qt.Key_PowerOff]: "XF86PowerOff", [Qt.Key_Sleep]: "XF86Sleep"
    })
    function keyName(k) {
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k);
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1);
        return shiftedKeys[k] ?? namedKeys[k] ?? "";
    }
    // Keys that are fine on their own; anything else needs a modifier so a
    // shortcut can never swallow ordinary typing.
    function standalone(name) {
        return /^F\d+$/.test(name) || name.startsWith("XF86")
            || ["Print", "Pause", "Scroll_Lock", "Insert"].includes(name);
    }

    readonly property var prettyNames: ({
        SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift",
        Return: "Enter", KP_Enter: "Num Enter", SPACE: "Space", BackSpace: "Backspace",
        Prior: "PgUp", Next: "PgDn", Scroll_Lock: "ScrLk",
        left: "←", right: "→", up: "↑", down: "↓",
        comma: ",", period: ".", slash: "/", semicolon: ";", apostrophe: "'",
        bracketleft: "[", bracketright: "]", backslash: "\\", minus: "-", equal: "=", grave: "`"
    })
    function pretty(part) {
        const p = part.trim();
        return prettyNames[p] ?? prettyNames[p.toUpperCase()] ?? p.replace(/^XF86/, "");
    }

    Keys.onPressed: event => {
        if (!listening) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                start();
                event.accepted = true;
            }
            return;
        }
        event.accepted = true;
        timeout.restart();
        const mods = modsOf(event.modifiers);
        if (isModifierKey(event.key)) {
            heldMods = mods;
            return;
        }
        if (event.key === Qt.Key_Escape && mods.length === 0) {
            stop();
            return;
        }
        const name = keyName(event.key);
        if (!name) {
            message = "That key can't be bound";
            return;
        }
        if (mods.length === 0 && !standalone(name)) {
            message = "Add a modifier, e.g. Super";
            return;
        }
        const combo = [...mods, name].join(" + ");
        const reserved = HyprSettings.reservedLabel(combo);
        if (reserved) {
            message = `Reserved for ${reserved}`;
            return;
        }
        stop();
        root.recorded(combo);
    }
    Keys.onReleased: event => {
        if (!listening) return;
        event.accepted = true;
        // On release the released modifier may still be in event.modifiers.
        const released = {
            [Qt.Key_Meta]: "SUPER", [Qt.Key_Super_L]: "SUPER", [Qt.Key_Super_R]: "SUPER",
            [Qt.Key_Control]: "CTRL", [Qt.Key_Alt]: "ALT", [Qt.Key_Shift]: "SHIFT"
        }[event.key];
        heldMods = modsOf(event.modifiers).filter(m => m !== released);
    }

    // ---- display -----------------------------------------------------------
    readonly property var shownParts: listening ? heldMods
        : keys !== "" ? keys.split("+").map(s => s.trim()).filter(s => s !== "") : []
    readonly property string shownText: listening
        ? (heldMods.length ? "" : (message || "Press a shortcut…"))
        : (keys === "" ? placeholder : "")

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.shownParts
            Rectangle {
                required property var modelData
                implicitWidth: Math.max(22, capText.implicitWidth + 12)
                implicitHeight: 22
                radius: 6
                color: root.listening ? Theme.alpha(Colors.primary, 0.22) : Theme.card
                border.width: 1
                border.color: Theme.hairline
                Text {
                    id: capText
                    anchors.centerIn: parent
                    text: root.pretty(modelData)
                    color: root.listening ? Colors.primary : Colors.text
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }
        }
        Text {
            visible: root.listening && root.heldMods.length > 0
            text: "…"
            color: Colors.primary
            font.family: Theme.mono
            font.pixelSize: 12
        }
        Text {
            visible: root.shownText !== ""
            text: root.shownText
            color: root.listening ? (root.message ? Colors.error : Colors.primary) : Theme.textFaint
            font.family: Theme.sans
            font.pixelSize: 12
            font.italic: !root.listening
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.listening ? root.stop() : root.start()
    }
}
