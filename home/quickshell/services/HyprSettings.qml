pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland settings, editable from the island's settings panel.
//
// hyprland.lua is a read-only Nix-store file, so user changes live in two
// writable files next to it:
//
//   ~/.config/hypr/settings.json  overrides only (what the panel reads back)
//   ~/.config/hypr/settings.lua   generated script hyprland.lua dofile()s last
//
// Changes apply instantly with `hyprctl eval` and are persisted to both
// files, so they survive restarts and rebuilds. Anything not overridden falls
// through to the Nix config. Defaults below mirror hyprland.nix (or
// Hyprland's built-ins where the Nix config doesn't set the key).
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/hypr"
    readonly property string jsonPath: dir + "/settings.json"
    readonly property string luaPath: dir + "/settings.lua"

    property var overrides: ({})   // key -> value (only non-default values)
    property var monitorOverrides: ({}) // output -> { mode, scale }
    property bool loaded: false
    property string lastError: ""

    // ---- schema ------------------------------------------------------------
    // type: bool | int | float | choice | text.  Keys are Hyprland Lua config
    // paths, except `anim.*` (rendered into hl.animation calls) and
    // `shell.*` (read by Quickshell itself, never sent to Hyprland).
    function opts(pairs) {
        return pairs.map(p => ({ value: p[0], label: p[1] }));
    }

    // Keys Quickshell consumes itself — persisted, never sent to Hyprland.
    function isLocal(key) {
        return key.startsWith("shell.") || key.startsWith("island.");
    }
    // Keys that feed animationLua(): the Hyprland anim.* knobs, plus the
    // island launch toggle, which swaps Hyprland's window-open animation out.
    function isAnimKey(key) {
        return key.startsWith("anim.") || key === "island.windowLaunch";
    }

    readonly property var islandActions: [
        ["control", "Control center"], ["launcher", "Launcher"], ["settings", "Settings"],
        ["wallpapers", "Wallpapers"], ["playpause", "Play / pause"], ["none", "Nothing"]
    ]

    readonly property var sections: [
        {
            id: "appearance", label: "Appearance", icon: "󰏘",
            groups: [
                { title: "Gaps & borders", fields: [
                    { key: "general.gaps_in", label: "Inner gaps", type: "int", min: 0, max: 40, unit: "px", def: 4 },
                    { key: "general.gaps_out", label: "Outer gaps", type: "int", min: 0, max: 80, unit: "px", def: 10 },
                    { key: "general.border_size", label: "Border width", type: "int", min: 0, max: 10, unit: "px", def: 2 }
                ]},
                { title: "Corners", fields: [
                    { key: "decoration.rounding", label: "Corner radius", type: "int", min: 0, max: 40, unit: "px", def: 10 },
                    { key: "decoration.rounding_power", label: "Corner shape", type: "float", min: 1, max: 10, step: 0.1, def: 2,
                      hint: "2 is a circular arc; higher values make smoother squircles" }
                ]},
                { title: "Opacity & dimming", fields: [
                    { key: "decoration.active_opacity", label: "Focused windows", type: "float", min: 0.3, max: 1, step: 0.01, percent: true, def: 1 },
                    { key: "decoration.inactive_opacity", label: "Unfocused windows", type: "float", min: 0.3, max: 1, step: 0.01, percent: true, def: 1 },
                    { key: "decoration.dim_inactive", label: "Dim unfocused windows", type: "bool", def: false },
                    { key: "decoration.dim_strength", label: "Dim strength", type: "float", min: 0, max: 1, step: 0.05, percent: true, def: 0.5,
                      dependsOn: "decoration.dim_inactive" }
                ]},
                { title: "Shadow", fields: [
                    { key: "decoration.shadow.enabled", label: "Window shadows", type: "bool", def: true },
                    { key: "decoration.shadow.range", label: "Size", type: "int", min: 0, max: 80, unit: "px", def: 20, dependsOn: "decoration.shadow.enabled" },
                    { key: "decoration.shadow.render_power", label: "Falloff", type: "int", min: 1, max: 4, def: 3, dependsOn: "decoration.shadow.enabled",
                      hint: "Higher is a tighter, faster-fading shadow" },
                    { key: "decoration.shadow.sharp", label: "Hard edge", type: "bool", def: false, dependsOn: "decoration.shadow.enabled" }
                ]},
                { title: "Blur", fields: [
                    { key: "decoration.blur.enabled", label: "Background blur", type: "bool", def: true },
                    { key: "decoration.blur.size", label: "Radius", type: "int", min: 1, max: 20, def: 6, dependsOn: "decoration.blur.enabled" },
                    { key: "decoration.blur.passes", label: "Passes", type: "int", min: 1, max: 6, def: 3, dependsOn: "decoration.blur.enabled",
                      hint: "More passes look smoother but cost GPU time" },
                    { key: "decoration.blur.vibrancy", label: "Vibrancy", type: "float", min: 0, max: 1, step: 0.01, def: 0.1696, dependsOn: "decoration.blur.enabled" },
                    { key: "decoration.blur.noise", label: "Noise", type: "float", min: 0, max: 0.2, step: 0.005, def: 0.0117, dependsOn: "decoration.blur.enabled" },
                    { key: "decoration.blur.contrast", label: "Contrast", type: "float", min: 0, max: 2, step: 0.05, def: 0.8916, dependsOn: "decoration.blur.enabled" },
                    { key: "decoration.blur.brightness", label: "Brightness", type: "float", min: 0, max: 2, step: 0.05, def: 1, dependsOn: "decoration.blur.enabled" },
                    { key: "decoration.blur.popups", label: "Blur popups & menus", type: "bool", def: false, dependsOn: "decoration.blur.enabled" },
                    { key: "decoration.blur.xray", label: "X-ray (floating windows blur only the wallpaper)", type: "bool", def: false, dependsOn: "decoration.blur.enabled" }
                ]}
            ]
        },
        {
            id: "animations", label: "Animations", icon: "󰄄",
            groups: [
                { title: "Motion", fields: [
                    { key: "animations.enabled", label: "Animations", type: "bool", def: true },
                    { key: "anim.scale", label: "Duration", type: "float", min: 0.25, max: 3, step: 0.05, unit: "×", def: 1,
                      hint: "Multiplies every animation's length — lower is snappier", dependsOn: "animations.enabled" },
                    { key: "anim.windows", label: "Window open/close", type: "choice", def: "popin 85%", dependsOn: "animations.enabled",
                      options: opts([["popin 85%", "Pop in"], ["slide", "Slide"], ["gnomed", "Gnome"]]) },
                    // island.* key: handled by Quickshell (widgets/WindowLaunch.qml), not Hyprland.
                    { key: "island.windowLaunch", label: "Open windows out of the island", type: "bool", def: true,
                      dependsOn: "animations.enabled", hint: "New windows fly out of the Dynamic Island into place" },
                    { key: "anim.workspaces", label: "Workspace switch", type: "choice", def: "slide", dependsOn: "animations.enabled",
                      options: opts([["slide", "Slide"], ["slidevert", "Vertical"], ["fade", "Fade"], ["slidefade 20%", "Blend"]]) }
                ]},
                { title: "Details", fields: [
                    { key: "animations.workspace_wraparound", label: "Wrap around when cycling workspaces", type: "bool", def: false },
                    { key: "misc.animate_manual_resizes", label: "Animate manual resizes", type: "bool", def: false },
                    { key: "misc.animate_mouse_windowdragging", label: "Animate window dragging", type: "bool", def: false }
                ]}
            ]
        },
        {
            id: "windows", label: "Windows & Layout", icon: "󰕰",
            groups: [
                { title: "Tiling", fields: [
                    { key: "general.layout", label: "Layout", type: "choice", def: "dwindle",
                      options: opts([["dwindle", "Dwindle"], ["master", "Master"], ["scrolling", "Scrolling"], ["monocle", "Monocle"]]) }
                ]},
                { title: "Dwindle", fields: [
                    { key: "dwindle.preserve_split", label: "Keep split direction when resizing", type: "bool", def: true },
                    { key: "dwindle.smart_split", label: "Split based on cursor position", type: "bool", def: false },
                    { key: "dwindle.force_split", label: "New window goes", type: "choice", def: 0,
                      options: opts([[0, "Follow mouse"], [1, "Left / top"], [2, "Right / bottom"]]) },
                    { key: "dwindle.default_split_ratio", label: "Split ratio", type: "float", min: 0.1, max: 1.9, step: 0.05, def: 1 }
                ]},
                { title: "Master", fields: [
                    { key: "master.mfact", label: "Master size", type: "float", min: 0.1, max: 0.9, step: 0.01, percent: true, def: 0.55 },
                    { key: "master.orientation", label: "Master side", type: "choice", def: "left",
                      options: opts([["left", "Left"], ["right", "Right"], ["top", "Top"], ["bottom", "Bottom"], ["center", "Center"]]) },
                    { key: "master.new_status", label: "New windows become", type: "choice", def: "slave",
                      options: opts([["slave", "Stack"], ["master", "Master"], ["inherit", "Inherit"]]) },
                    { key: "master.new_on_top", label: "New windows at top of stack", type: "bool", def: false }
                ]},
                // Read by widgets/DrawTerminal.qml (local `shell.*` keys).
                { title: "Draw a terminal", fields: [
                    { key: "shell.draw.enabled", label: "Draw terminals on the desktop", type: "bool", def: true,
                      hint: "Hold the key below and drag on empty desktop; a live outline follows, release to open kitty there. Right-click mid-drag cancels" },
                    { key: "shell.draw.modifier", label: "Hold while dragging", type: "choice", def: "super", dependsOn: "shell.draw.enabled",
                      options: opts([["super", "Super"], ["alt", "Alt"], ["ctrl", "Ctrl"], ["none", "Nothing"]]) },
                    { key: "shell.draw.grid", label: "Snap to grid", type: "choice", def: 0, dependsOn: "shell.draw.enabled",
                      options: opts([[0, "Off"], [10, "10 px"], [20, "20 px"], [40, "40 px"]]) },
                    { key: "shell.draw.minSize", label: "Minimum width", type: "int", min: 60, max: 600, step: 10, unit: "px", def: 160,
                      dependsOn: "shell.draw.enabled", hint: "Smaller drags are ignored, so stray clicks never open terminals" }
                ]},
                { title: "Behaviour", fields: [
                    { key: "general.resize_on_border", label: "Resize by dragging borders", type: "bool", def: true },
                    { key: "general.extend_border_grab_area", label: "Border grab area", type: "int", min: 0, max: 40, unit: "px", def: 15,
                      dependsOn: "general.resize_on_border" },
                    { key: "general.hover_icon_on_border", label: "Resize cursor on borders", type: "bool", def: true },
                    { key: "general.snap.enabled", label: "Snap floating windows", type: "bool", def: false },
                    { key: "misc.focus_on_activate", label: "Focus apps that request it", type: "bool", def: false },
                    { key: "misc.enable_swallow", label: "Terminal swallowing", type: "bool", def: false },
                    { key: "binds.workspace_back_and_forth", label: "Re-pressing a workspace key goes back", type: "bool", def: false },
                    { key: "misc.close_special_on_empty", label: "Close special workspace when empty", type: "bool", def: true },
                    { key: "group.groupbar.enabled", label: "Tab bar on window groups", type: "bool", def: true }
                ]}
            ]
        },
        {
            id: "keyboard", label: "Keyboard", icon: "󰌌",
            groups: [
                { title: "Layout", fields: [
                    { key: "input.kb_layout", label: "Layouts", type: "text", def: "us", placeholder: "us",
                      hint: "Comma-separated for several, e.g. us,de" },
                    { key: "input.kb_variant", label: "Variants", type: "text", def: "", placeholder: "none",
                      hint: "One per layout, e.g. ,nodeadkeys" },
                    { key: "input.kb_options", label: "Options", type: "text", def: "", placeholder: "none",
                      hint: "XKB options, e.g. caps:escape,grp:alt_shift_toggle" }
                ]},
                { title: "Typing", fields: [
                    { key: "input.repeat_rate", label: "Key repeat rate", type: "int", min: 5, max: 100, unit: "/s", def: 25 },
                    { key: "input.repeat_delay", label: "Delay before repeat", type: "int", min: 100, max: 1500, step: 25, unit: "ms", def: 600 },
                    { key: "input.numlock_by_default", label: "Num Lock on at login", type: "bool", def: false }
                ]}
            ]
        },
        {
            // Rendered by widgets/KeybindsPage.qml: the rebindable binds come
            // from keybinds.json (bindDefaults), not from `fields`. The two
            // `bind.*` fields here are the workspace modifiers.
            id: "keybinds", label: "Keybinds", icon: "󰧹",
            keybinds: true,
            groups: [
                { title: "Workspaces", fields: [
                    { key: "bind.wsFocus", label: "Switch to workspace", type: "choice", def: bindDefaults.workspaces.focus,
                      hint: "Hold with a number key 1–0",
                      options: opts([["SUPER", "Super"], ["ALT", "Alt"], ["CTRL", "Ctrl"], ["SUPER + CTRL", "Super + Ctrl"]]) },
                    { key: "bind.wsMove", label: "Move window to workspace", type: "choice", def: bindDefaults.workspaces.move,
                      hint: "Hold with a number key 1–0",
                      options: opts([["SUPER + SHIFT", "Super + Shift"], ["SUPER + CTRL", "Super + Ctrl"],
                                     ["SUPER + ALT", "Super + Alt"], ["ALT + SHIFT", "Alt + Shift"]]) }
                ]}
            ]
        },
        {
            id: "pointer", label: "Mouse & Touchpad", icon: "󰍽",
            groups: [
                { title: "Mouse", fields: [
                    { key: "input.sensitivity", label: "Pointer speed", type: "float", min: -1, max: 1, step: 0.05, def: 0 },
                    { key: "input.accel_profile", label: "Acceleration", type: "choice", def: "",
                      options: opts([["", "Default"], ["adaptive", "Adaptive"], ["flat", "Flat"]]) },
                    { key: "input.natural_scroll", label: "Natural scrolling", type: "bool", def: false },
                    { key: "input.scroll_factor", label: "Scroll speed", type: "float", min: 0.1, max: 3, step: 0.05, unit: "×", def: 1 },
                    { key: "input.left_handed", label: "Left-handed buttons", type: "bool", def: false },
                    { key: "input.follow_mouse", label: "Focus follows mouse", type: "choice", def: 1,
                      options: opts([[1, "Always"], [2, "Loose"], [3, "Click only"], [0, "Off"]]) }
                ]},
                { title: "Touchpad", fields: [
                    { key: "input.touchpad.natural_scroll", label: "Natural scrolling", type: "bool", def: true },
                    { key: "input.touchpad.tap_to_click", label: "Tap to click", type: "bool", def: true },
                    { key: "input.touchpad.tap_and_drag", label: "Tap and drag", type: "bool", def: true },
                    { key: "input.touchpad.drag_lock", label: "Drag lock", type: "choice", def: 0,
                      options: opts([[0, "Off"], [1, "Timeout"], [2, "Sticky"]]) },
                    { key: "input.touchpad.disable_while_typing", label: "Disable while typing", type: "bool", def: true },
                    { key: "input.touchpad.clickfinger_behavior", label: "Two-finger click for right-click", type: "bool", def: false },
                    { key: "input.touchpad.middle_button_emulation", label: "Middle-click emulation", type: "bool", def: false },
                    { key: "input.touchpad.scroll_factor", label: "Scroll speed", type: "float", min: 0.1, max: 3, step: 0.05, unit: "×", def: 1 }
                ]},
                { title: "Gestures", fields: [
                    { key: "gestures.workspace_swipe_invert", label: "Invert swipe direction", type: "bool", def: true },
                    { key: "gestures.workspace_swipe_distance", label: "Swipe distance", type: "int", min: 100, max: 1200, step: 50, unit: "px", def: 300 },
                    { key: "gestures.workspace_swipe_cancel_ratio", label: "Commit threshold", type: "float", min: 0.1, max: 0.9, step: 0.05, percent: true, def: 0.5 },
                    { key: "gestures.workspace_swipe_create_new", label: "Swipe past last workspace creates one", type: "bool", def: true },
                    { key: "gestures.workspace_swipe_forever", label: "Swipe through many at once", type: "bool", def: false }
                ]},
                { title: "Cursor", fields: [
                    // `pointer.*` is applied with `hyprctl setcursor` + env
                    // (see pointerLua). Themes are installed in chasec.nix.
                    { key: "pointer.theme", label: "Cursor theme", type: "choice", def: "Bibata-Modern-Classic",
                      options: opts([
                          ["Bibata-Modern-Classic", "Bibata Modern · Classic"],
                          ["Bibata-Modern-Ice", "Bibata Modern · Ice"],
                          ["Bibata-Modern-Amber", "Bibata Modern · Amber"],
                          ["Bibata-Original-Classic", "Bibata Original · Classic"],
                          ["phinger-cursors-dark", "Phinger · Dark"],
                          ["phinger-cursors-light", "Phinger · Light"],
                          ["capitaine-cursors", "Capitaine · Dark"],
                          ["capitaine-cursors-white", "Capitaine · White"],
                          ["catppuccin-mocha-dark-cursors", "Catppuccin Mocha · Dark"],
                          ["catppuccin-mocha-light-cursors", "Catppuccin Mocha · Light"],
                          ["BreezeX-RosePine-Linux", "Rosé Pine"],
                          ["BreezeX-RosePineDawn-Linux", "Rosé Pine · Dawn"],
                          ["graphite-dark", "Graphite · Dark"],
                          ["graphite-light", "Graphite · Light"],
                          ["Vimix-cursors", "Vimix · Dark"],
                          ["Vimix-white-cursors", "Vimix · White"]
                      ]) },
                    { key: "pointer.size", label: "Cursor size", type: "choice", def: 24,
                      options: opts([[18, "Small"], [24, "Default"], [32, "Large"], [48, "Huge"]]) },
                    { key: "cursor.inactive_timeout", label: "Hide when idle", type: "int", min: 0, max: 30, unit: "s", def: 0,
                      hint: "0 keeps it visible" },
                    { key: "cursor.hide_on_key_press", label: "Hide while typing", type: "bool", def: false },
                    { key: "cursor.no_warps", label: "Never move the cursor automatically", type: "bool", def: false },
                    { key: "cursor.zoom_factor", label: "Screen magnifier", type: "float", min: 1, max: 5, step: 0.1, unit: "×", def: 1 }
                ]}
            ]
        },
        {
            id: "display", label: "Display", icon: "󰍹",
            monitors: true,
            groups: [
                // `color.*` keys are compiled into one screen shader (see
                // colorLua) — only the stages that differ from neutral are
                // emitted, and with everything neutral no shader runs at all.
                { title: "Color", fields: [
                    { key: "color.enabled", label: "Color adjustments", type: "bool", def: true,
                      hint: "Off compares against the untouched image. While any adjustment is active a screen shader runs, which costs a little GPU and disables direct scanout" },
                    { key: "color.brightness", label: "Brightness", type: "float", min: 0.5, max: 1.5, step: 0.01, percent: true, def: 1, dependsOn: "color.enabled" },
                    { key: "color.contrast", label: "Contrast", type: "float", min: 0.5, max: 1.5, step: 0.01, percent: true, def: 1, dependsOn: "color.enabled" },
                    { key: "color.saturation", label: "Saturation", type: "float", min: 0, max: 2, step: 0.01, percent: true, def: 1, dependsOn: "color.enabled" },
                    { key: "color.vibrance", label: "Vibrance", type: "float", min: -1, max: 1, step: 0.01, percent: true, def: 0, dependsOn: "color.enabled",
                      hint: "Saturation that boosts muted colors more than already-vivid ones" },
                    { key: "color.gamma", label: "Gamma", type: "float", min: 0.5, max: 2, step: 0.01, def: 1, dependsOn: "color.enabled",
                      hint: "Above 1 lifts midtones, below 1 deepens them" },
                    { key: "color.shadows", label: "Shadows", type: "float", min: -0.5, max: 0.5, step: 0.01, percent: true, def: 0, dependsOn: "color.enabled",
                      hint: "Lift or crush the darkest tones" },
                    { key: "color.highlights", label: "Highlights", type: "float", min: -0.5, max: 0.5, step: 0.01, percent: true, def: 0, dependsOn: "color.enabled" },
                    { key: "color.temperature", label: "Temperature", type: "float", min: -1, max: 1, step: 0.01, percent: true, def: 0, dependsOn: "color.enabled",
                      hint: "Cooler (blue) to warmer (amber)" },
                    { key: "color.tint", label: "Tint", type: "float", min: -1, max: 1, step: 0.01, percent: true, def: 0, dependsOn: "color.enabled",
                      hint: "Green to magenta" },
                    { key: "color.hue", label: "Hue shift", type: "int", min: -180, max: 180, unit: "°", def: 0, dependsOn: "color.enabled" },
                    { key: "color.sharpness", label: "Sharpness", type: "float", min: 0, max: 1, step: 0.01, percent: true, def: 0, dependsOn: "color.enabled" },
                    { key: "color.filter", label: "Color filter", type: "choice", def: "", dependsOn: "color.enabled",
                      options: opts([["", "None"], ["grayscale", "Grayscale"], ["sepia", "Sepia"], ["invert", "Invert"],
                                     ["protan", "Protanopia (red-blind) assist"], ["deutan", "Deuteranopia (green-blind) assist"],
                                     ["tritan", "Tritanopia (blue-blind) assist"]]) },
                    { key: "color.filterStrength", label: "Filter strength", type: "float", min: 0, max: 1, step: 0.01, percent: true, def: 1,
                      dependsOn: "color.filter" }
                ]},
                { title: "Advanced", fields: [
                    { key: "misc.vrr", label: "Variable refresh rate", type: "choice", def: 0,
                      options: opts([[0, "Off"], [1, "On"], [2, "Fullscreen"]]) },
                    { key: "general.allow_tearing", label: "Allow tearing (games that request it)", type: "bool", def: false },
                    { key: "xwayland.force_zero_scaling", label: "Unscaled XWayland apps", type: "bool", def: false,
                      hint: "Sharper X11 apps on scaled displays (they may render small)" },
                    { key: "misc.mouse_move_enables_dpms", label: "Mouse wakes the screen", type: "bool", def: false },
                    { key: "misc.key_press_enables_dpms", label: "Keypress wakes the screen", type: "bool", def: false }
                ]}
            ]
        },
        {
            // `island.*` keys are read by Quickshell (services/IslandConfig.qml)
            // and never sent to Hyprland.
            id: "island", label: "Dynamic Island", icon: "󰍜",
            groups: [
                { title: "Behaviour", fields: [
                    { key: "island.hoverExpand", label: "Expand on hover", type: "bool", def: true },
                    { key: "island.hoverDelay", label: "Hover delay", type: "int", min: 0, max: 600, step: 10, unit: "ms", def: 40,
                      dependsOn: "island.hoverExpand", hint: "How long the cursor rests on the island before it expands" },
                    { key: "island.collapseDelay", label: "Collapse delay", type: "int", min: 0, max: 1500, step: 25, unit: "ms", def: 150,
                      dependsOn: "island.hoverExpand", hint: "Grace period after the cursor leaves" },
                    { key: "island.clickAction", label: "Click", type: "choice", def: "control", options: opts(islandActions) },
                    { key: "island.rightClickAction", label: "Right-click", type: "choice", def: "launcher", options: opts(islandActions) },
                    { key: "island.middleClickAction", label: "Middle-click", type: "choice", def: "playpause", options: opts(islandActions) },
                    { key: "island.scrollAction", label: "Scroll", type: "choice", def: "volume",
                      options: opts([["volume", "Volume"], ["brightness", "Brightness"], ["workspace", "Switch workspace"], ["none", "Nothing"]]) },
                    { key: "island.trackPeek", label: "Expand briefly when the track changes", type: "bool", def: true },
                    { key: "island.trackPeekSeconds", label: "Track change duration", type: "float", min: 1, max: 8, step: 0.5, unit: "s", def: 3,
                      dependsOn: "island.trackPeek" },
                    { key: "island.osd", label: "Show volume & brightness changes", type: "bool", def: true },
                    { key: "island.osdSeconds", label: "Level indicator duration", type: "float", min: 0.5, max: 5, step: 0.1, unit: "s", def: 1.5,
                      dependsOn: "island.osd" }
                ]},
                { title: "Appearance", fields: [
                    { key: "island.offset", label: "Distance from top", type: "int", min: 0, max: 40, unit: "px", def: 6 },
                    { key: "island.attached", label: "Attach to the top edge (notch style)", type: "bool", def: false },
                    { key: "island.tint", label: "Palette tint", type: "float", min: 0, max: 1, step: 0.01, percent: true, def: 0.55,
                      hint: "0% is pure black; higher picks up the wallpaper's colours" },
                    { key: "island.opacity", label: "Opacity", type: "float", min: 0.5, max: 1, step: 0.01, percent: true, def: 1 },
                    { key: "island.rim", label: "Outline", type: "bool", def: true },
                    { key: "island.sheen", label: "Top highlight", type: "bool", def: true },
                    { key: "island.glow", label: "Accent glow", type: "float", min: 0, max: 0.5, step: 0.01, percent: true, def: 0.14 },
                    { key: "island.shadow", label: "Shadow", type: "float", min: 0, max: 1, step: 0.05, percent: true, def: 0.45 },
                    { key: "island.panelRadius", label: "Expanded corner radius", type: "int", min: 12, max: 44, unit: "px", def: 30 },
                    { key: "island.dim", label: "Dim the screen behind panels", type: "float", min: 0, max: 0.7, step: 0.01, percent: true, def: 0.3 }
                ]},
                { title: "Motion", fields: [
                    { key: "island.animate", label: "Animate", type: "bool", def: true },
                    { key: "island.morphMs", label: "Morph duration", type: "int", min: 120, max: 900, step: 10, unit: "ms", def: 380,
                      dependsOn: "island.animate" },
                    { key: "island.bounce", label: "Bounce", type: "float", min: 0, max: 2, step: 0.05, def: 0.75,
                      dependsOn: "island.animate", hint: "0 settles without overshooting" },
                    { key: "island.fadeMs", label: "Content fade", type: "int", min: 60, max: 500, step: 10, unit: "ms", def: 180,
                      dependsOn: "island.animate" }
                ]},
                { title: "Resting pill", fields: [
                    { key: "island.showWorkspaces", label: "Workspaces", type: "bool", def: true },
                    { key: "island.clockFormat", label: "Clock", type: "choice", def: "24",
                      options: opts([["24", "24-hour"], ["12", "12-hour"]]) },
                    { key: "island.showSeconds", label: "Show seconds", type: "bool", def: false },
                    { key: "island.blinkColon", label: "Blinking colon", type: "bool", def: true },
                    { key: "island.showArt", label: "Album art while playing", type: "bool", def: true },
                    { key: "island.showEqualizer", label: "Equalizer while a player is open", type: "bool", def: true },
                    { key: "island.showIndicators", label: "Do Not Disturb & Caffeine icons", type: "bool", def: true },
                    { key: "island.battery", label: "Battery", type: "choice", def: "low",
                      options: opts([["low", "When low"], ["always", "Always"], ["never", "Never"]]) }
                ]},
                { title: "Hover view", fields: [
                    { key: "island.peekMedia", label: "Media controls", type: "bool", def: true },
                    { key: "island.peekStatus", label: "Network, volume & battery", type: "bool", def: true },
                    { key: "island.peekTray", label: "System tray", type: "bool", def: true },
                    { key: "island.peekDate", label: "Date under the clock", type: "bool", def: true }
                ]},
                { title: "Launcher", fields: [
                    { key: "island.launcherRows", label: "Visible results", type: "int", min: 3, max: 12, def: 7 },
                    { key: "island.launcherCalc", label: "Calculator", type: "bool", def: true,
                      hint: "Type a sum like 12*(3+4) to see the answer" }
                ]}
            ]
        },
        {
            id: "shell", label: "Shell", icon: "󰘳",
            groups: [
                { title: "Island", fields: [
                    { key: "shell.nightTemp", label: "Night light warmth", type: "int", min: 2500, max: 6500, step: 100, unit: "K", def: 4500,
                      hint: "Lower is warmer" },
                    { key: "shell.toastSeconds", label: "Notification duration", type: "int", min: 2, max: 20, unit: "s", def: 6 }
                ]},
                { title: "System", fields: [
                    { key: "misc.middle_click_paste", label: "Middle-click paste", type: "bool", def: true },
                    { key: "ecosystem.no_update_news", label: "Hide Hyprland update news", type: "bool", def: false }
                ]}
            ]
        }
    ]

    readonly property var fieldMap: {
        const m = {};
        for (const s of sections)
            for (const g of s.groups)
                for (const f of g.fields) m[f.key] = Object.assign({ section: s.id, group: g.title }, f);
        return m;
    }

    // ---- reading -----------------------------------------------------------
    function field(key) {
        return fieldMap[key];
    }
    function get(key) {
        return key in overrides ? overrides[key] : fieldMap[key]?.def;
    }
    function isDefault(key) {
        return !(key in overrides);
    }
    function enabled(key) {
        const dep = fieldMap[key]?.dependsOn;
        return !dep || !!get(dep);
    }
    function changedIn(sectionId) {
        return Object.keys(overrides).filter(k => fieldMap[k]?.section === sectionId).length
            + (sectionId === "display" ? Object.keys(monitorOverrides).length : 0)
            + (sectionId === "keybinds" ? Object.keys(bindOverrides).length + customBinds.length : 0);
    }

    // ---- writing -----------------------------------------------------------
    function normalize(f, v) {
        if (f.type === "bool") return !!v;
        if (f.type === "int") return Math.round(Math.max(f.min, Math.min(f.max, Number(v))));
        if (f.type === "float") {
            const step = f.step ?? 0.01;
            const snapped = Math.round(Number(v) / step) * step;
            return Number(Math.max(f.min, Math.min(f.max, snapped)).toFixed(4));
        }
        if (f.type === "text") return String(v).replace(/[^A-Za-z0-9_,:.()+\- ]/g, "").trim();
        return v;
    }

    function set(key, value) {
        const f = fieldMap[key];
        if (!f) return;
        const v = normalize(f, value);
        const o = Object.assign({}, overrides);
        if (v === f.def) delete o[key];
        else o[key] = v;
        if (JSON.stringify(o) === JSON.stringify(overrides)) return;
        overrides = o;
        queueLive(key);
        saveTimer.restart();
    }
    function reset(key) {
        const f = fieldMap[key];
        if (f) set(key, f.def);
    }
    function resetSection(sectionId) {
        for (const k of Object.keys(overrides))
            if (fieldMap[k]?.section === sectionId) reset(k);
        if (sectionId === "display")
            for (const m of Object.keys(monitorOverrides)) resetMonitor(m);
        if (sectionId === "keybinds" && (Object.keys(bindOverrides).length || customBinds.length)) {
            bindOverrides = {};
            customBinds = [];
            commitBinds();
        }
    }

    // ---- keybinds ----------------------------------------------------------
    // Defaults live in keybinds.json, which hyprland.nix also reads to bind
    // them at startup. Overrides are applied by unbinding every managed
    // combo and rebinding the effective set — hl.unbind drops *all* binds on
    // a combo, so rebinding one at a time would break when two binds share
    // keys. hl.unbind only matches the exact string a bind was made with, so
    // combos are always written "MOD + MOD + key" in SUPER, CTRL, ALT, SHIFT
    // order (the order keybinds.json uses).
    FileView {
        id: bindDefaultsFile
        path: Quickshell.shellPath("keybinds.json")
        blockLoading: true
    }
    readonly property var bindDefaults: {
        try {
            const d = JSON.parse(bindDefaultsFile.text());
            if (Array.isArray(d.binds)) return d;
        } catch (e) {
            console.warn("keybinds.json unreadable:", e);
        }
        return { groups: [], workspaces: { focus: "SUPER", move: "SUPER + SHIFT" }, binds: [], reserved: [] };
    }
    readonly property var bindMap: {
        const m = {};
        for (const b of bindDefaults.binds) m[b.id] = b;
        return m;
    }

    property var bindOverrides: ({})   // bind id -> keys ("" = unbound)
    property var customBinds: []        // [{ keys, exec }] user-added shortcuts
    property var appliedCombos: []      // combos the last apply bound
    property bool recording: false

    function bindKeys(id) {
        return id in bindOverrides ? bindOverrides[id] : (bindMap[id]?.keys ?? "");
    }
    function bindIsDefault(id) {
        return !(id in bindOverrides);
    }
    function setBind(id, keys) {
        const b = bindMap[id];
        if (!b) return;
        const o = Object.assign({}, bindOverrides);
        if (keys === b.keys) delete o[id];
        else o[id] = keys;
        if (JSON.stringify(o) === JSON.stringify(bindOverrides)) return;
        bindOverrides = o;
        commitBinds();
    }
    function resetBind(id) {
        if (bindMap[id]) setBind(id, bindMap[id].keys);
    }
    function addCustomBind() {
        customBinds = [...customBinds, { keys: "", exec: "" }];
        saveTimer.restart();
    }
    function setCustomBind(i, patch) {
        const l = customBinds.slice();
        l[i] = Object.assign({}, l[i], patch);
        customBinds = l;
        commitBinds();
    }
    function removeCustomBind(i) {
        const l = customBinds.slice();
        l.splice(i, 1);
        customBinds = l;
        commitBinds();
    }
    function commitBinds() {
        applyBinds();
        saveTimer.restart();
    }

    // Order-insensitive identity of a combo, for conflict checks only.
    function comboId(keys) {
        const parts = String(keys ?? "").split("+").map(s => s.trim()).filter(s => s !== "");
        if (parts.length === 0) return "";
        const key = parts.pop().toLowerCase();
        const mods = [...new Set(parts.map(p => p.toUpperCase()))].sort();
        return [...mods, key].join("+");
    }
    function wsKeys(mod, i) {
        return `${mod} + ${i % 10}`;
    }

    // comboId -> [{ owner, label }] for everything bound to a key.
    readonly property var comboOwners: {
        const m = {};
        const add = (keys, owner, label) => {
            const id = comboId(keys);
            if (id) (m[id] = m[id] ?? []).push({ owner: owner, label: label });
        };
        for (const b of bindDefaults.binds) add(bindKeys(b.id), "bind:" + b.id, b.label);
        const f = get("bind.wsFocus"), mv = get("bind.wsMove");
        for (let i = 1; i <= 10; i++) {
            add(wsKeys(f, i), "ws:focus", `Switch to workspace ${i}`);
            add(wsKeys(mv, i), "ws:move", `Move window to workspace ${i}`);
        }
        customBinds.forEach((c, i) => {
            if (c.exec.trim()) add(c.keys, "custom:" + i, c.exec.trim());
        });
        for (const r of bindDefaults.reserved ?? []) add(r.keys, "reserved", r.label);
        return m;
    }
    // Labels of the other things bound to `keys` besides `owner`.
    function conflicts(keys, owner) {
        return (comboOwners[comboId(keys)] ?? []).filter(o => o.owner !== owner).map(o => o.label);
    }
    // Reserved combos stay bound by hyprland.nix (media keys); rebinding them
    // here would unbind the original, so the recorder refuses them.
    function reservedLabel(keys) {
        return (comboOwners[comboId(keys)] ?? []).find(o => o.owner === "reserved")?.label ?? "";
    }

    function bindDsp(b) {
        return "exec" in b ? `hl.dsp.exec_cmd(${luaValue(b.exec)})` : b.dsp;
    }
    function effectiveBinds() {
        const out = [];
        for (const b of bindDefaults.binds) {
            const k = bindKeys(b.id);
            if (k) out.push({ keys: k, dsp: bindDsp(b), opts: b.opts });
        }
        const f = get("bind.wsFocus"), mv = get("bind.wsMove");
        for (let i = 1; i <= 10; i++) {
            out.push({ keys: wsKeys(f, i), dsp: `hl.dsp.focus({ workspace = ${i} })` });
            out.push({ keys: wsKeys(mv, i), dsp: `hl.dsp.window.move({ workspace = ${i} })` });
        }
        for (const c of customBinds)
            if (c.keys && c.exec.trim()) out.push({ keys: c.keys, dsp: `hl.dsp.exec_cmd(${luaValue(c.exec.trim())})` });
        return out;
    }
    function defaultCombos() {
        const d = bindDefaults;
        const l = d.binds.map(b => b.keys);
        for (let i = 1; i <= 10; i++) l.push(wsKeys(d.workspaces.focus, i), wsKeys(d.workspaces.move, i));
        return l;
    }
    function bindsCustomized() {
        return Object.keys(bindOverrides).length > 0 || !isDefault("bind.wsFocus") || !isDefault("bind.wsMove")
            || customBinds.some(c => c.keys && c.exec.trim());
    }
    function bindsLua(alsoUnbind) {
        const eff = effectiveBinds();
        const un = [...new Set([...defaultCombos(), ...alsoUnbind, ...eff.map(e => e.keys)])];
        // No leading comment: `hyprctl eval --…` would parse it as a flag.
        return [
            ...un.map(k => `pcall(hl.unbind, ${luaValue(k)})`),
            ...eff.map(e => `pcall(hl.bind, ${luaValue(e.keys)}, ${e.dsp}${e.opts ? ", " + e.opts : ""})`)
        ].join("\n");
    }
    function applyBinds() {
        runLua(bindsLua(appliedCombos));
        appliedCombos = effectiveBinds().map(e => e.keys);
    }

    // While a shortcut is being recorded Hyprland sits in an empty submap, so
    // combos like SUPER+Q reach the panel instead of firing. Escape leaves it
    // (non-consuming, so the panel still sees it) in case Quickshell dies
    // mid-recording.
    function beginRecording() {
        recording = true;
        runLua('hl.define_submap("qs_keyrecord", function() hl.unbind("Escape") '
            + 'hl.bind("Escape", hl.dsp.submap("reset"), { non_consuming = true }) end) '
            + 'hl.dispatch(hl.dsp.submap("qs_keyrecord"))');
    }
    function endRecording() {
        if (!recording) return;
        recording = false;
        runLua('hl.dispatch(hl.dsp.submap("reset"))');
    }

    // ---- monitors ----------------------------------------------------------
    // Base from hyprland.nix: every output at 1920x1080@60, scale 1.
    readonly property var monitorBase: ({ mode: "1920x1080@60", scale: 1 })
    property var monitorList: [] // hyprctl -j monitors

    Process {
        id: monProc
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitorList = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    function refreshMonitors() {
        monProc.running = true;
    }

    function monitorConfig(name) {
        return Object.assign({}, monitorBase, monitorOverrides[name] ?? {});
    }
    function setMonitor(name, cfg) {
        const merged = Object.assign({}, monitorConfig(name), cfg);
        const o = Object.assign({}, monitorOverrides);
        if (merged.mode === monitorBase.mode && merged.scale === monitorBase.scale) delete o[name];
        else o[name] = merged;
        monitorOverrides = o;
        runLua(monitorLua(name, merged));
        saveTimer.restart();
        monitorRefresh.restart();
    }
    function resetMonitor(name) {
        setMonitor(name, monitorBase);
    }

    // Display changes from the panel go through here: they apply at once but
    // revert after a countdown unless kept, so a bad mode can't strand you on
    // a black screen. Lives in the service (not the card) because the card is
    // rebuilt when the monitor list refreshes — and the revert must still
    // fire if the panel is closed.
    property var monitorPending: null   // { name, previous: { mode, scale } }
    property int monitorCountdown: 0

    function changeMonitor(name, cfg, current) {
        if (!monitorPending || monitorPending.name !== name)
            monitorPending = { name: name, previous: current };
        monitorCountdown = 12;
        confirmTimer.restart();
        setMonitor(name, cfg);
    }
    function keepMonitor() {
        monitorPending = null;
        monitorCountdown = 0;
        confirmTimer.stop();
    }
    function revertMonitor() {
        const p = monitorPending;
        keepMonitor();
        if (p) setMonitor(p.name, p.previous);
    }
    Timer {
        id: confirmTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.monitorCountdown--;
            if (root.monitorCountdown <= 0) root.revertMonitor();
        }
    }
    Timer {
        id: monitorRefresh
        interval: 900
        onTriggered: root.refreshMonitors()
    }

    // ---- Lua generation ----------------------------------------------------
    function luaValue(v) {
        if (typeof v === "boolean") return v ? "true" : "false";
        if (typeof v === "number") return String(v);
        return '"' + String(v).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
    }

    readonly property string luaHelper:
        "local function set(path, value) " +
        "local t = {} local cur = t local parts = {} " +
        "for p in string.gmatch(path, \"[^.]+\") do parts[#parts + 1] = p end " +
        "for i = 1, #parts - 1 do cur[parts[i]] = {} cur = cur[parts[i]] end " +
        "cur[parts[#parts]] = value pcall(hl.config, t) end\n"

    function configLine(key) {
        return `set(${luaValue(key)}, ${luaValue(get(key))})`;
    }

    // Mirrors the hl.animation table in hyprland.nix; `scale` stretches every
    // speed (Hyprland speeds are durations, so bigger = slower).
    function animationLua() {
        const k = get("anim.scale");
        const w = get("anim.windows");
        const ws = get("anim.workspaces");
        // "Open windows out of the island": Quickshell's WindowLaunch.qml
        // draws the opening, so Hyprland's own windowsIn motion is switched
        // off (two animations at once looked doubled) and the window just
        // fades in late (islandReveal), as the launch shape lands.
        const launch = !!get("island.windowLaunch");
        const sp = s => Number((s * k).toFixed(2));
        const leaves = [
            `{ leaf = "global", enabled = true, speed = ${sp(10)}, bezier = "default" }`,
            `{ leaf = "border", enabled = true, speed = ${sp(5.39)}, bezier = "easeOutQuint" }`,
            `{ leaf = "windows", enabled = true, speed = ${sp(4.79)}, spring = "easy" }`,
            `{ leaf = "windowsIn", enabled = ${!launch}, speed = ${sp(4.1)}, spring = "easy", style = ${luaValue(w)} }`,
            `{ leaf = "windowsOut", enabled = true, speed = ${sp(1.49)}, bezier = "linear", style = ${luaValue(w)} }`,
            `{ leaf = "fade", enabled = true, speed = ${sp(3.03)}, bezier = "easeOutQuint" }`,
            launch
                ? `{ leaf = "fadeIn", enabled = true, speed = 5, bezier = "islandReveal" }`
                : `{ leaf = "fadeIn", enabled = true, speed = ${sp(3.03)}, bezier = "easeOutQuint" }`,
            `{ leaf = "layers", enabled = true, speed = ${sp(3.81)}, bezier = "easeOutQuint" }`,
            `{ leaf = "layersIn", enabled = true, speed = ${sp(4)}, bezier = "easeOutQuint", style = "fade" }`,
            `{ leaf = "layersOut", enabled = true, speed = ${sp(1.5)}, bezier = "linear", style = "fade" }`,
            `{ leaf = "workspaces", enabled = true, speed = ${sp(1.94)}, bezier = "easeInOutCubic", style = ${luaValue(ws)} }`
        ];
        return leaves.map(l => `pcall(hl.animation, ${l})`).join("\n");
    }

    function monitorLua(name, cfg) {
        return `pcall(hl.monitor, { output = ${luaValue(name)}, mode = ${luaValue(cfg.mode)}, position = "auto", scale = ${luaValue(cfg.scale)} })`;
    }

    // ---- screen color shader -----------------------------------------------
    readonly property string shaderPath: dir + "/screen-shader.frag"

    function glf(v) {
        return Number(v).toFixed(5);
    }

    // GLSL ES 3.0 fragment shader for decoration.screen_shader, or "" when
    // every adjustment is neutral (so no shader runs and scanout stays direct).
    function colorShader() {
        if (!get("color.enabled")) return "";
        const v = k => get("color." + k);
        const body = [];

        if (v("sharpness") > 0) body.push(`
    {   // unsharp mask against the 4 neighbours
        vec2 o = 1.0 / vec2(textureSize(tex, 0));
        vec3 blur = (texture(tex, v_texcoord + vec2(o.x, 0.0)).rgb + texture(tex, v_texcoord - vec2(o.x, 0.0)).rgb
                   + texture(tex, v_texcoord + vec2(0.0, o.y)).rgb + texture(tex, v_texcoord - vec2(0.0, o.y)).rgb) * 0.25;
        c += (c - blur) * ${glf(v("sharpness") * 2)};
    }`);
        if (v("brightness") !== 1) body.push(`    c *= ${glf(v("brightness"))};`);
        if (v("temperature") !== 0 || v("tint") !== 0) {
            const t = v("temperature"), g = v("tint");
            body.push(`    c *= vec3(${glf(1 + 0.12 * t)}, ${glf(1 - 0.10 * g)}, ${glf(1 - 0.12 * t)});`);
        }
        if (v("shadows") !== 0) body.push(`    c += ${glf(v("shadows"))} * pow(clamp(1.0 - c, 0.0, 1.0), vec3(3.0));`);
        if (v("highlights") !== 0) body.push(`    c += ${glf(v("highlights"))} * pow(clamp(c, 0.0, 1.0), vec3(3.0));`);
        if (v("contrast") !== 1) body.push(`    c = (c - 0.5) * ${glf(v("contrast"))} + 0.5;`);
        if (v("saturation") !== 1 || v("vibrance") !== 0) body.push(`
    {
        float l = dot(c, LUMA);
        float spread = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
        float amount = ${glf(v("saturation"))} * (1.0 + ${glf(v("vibrance"))} * (1.0 - clamp(spread, 0.0, 1.0)));
        c = mix(vec3(l), c, amount);
    }`);
        if (v("hue") !== 0) {
            const a = v("hue") * Math.PI / 180;
            body.push(`
    {   // rotate chroma in YIQ space
        float y = dot(c, vec3(0.299, 0.587, 0.114));
        float i = dot(c, vec3(0.596, -0.274, -0.322));
        float q = dot(c, vec3(0.211, -0.523, 0.312));
        float i2 = i * ${glf(Math.cos(a))} - q * ${glf(Math.sin(a))};
        float q2 = i * ${glf(Math.sin(a))} + q * ${glf(Math.cos(a))};
        c = vec3(y + 0.956 * i2 + 0.621 * q2, y - 0.272 * i2 - 0.647 * q2, y - 1.106 * i2 + 1.703 * q2);
    }`);
        }
        if (v("gamma") !== 1) body.push(`    c = pow(max(c, 0.0), vec3(${glf(1 / v("gamma"))}));`);

        const filter = v("filter");
        if (filter && v("filterStrength") > 0) {
            let f;
            if (filter === "grayscale") f = "vec3(dot(c, LUMA))";
            else if (filter === "sepia") f = "vec3(dot(c, vec3(0.393, 0.769, 0.189)), dot(c, vec3(0.349, 0.686, 0.168)), dot(c, vec3(0.272, 0.534, 0.131)))";
            else if (filter === "invert") f = "1.0 - c";
            else f = `daltonize(c, ${ { protan: 0, deutan: 1, tritan: 2 }[filter] })`;
            body.push(`    c = mix(c, ${f}, ${glf(v("filterStrength"))});`);
        }

        if (body.length === 0) return "";

        const dalton = ["protan", "deutan", "tritan"].includes(filter) ? `
// Daltonization: simulate the deficiency in LMS space, then shift the lost
// information into channels the viewer can still distinguish.
vec3 daltonize(vec3 c, int kind) {
    float L = 17.8824 * c.r + 43.5161 * c.g + 4.11935 * c.b;
    float M = 3.45565 * c.r + 27.1554 * c.g + 3.86714 * c.b;
    float S = 0.0299566 * c.r + 0.184309 * c.g + 1.46709 * c.b;
    if (kind == 0) L = 2.02344 * M - 2.52581 * S;
    else if (kind == 1) M = 0.494207 * L + 1.24827 * S;
    else S = -0.395913 * L + 0.801109 * M;
    vec3 sim = vec3(
        0.0809444479 * L - 0.130504409 * M + 0.116721066 * S,
        -0.0102485335 * L + 0.0540193266 * M - 0.113614708 * S,
        -0.000365296938 * L - 0.00412161469 * M + 0.693511405 * S);
    vec3 err = c - sim;
    return c + vec3(0.0, 0.7 * err.r + err.g, 0.7 * err.r + err.b);
}
` : "";

        return `#version 300 es
// GENERATED by the Quickshell settings panel (Display › Color).
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
${dalton}
void main() {
    vec4 px = texture(tex, v_texcoord);
    vec3 c = px.rgb;
${body.join("\n")}
    fragColor = vec4(clamp(c, 0.0, 1.0), px.a);
}
`;
    }

    // Lua that writes the shader beside settings.lua and points Hyprland at
    // it — so settings.lua stays self-contained at startup, and the same
    // chunk is what live changes eval. Re-setting the same path reloads it.
    function colorLua() {
        const src = colorShader();
        if (src === "") return `pcall(hl.config, { decoration = { screen_shader = "" } })`;
        return [
            `do`,
            `  local path = ${luaValue(shaderPath)}`,
            `  local f = io.open(path, "w")`,
            `  if f then`,
            `    f:write([==[${src}]==])`,
            `    f:close()`,
            `    pcall(hl.config, { decoration = { screen_shader = path } })`,
            `  end`,
            `end`
        ].join("\n");
    }

    // ---- cursor theme ------------------------------------------------------
    // At startup, Hyprland picks the cursor from these env vars (set before
    // its cursor manager starts), and apps it launches inherit them. A running
    // compositor needs `hyprctl setcursor` instead, which also syncs the
    // theme to gsettings for GTK apps (cursor.sync_gsettings_theme).
    function pointerLua() {
        const t = luaValue(get("pointer.theme"));
        const s = luaValue(String(get("pointer.size")));
        return [
            `pcall(hl.env, "XCURSOR_THEME", ${t})`,
            `pcall(hl.env, "HYPRCURSOR_THEME", ${t})`,
            `pcall(hl.env, "XCURSOR_SIZE", ${s})`,
            `pcall(hl.env, "HYPRCURSOR_SIZE", ${s})`
        ].join("\n");
    }
    function applyCursor() {
        Quickshell.execDetached(["hyprctl", "setcursor", get("pointer.theme"), String(get("pointer.size"))]);
    }

    function fullLua() {
        const lines = [
            "-- GENERATED by the Quickshell settings panel (SUPER+I).",
            "-- Edit settings there; this file is rewritten on every change.",
            "-- Loaded last by hyprland.lua, so it overrides the Nix defaults.",
            luaHelper
        ];
        for (const k of Object.keys(overrides).sort()) {
            if (isLocal(k) || k.startsWith("anim.") || k.startsWith("color.") || k.startsWith("pointer.") || k.startsWith("bind.")) continue;
            lines.push(configLine(k));
        }
        if (Object.keys(overrides).some(k => root.isAnimKey(k))) lines.push(animationLua());
        if (Object.keys(overrides).some(k => k.startsWith("color."))) lines.push(colorLua());
        if (Object.keys(overrides).some(k => k.startsWith("pointer."))) lines.push(pointerLua());
        if (bindsCustomized())
            lines.push("-- Keybinds: drop every managed bind, then rebind the effective set", bindsLua([]));
        for (const m of Object.keys(monitorOverrides).sort())
            lines.push(monitorLua(m, monitorOverrides[m]));
        return lines.join("\n") + "\n";
    }

    // ---- live apply (coalesced) --------------------------------------------
    property var pendingKeys: ({})
    function queueLive(key) {
        if (key.startsWith("bind.")) {
            applyBinds();
            return;
        }
        if (isLocal(key) && !isAnimKey(key)) return;
        const p = Object.assign({}, pendingKeys);
        p[key] = true;
        pendingKeys = p;
        liveTimer.restart();
    }
    Timer {
        id: liveTimer
        interval: 50
        onTriggered: {
            const keys = Object.keys(root.pendingKeys);
            root.pendingKeys = {};
            if (keys.length === 0) return;
            const lines = [root.luaHelper];
            for (const k of keys)
                if (!root.isLocal(k) && !k.startsWith("anim.") && !k.startsWith("color.") && !k.startsWith("pointer."))
                    lines.push(root.configLine(k));
            if (keys.some(k => root.isAnimKey(k))) lines.push(root.animationLua());
            if (keys.some(k => k.startsWith("color."))) lines.push(root.colorLua());
            if (keys.some(k => k.startsWith("pointer."))) {
                lines.push(root.pointerLua());
                root.applyCursor();
            }
            root.runLua(lines.join("\n"));
        }
    }

    property var luaQueue: []
    function runLua(code) {
        luaQueue = [...luaQueue, code];
        if (!evalProc.running) pumpLua();
    }
    function pumpLua() {
        if (luaQueue.length === 0) return;
        // Merge everything queued while the last eval ran into one call.
        evalProc.command = ["hyprctl", "eval", luaQueue.join("\n")];
        luaQueue = [];
        evalProc.running = true;
    }
    Process {
        id: evalProc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root.lastError = t.startsWith("error") ? t.replace(/^error:\s*/, "") : "";
            }
        }
        onExited: root.pumpLua()
    }

    // ---- persistence -------------------------------------------------------
    FileView {
        id: jsonFile
        path: root.jsonPath
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                const o = {};
                for (const [k, v] of Object.entries(d.values ?? {}))
                    if (root.fieldMap[k]) o[k] = v;
                root.overrides = o;
                root.monitorOverrides = d.monitors ?? {};
                const b = {};
                for (const [id, keys] of Object.entries(d.binds ?? {}))
                    if (root.bindMap[id] && typeof keys === "string") b[id] = keys;
                root.bindOverrides = b;
                root.customBinds = (d.customBinds ?? [])
                    .filter(c => c && typeof c.keys === "string" && typeof c.exec === "string")
                    .map(c => ({ keys: c.keys, exec: c.exec }));
            } catch (e) {
                console.warn("settings.json unreadable, starting fresh:", e);
            }
            root.markBindsApplied();
            root.loaded = true;
        }
        onLoadFailed: {
            root.markBindsApplied();
            root.loaded = true;
        }
    }
    // settings.lua already applied these at startup.
    function markBindsApplied() {
        appliedCombos = effectiveBinds().map(e => e.keys);
    }
    FileView {
        id: luaFile
        path: root.luaPath
        printErrors: false
        blockLoading: false
    }
    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            jsonFile.setText(JSON.stringify({
                values: root.overrides,
                monitors: root.monitorOverrides,
                binds: root.bindOverrides,
                customBinds: root.customBinds
            }, null, 2) + "\n");
            luaFile.setText(root.fullLua());
        }
    }
}
