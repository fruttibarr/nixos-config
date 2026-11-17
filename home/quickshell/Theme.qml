pragma Singleton
import QtQuick
import Quickshell
import "root:/services"

// Design tokens shared by the island and everything that grows out of it.
// Colours are *derived* from the matugen palette in Colors.qml so a
// wallpaper change still re-themes the whole shell.
Singleton {
    id: root

    // ---- type -------------------------------------------------------------
    // A humanist sans for words, the mono for numbers and glyphs. Mixing the
    // two is what stops the island reading like a terminal status line.
    readonly property string sans: "Noto Sans"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string icons: "JetBrainsMono Nerd Font"

    // ---- colour helpers ---------------------------------------------------
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    // Arguments must be real colors, not "#rrggbb" strings — a string has no
    // .r/.g/.b, which silently yields a transparent result.
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // The island itself: near-black with just a breath of the palette's hue,
    // like the hardware cut-out it imitates. Opaque on purpose: Hyprland has
    // no region blur for layer surfaces, and a see-through pill over busy
    // windows reads as muddy rather than glassy.
    readonly property color ink: "#050507"
    // Tint/opacity are user settings (Settings › Dynamic Island).
    readonly property color island: alpha(mix(ink, Colors.background, IslandConfig.tint), IslandConfig.opacity)
    readonly property color islandRim: alpha(Colors.text, 0.075)
    readonly property color islandSheen: alpha(Colors.primary, 0.20)

    // Raised surfaces inside the expanded island.
    readonly property color card: alpha(Colors.text, 0.055)
    readonly property color cardHover: alpha(Colors.text, 0.09)
    readonly property color cardPressed: alpha(Colors.text, 0.13)
    readonly property color hairline: alpha(Colors.text, 0.08)
    readonly property color track: alpha(Colors.text, 0.10)

    readonly property color textSoft: alpha(Colors.text, 0.62)
    readonly property color textFaint: alpha(Colors.text, 0.38)

    // ---- shape ------------------------------------------------------------
    readonly property real radiusPanel: IslandConfig.panelRadius
    readonly property real radiusCard: 18
    readonly property real radiusSmall: 12

    // ---- motion -----------------------------------------------------------
    // The morph uses a gentle OutBack so the island overshoots a hair and
    // settles, which is most of what makes it feel physical.
    // Durations/bounce come from Settings › Dynamic Island (0 = no animation).
    readonly property int morphMs: IslandConfig.morphMs
    readonly property real morphOvershoot: IslandConfig.bounce
    readonly property int fadeMs: IslandConfig.fadeMs
}
