pragma Singleton
import QtQuick
import Quickshell

// Typed view of the island's settings (Settings › Dynamic Island). Every
// property is a live binding on HyprSettings, so changes apply instantly.
Singleton {
    function v(k) {
        return HyprSettings.get("island." + k);
    }

    // Behaviour
    readonly property bool hoverExpand: v("hoverExpand")
    readonly property int hoverDelay: v("hoverDelay")
    readonly property int collapseDelay: v("collapseDelay")
    readonly property string clickAction: v("clickAction")
    readonly property string rightClickAction: v("rightClickAction")
    readonly property string middleClickAction: v("middleClickAction")
    readonly property string scrollAction: v("scrollAction")
    readonly property bool trackPeek: v("trackPeek")
    readonly property real trackPeekSeconds: v("trackPeekSeconds")
    readonly property bool osd: v("osd")
    readonly property real osdSeconds: v("osdSeconds")

    // Appearance
    readonly property int offset: v("offset")
    readonly property bool attached: v("attached")
    readonly property real tint: v("tint")
    readonly property real opacity: v("opacity")
    readonly property bool rim: v("rim")
    readonly property bool sheen: v("sheen")
    readonly property real glow: v("glow")
    readonly property real shadow: v("shadow")
    readonly property int panelRadius: v("panelRadius")
    readonly property real dim: v("dim")

    // Motion
    readonly property bool animate: v("animate")
    readonly property int morphMs: animate ? v("morphMs") : 0
    readonly property real bounce: v("bounce")
    readonly property int fadeMs: animate ? v("fadeMs") : 0
    readonly property bool windowLaunch: v("windowLaunch")

    // Resting pill
    readonly property bool showWorkspaces: v("showWorkspaces")
    readonly property bool clock12: v("clockFormat") === "12"
    readonly property bool showSeconds: v("showSeconds")
    readonly property bool blinkColon: v("blinkColon")
    readonly property bool showArt: v("showArt")
    readonly property bool showEqualizer: v("showEqualizer")
    readonly property bool showIndicators: v("showIndicators")
    readonly property string battery: v("battery")

    // Hover view
    readonly property bool peekMedia: v("peekMedia")
    readonly property bool peekStatus: v("peekStatus")
    readonly property bool peekTray: v("peekTray")
    readonly property bool peekDate: v("peekDate")

    // Launcher
    readonly property int launcherRows: v("launcherRows")
    readonly property bool launcherCalc: v("launcherCalc")
}
