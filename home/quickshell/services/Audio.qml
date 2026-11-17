pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "root:/"

// Default sink/source, tracked so their volume is readable and writable.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property string icon: {
        if (muted || volume <= 0.001) return "󰝟";
        if (volume > 0.66) return "󰕾";
        if (volume > 0.33) return "󰖀";
        return "󰕿";
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n !== null)
    }

    function setVolume(v) {
        if (!sink?.audio) return;
        sink.audio.volume = Math.max(0, Math.min(1, v));
        if (sink.audio.muted && v > 0) sink.audio.muted = false;
    }
    function nudge(delta) {
        setVolume(volume + delta);
    }
    function toggleMute() {
        if (sink?.audio) sink.audio.muted = !sink.audio.muted;
    }
    function toggleMic() {
        if (source?.audio) source.audio.muted = !source.audio.muted;
    }

    readonly property real micVolume: source?.audio?.volume ?? 0
    function setMicVolume(v) {
        if (!source?.audio) return;
        source.audio.volume = Math.max(0, Math.min(1, v));
        if (source.audio.muted && v > 0) source.audio.muted = false;
    }

    // ---- devices -------------------------------------------------------------
    // Hardware outputs/inputs (not app streams). A headphone jack is a *port*
    // on the same card and PipeWire switches it on its own; HDMI/DP audio and
    // Bluetooth headsets show up here as separate devices.
    readonly property var sinks: Pipewire.nodes.values
        .filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values
        .filter(n => !n.isSink && !n.isStream && n.audio)

    function setSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }
    function setSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function deviceName(n) {
        // description first: it tells apart nodes sharing a nickname (e.g. two
        // microphones on one card).
        return n?.description || n?.nickname || n?.name || "Unknown device";
    }
    function deviceIcon(n, input) {
        const p = n?.properties ?? {};
        const name = (n?.name ?? "").toLowerCase();
        const form = String(p["device.form-factor"] ?? "").toLowerCase();
        const bus = String(p["device.bus"] ?? "").toLowerCase();
        if (input) {
            if (form.includes("headset") || name.includes("bluez")) return "󰋎";
            if (form === "webcam") return "󰄀";
            return "󰍬";
        }
        if (name.includes("bluez") || bus === "bluetooth")
            return form.includes("head") ? "󰋋" : "󰂰";
        if (name.includes("hdmi") || name.includes("displayport") || form === "tv") return "󰡁";
        if (form.includes("head")) return "󰋋";
        if (bus === "usb") return "󰓃";
        return "󰓃";
    }

    // Volume keys go straight to pamixer, so the OSD is driven by observing
    // the node rather than by the keybind. The startup guard swallows the
    // burst of changes while Pipewire state settles.
    property bool ready: false
    Timer {
        interval: 1500
        running: true
        onTriggered: root.ready = true
    }
    onVolumeChanged: if (ready) ShellState.showOsd("volume", volume, muted)
    onMutedChanged: if (ready) ShellState.showOsd("volume", volume, muted)
}
