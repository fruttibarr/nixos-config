pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper library: scanning, thumbnails, current/recent, applying.
//
// The library is large (thousands of multi-megapixel images), so:
//  - the scan is one `find`, done lazily on first use;
//  - thumbnails are generated on demand by a small pool of `magick`
//    workers and cached by md5(path) — the grid only asks for what's
//    on screen, and cancels requests that scroll away before starting.
Singleton {
    id: svc

    readonly property string root: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string thumbDir: Quickshell.cacheDir + "/wallthumbs"

    property string current: ""
    property var all: []            // abs paths, sorted
    property var collections: []    // [{ name, label, path, count }]
    property var recent: []         // abs paths, most recent first
    property bool loading: false
    property bool missing: false    // root folder absent or holds no images
    property string applying: ""

    signal thumbReady(string path)

    // Lower-cased paths relative to root, index-aligned with `all`, so
    // search is one cheap pass with no per-keystroke allocation.
    property var allLower: []

    // ---- current ------------------------------------------------------------
    FileView {
        id: currentFile
        path: Quickshell.env("HOME") + "/.cache/current-wallpaper"
        watchChanges: true
        printErrors: false
        onLoaded: svc.current = text().trim()
        onFileChanged: reload()
    }

    // Anything that changes the wallpaper (this picker, SUPER+W, the CLI)
    // goes through the cache file, so recent tracks all of them.
    onCurrentChanged: if (current !== "") pushRecent(current)

    // ---- recent -------------------------------------------------------------
    FileView {
        id: recentFile
        path: Quickshell.stateDir + "/wallpaper-recent.json"
        printErrors: false
        onLoaded: {
            try {
                const r = JSON.parse(text());
                if (Array.isArray(r)) svc.recent = r.filter(p => typeof p === "string");
            } catch (e) {}
            if (svc.current !== "") svc.pushRecent(svc.current);
        }
    }

    function pushRecent(path) {
        if (recent[0] === path) return;
        recent = [path, ...recent.filter(p => p !== path)].slice(0, 24);
        recentFile.setText(JSON.stringify(recent));
    }

    // ---- scan ---------------------------------------------------------------
    Process {
        id: scanProc
        command: ["find", svc.root, "-type", "f", "(",
            "-iname", "*.jpg", "-o", "-iname", "*.jpeg",
            "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: svc._ingest(text)
        }
    }

    function refresh() {
        if (scanProc.running) return;
        loading = true;
        lsProc.running = true;
        scanProc.running = true;
    }

    function _prettify(name) {
        return name.replace(/[-_]+/g, " ")
            .replace(/\b([a-z])/g, (m, c) => c.toUpperCase());
    }

    function _ingest(text) {
        const paths = text.split("\n").filter(p => p.length > 0).sort();
        const prefixLen = svc.root.length + 1;
        const lower = new Array(paths.length);
        const dirs = {};
        for (let i = 0; i < paths.length; i++) {
            const p = paths[i];
            lower[i] = p.slice(prefixLen).toLowerCase();
            const d = p.slice(0, p.lastIndexOf("/"));
            dirs[d] = (dirs[d] ?? 0) + 1;
        }
        const cols = Object.keys(dirs).sort().map(d => {
            const name = d.slice(d.lastIndexOf("/") + 1);
            return {
                name: name,
                label: d === svc.root ? "Unsorted" : _prettify(name),
                path: d,
                count: dirs[d]
            };
        });
        allLower = lower;
        all = paths;
        collections = cols;
        missing = paths.length === 0;
        loading = false;
    }

    // ---- thumbnails ---------------------------------------------------------
    // Thumbnail file names already on disk (filled by one `ls` per refresh).
    // Plain JS object, not a bound property: lookups happen inside delegate
    // bindings and must not make every delegate depend on it.
    property var _known: ({})
    property bool _listed: false
    property var _queue: []
    property var _queued: ({})
    readonly property int _maxWorkers: 4

    Process {
        id: lsProc
        command: ["sh", "-c", "mkdir -p \"$1\" && ls -1 \"$1\"", "sh", svc.thumbDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const k = {};
                for (const f of text.split("\n")) if (f.endsWith(".jpg")) k[f] = true;
                svc._known = k;
                svc._listed = true;
                svc._pump();
            }
        }
    }

    function _key(path) {
        return Qt.md5(path) + ".jpg";
    }

    function thumb(path) {
        if (!path) return "";
        const key = _key(path);
        if (_known[key]) return "file://" + thumbDir + "/" + key;
        if (!_queued[path]) {
            _queued[path] = true;
            _queue.push(path);
            if (!_listed && !lsProc.running) lsProc.running = true;
            // Deferred: thumb() is called from delegate bindings, and pumping
            // can emit thumbReady, which would re-enter those bindings.
            Qt.callLater(_pump);
        }
        return "";
    }

    // Drop a request that hasn't started yet (its card scrolled away).
    function cancel(path) {
        if (!_queued[path]) return;
        const i = _queue.indexOf(path);
        if (i >= 0) {
            _queue.splice(i, 1);
            delete _queued[path];
        }
    }

    component Worker: Process {
        id: w
        property string src: ""
        property string dst: ""
        command: ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\" && "
            + "magick -define jpeg:size=800x500 \"$1[0]\" -auto-orient "
            + "-thumbnail '400x250^' -gravity center -extent 400x250 "
            + "-strip -quality 80 \"jpg:$2.tmp\" && mv \"$2.tmp\" \"$2\"",
            "sh", w.src, w.dst]
        // Inline components can't see the file's ids, so report via signal.
        signal done(var worker, int code)
        onExited: code => w.done(w, code)
    }

    property list<Process> _workers: [
        Worker { onDone: (w, c) => svc._finished(w, c) },
        Worker { onDone: (w, c) => svc._finished(w, c) },
        Worker { onDone: (w, c) => svc._finished(w, c) },
        Worker { onDone: (w, c) => svc._finished(w, c) }
    ]

    function _pump() {
        if (!_listed) return;
        for (const w of _workers) {
            if (w.running || w.src !== "") continue;
            let path = null;
            while (_queue.length) {
                const p = _queue.shift();
                if (_known[_key(p)]) {
                    // Already cached (queued before the listing arrived).
                    delete _queued[p];
                    thumbReady(p);
                    continue;
                }
                path = p;
                break;
            }
            if (path === null) return;
            w.src = path;
            w.dst = thumbDir + "/" + _key(path);
            w.running = true;
        }
    }

    function _finished(w, code) {
        const path = w.src;
        w.src = "";
        delete _queued[path];
        if (code === 0) {
            _known[_key(path)] = true;
            thumbReady(path);
        }
        // Defer so the finished Process fully resets before reuse.
        Qt.callLater(_pump);
    }

    // ---- applying -----------------------------------------------------------
    property string _pending: ""

    Process {
        id: applyProc
        property string target: ""
        command: ["set-wallpaper", target]
        onExited: code => {
            svc.applying = "";
            if (svc._pending !== "") {
                const next = svc._pending;
                svc._pending = "";
                Qt.callLater(() => svc.apply(next));
            }
        }
    }

    function apply(path) {
        if (!path) return;
        if (applyProc.running) {
            // Latest request wins; it runs as soon as the current one ends.
            _pending = path;
            return;
        }
        applying = path;
        applyProc.target = path;
        applyProc.running = true;
    }

    function random() {
        if (all.length === 0) return;
        let p = all[Math.floor(Math.random() * all.length)];
        if (p === current && all.length > 1) p = all[(all.indexOf(p) + 1) % all.length];
        apply(p);
    }
}
