pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU / memory / temperature / uptime, polled every few seconds.
Singleton {
    id: root

    property int cpu: 0
    property int mem: 0
    property int temp: 0
    property string uptime: ""

    property real _prevTotal: 0
    property real _prevIdle: 0

    Process {
        id: statProc
        command: ["cat", "/proc/stat", "/proc/meminfo", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: tempProc
        command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -rn | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = parseInt(text.trim());
                if (!isNaN(raw)) root.temp = Math.round(raw / 1000);
            }
        }
    }

    function parse(text) {
        const lines = text.split("\n");

        const cpuLine = lines.find(l => l.startsWith("cpu "));
        if (cpuLine) {
            const f = cpuLine.trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + (f[4] ?? 0);
            const total = f.reduce((a, b) => a + b, 0);
            const dTotal = total - _prevTotal;
            const dIdle = idle - _prevIdle;
            if (_prevTotal > 0 && dTotal > 0)
                cpu = Math.round(100 * (dTotal - dIdle) / dTotal);
            _prevTotal = total;
            _prevIdle = idle;
        }

        const kb = key => parseInt(lines.find(l => l.startsWith(key))?.match(/\d+/)?.[0] ?? 0);
        const memTotal = kb("MemTotal:");
        const memAvail = kb("MemAvailable:");
        if (memTotal > 0) mem = Math.round(100 * (memTotal - memAvail) / memTotal);

        // /proc/uptime is the last file, a single "secs idle" line.
        const upLine = lines.filter(l => /^\d+\.\d+ \d+\.\d+$/.test(l.trim())).pop();
        if (upLine) {
            const s = Math.floor(parseFloat(upLine));
            const d = Math.floor(s / 86400);
            const h = Math.floor((s % 86400) / 3600);
            const m = Math.floor((s % 3600) / 60);
            uptime = d > 0 ? `${d}d ${h}h` : (h > 0 ? `${h}h ${m}m` : `${m}m`);
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statProc.running = true;
            tempProc.running = true;
        }
    }
}
