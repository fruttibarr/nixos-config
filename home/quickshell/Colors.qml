pragma Singleton
import QtQuick

// Fallback palette. matugen overwrites this file on every wallpaper change,
// so these values only apply before the first `set-wallpaper` run.
QtObject {
    readonly property color background: "#14131a"
    readonly property color surface: "#1f1e26"
    readonly property color surfaceBright: "#2a2833"
    // NOTE: these must NOT be named on*/onPrimary — QML parses an `on<Name>`
    // property as a signal handler for `<name>`, so Material You's
    // on_surface / on_primary roles are renamed here.
    readonly property color text: "#e5e1e9"
    readonly property color textDim: "#c8c3d0"
    readonly property color primary: "#c7bfff"
    readonly property color textOnPrimary: "#2e2660"
    readonly property color secondary: "#c8c3dc"
    readonly property color tertiary: "#ecb8cd"
    readonly property color error: "#ffb4ab"
    readonly property color outline: "#484553"
}
