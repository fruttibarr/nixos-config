pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Backlight via brightnessctl. sysfs brightness files don't emit inotify
// events, so the brightness keys ping `qs ipc call island brightness` after
// changing it, which re-reads the level and shows the OSD.
Singleton {
    id: root

    property bool available: false
    property real value: 0 // 0..1
    property bool pendingOsd: false

    Process {
        id: readProc
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    // -m output: name,class,current,percent%,max
    function parse(text) {
        const line = text.trim().split("\n")[0] ?? "";
        const f = line.split(",");
        const cur = parseInt(f[2]);
        const max = parseInt(f[4]);
        if (f.length >= 5 && max > 0) {
            available = true;
            value = cur / max;
            if (pendingOsd) ShellState.showOsd("brightness", value, false);
        } else {
            available = false;
        }
        pendingOsd = false;
    }

    function refresh(withOsd) {
        pendingOsd = !!withOsd;
        readProc.running = true;
    }

    // Slider drags fire far faster than it's worth spawning processes, so
    // writes are coalesced to one per frame-ish.
    property real target: -1
    function set(v) {
        value = Math.max(0.01, Math.min(1, v));
        target = value;
        if (!writeTimer.running) writeTimer.start();
    }
    Timer {
        id: writeTimer
        interval: 40
        onTriggered: {
            if (root.target < 0) return;
            Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set",
                Math.round(root.target * 100) + "%"]);
            root.target = -1;
        }
    }

    Component.onCompleted: refresh(false)
}
