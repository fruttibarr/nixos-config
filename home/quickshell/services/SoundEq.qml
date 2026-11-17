pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "root:/"

// System-wide 5-band equalizer. The DSP is a PipeWire filter-chain defined in
// equalizer.nix (node "effect_input.eq"); this pushes gains into it live with
// `pw-cli set-param` and remembers them, since PipeWire itself starts flat
// on every restart.
//
// Off just sends a flat curve: the filter stays in the graph, so toggling
// never re-routes audio or causes a dropout.
Singleton {
    id: root

    readonly property var bands: [
        { label: "60", unit: "Hz", name: "Bass" },
        { label: "250", unit: "Hz", name: "Low mids" },
        { label: "1k", unit: "Hz", name: "Mids" },
        { label: "4k", unit: "Hz", name: "Presence" },
        { label: "12k", unit: "Hz", name: "Treble" }
    ]
    readonly property real maxDb: 12

    readonly property var presets: [
        { id: "flat", label: "Flat", gains: [0, 0, 0, 0, 0] },
        { id: "bass", label: "Bass", gains: [6, 3, 0, 0, 0] },
        { id: "vocal", label: "Vocal", gains: [-2, -1, 3, 3, 0] },
        { id: "treble", label: "Treble", gains: [0, 0, 0, 3, 6] }
    ]

    property bool enabled: false
    property var gains: [0, 0, 0, 0, 0]

    // Which preset the current curve matches, or "custom".
    readonly property string preset: {
        for (const p of presets)
            if (p.gains.every((g, i) => Math.abs(g - gains[i]) < 0.05)) return p.id;
        return "custom";
    }

    // The filter node, found by name. Its id changes whenever PipeWire
    // restarts, so everything keys off this binding.
    readonly property PwNode node: Pipewire.nodes.values.find(n => n.name === "effect_input.eq") ?? null
    readonly property bool available: node !== null
    onNodeChanged: if (node) apply()

    // ---- public API ---------------------------------------------------------
    function setEnabled(on) {
        enabled = on;
        apply();
        save();
    }
    function setGain(i, db) {
        const g = gains.slice();
        g[i] = Math.round(Math.max(-maxDb, Math.min(maxDb, db)) * 2) / 2; // 0.5 dB steps
        gains = g;
        if (!enabled) enabled = true;   // touching a slider means "I want EQ"
        apply();
        save();
    }
    function setPreset(id) {
        const p = presets.find(x => x.id === id);
        if (!p) return;
        gains = p.gains.slice();
        enabled = id !== "flat";
        apply();
        save();
    }

    // `qs ipc call eq toggle` / `qs ipc call eq preset bass` (flat, bass,
    // vocal, treble), e.g. for a keybind.
    IpcHandler {
        target: "eq"
        function toggle(): void {
            root.setEnabled(!root.enabled);
        }
        function preset(id: string): void {
            root.setPreset(id);
        }
    }

    // ---- applying -----------------------------------------------------------
    // Coalesced: a slider drag fires many changes, but only the latest curve
    // needs to reach PipeWire, at most every ~40 ms.
    function apply() {
        applyTimer.restart();
    }
    Timer {
        id: applyTimer
        interval: 40
        onTriggered: root.push()
    }

    function push() {
        if (!node) return;
        const g = enabled ? gains : [0, 0, 0, 0, 0];
        // Pull the preamp down by the biggest boost so a boosted curve can't
        // clip (a band at +6 dB can double the peak level).
        const headroom = Math.max(0, ...g);
        const mult = Math.pow(10, -headroom / 20);
        const params = [`"eq_preamp:Mult" ${mult.toFixed(4)}`];
        g.forEach((v, i) => params.push(`"eq_band_${i + 1}:Gain" ${Number(v).toFixed(1)}`));
        setProc.command = ["pw-cli", "set-param", String(node.id), "Props",
            `{ params = [ ${params.join(" ")} ] }`];
        if (setProc.running) applyTimer.restart();   // try again once this one exits
        else setProc.running = true;
    }
    Process {
        id: setProc
    }

    // ---- persistence --------------------------------------------------------
    FileView {
        id: stateFile
        path: Quickshell.stateDir + "/equalizer.json"
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                if (Array.isArray(s.gains) && s.gains.length === 5) root.gains = s.gains.map(Number);
                root.enabled = !!s.enabled;
            } catch (e) {}
            root.apply();
        }
    }
    function save() {
        stateFile.setText(JSON.stringify({ enabled: enabled, gains: gains }));
    }
}
