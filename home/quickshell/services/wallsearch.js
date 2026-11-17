.pragma library

// Smart search for the wallpaper picker. Pure functions, no QML, so it can be
// tested on its own.
//
// A query is split into words. Every word has to match the wallpaper, either:
//  - by NAME (file or folder): substring, word-start, or a word within one or
//    two typos ("outrn" -> "outrun", "forrest" -> "forest"), or
//  - by LOOK, from the colour index (wallpaper-colors): colour words ("blue",
//    "navy", "gold"), and moods ("dark", "bright", "warm", "pastel", "neon"...).
// Results are ranked by the summed score of their words, so "dark blue"
// puts the darkest, bluest images first.

// ---- colour index ----------------------------------------------------------

// "1433:#2A1F18 74:#3D463D ..." ->
//   { c: {bucket: share}, a: {bucket: share of vivid pixels}, lum, sat, warm }
// `a` lets a small but vivid accent (neon signs on a dark scene) count: the
// eye notices it far more than its pixel share suggests.
function features(hist) {
    const c = {};
    const a = {};
    let total = 0, lum = 0, sat = 0, warm = 0;
    const parts = hist.split(" ");
    const cols = [];
    for (const part of parts) {
        const k = part.indexOf(":#");
        if (k < 0) continue;
        const n = parseInt(part.slice(0, k), 10);
        const hex = part.slice(k + 2);
        if (!(n > 0) || hex.length < 6) continue;
        cols.push([n, parseInt(hex.slice(0, 2), 16) / 255, parseInt(hex.slice(2, 4), 16) / 255, parseInt(hex.slice(4, 6), 16) / 255]);
        total += n;
    }
    if (total === 0) return null;

    for (const [n, r, g, b] of cols) {
        const w = n / total;
        const max = Math.max(r, g, b), min = Math.min(r, g, b);
        const l = (max + min) / 2;
        const chroma = max - min;
        const s = chroma === 0 ? 0 : chroma / (1 - Math.abs(2 * l - 1));
        let h = 0;
        if (chroma > 0) {
            if (max === r) h = 60 * (((g - b) / chroma) % 6);
            else if (max === g) h = 60 * ((b - r) / chroma + 2);
            else h = 60 * ((r - g) / chroma + 4);
            if (h < 0) h += 360;
        }

        lum += w * (0.2126 * r + 0.7152 * g + 0.0722 * b);
        sat += w * chroma;

        const add = (k, v) => {
            c[k] = (c[k] ?? 0) + v;
            if (chroma >= 0.25) a[k] = (a[k] ?? 0) + v;
        };
        if (l < 0.11) { add("black", w); continue; }
        // Low chroma is grey, unless it's a clearly tinted dark (a navy like
        // #1B1C29 has little chroma in absolute terms but reads as blue).
        if (chroma < 0.09 && !(s >= 0.18 && chroma >= 0.035)) {
            if (l > 0.82) add("white", w);
            else add("grey", w);
            if (l < 0.25) add("black", w * 0.5);
            continue;
        }
        // Colourful: warm/cool lean, weighted by how colourful it is.
        if (h < 70 || h >= 330) warm += w * chroma;
        else if (h >= 160 && h < 290) warm -= w * chroma;

        if (h < 14 || h >= 345) add(l > 0.68 ? "pink" : "red", w);
        else if (h < 45) add(l < 0.33 || (s < 0.45 && l < 0.5) ? "brown" : "orange", w);
        else if (h < 70) add(l < 0.3 ? "brown" : "yellow", w);
        else if (h < 165) add("green", w);
        else if (h < 198) add("teal", w);
        else if (h < 255) add("blue", w);
        else if (h < 290) add("purple", w);
        else add(l < 0.3 && h < 315 ? "purple" : "pink", w);
    }
    return { c: c, a: a, lum: lum, sat: sat, warm: warm };
}

// Parses the whole index file -> { relPath: features }.
function parseIndex(text) {
    const out = {};
    let start = 0;
    while (start < text.length) {
        let end = text.indexOf("\n", start);
        if (end < 0) end = text.length;
        const tab = text.indexOf("\t", start);
        if (tab > start && tab < end) {
            const f = features(text.slice(tab + 1, end));
            if (f) out[text.slice(start, tab)] = f;
        }
        start = end + 1;
    }
    return out;
}

// ---- look words ---------------------------------------------------------------

// word -> colour bucket(s)
const COLOURS = {
    red: ["red"], crimson: ["red"], scarlet: ["red"], maroon: ["red"], ruby: ["red"],
    orange: ["orange"], amber: ["orange"], peach: ["orange", "pink"], copper: ["orange", "brown"],
    yellow: ["yellow"], gold: ["yellow"], golden: ["yellow"],
    green: ["green"], lime: ["green"], olive: ["green"], emerald: ["green"], mint: ["green", "teal"],
    teal: ["teal"], cyan: ["teal"], aqua: ["teal"], turquoise: ["teal"],
    blue: ["blue"], navy: ["blue"], azure: ["blue"], cobalt: ["blue"],
    purple: ["purple"], violet: ["purple"], lavender: ["purple"], indigo: ["purple", "blue"], lilac: ["purple"],
    pink: ["pink"], magenta: ["pink"], rose: ["pink"], fuchsia: ["pink"], salmon: ["pink"],
    brown: ["brown"], tan: ["brown"], beige: ["brown", "white"], sepia: ["brown"],
    black: ["black"],
    white: ["white"],
    grey: ["grey"], gray: ["grey"], silver: ["grey"]
};

// word -> (features) => 0..1 strength, 0 = no match
const MOODS = {
    dark: f => f.lum < 0.3 ? 1 - f.lum / 0.3 * 0.6 : 0,
    night: f => f.lum < 0.22 ? 1 - f.lum / 0.22 * 0.6 : 0,
    dim: f => f.lum < 0.3 ? 0.7 : 0,
    moody: f => f.lum < 0.3 && f.sat < 0.35 ? 0.8 : 0,
    bright: f => f.lum > 0.55 ? 0.4 + (f.lum - 0.55) : 0,
    light: f => f.lum > 0.55 ? 0.4 + (f.lum - 0.55) : 0,
    vibrant: f => f.sat > 0.4 ? f.sat : 0,
    vivid: f => f.sat > 0.4 ? f.sat : 0,
    colorful: f => f.sat > 0.4 ? f.sat : 0,
    colourful: f => f.sat > 0.4 ? f.sat : 0,
    saturated: f => f.sat > 0.4 ? f.sat : 0,
    // Vivid pink/purple/cyan/blue/green on a dark scene.
    neon: f => {
        const v = ["pink", "purple", "teal", "blue", "green"].reduce((s, k) => s + (f.a[k] ?? 0), 0);
        return f.lum < 0.4 && v >= 0.1 ? Math.min(1, 0.4 + v) : 0;
    },
    muted: f => f.sat < 0.2 && f.sat > 0.04 ? 0.8 : 0,
    pastel: f => f.lum > 0.5 && f.sat > 0.08 && f.sat < 0.35 ? 0.8 : 0,
    monochrome: f => f.sat < 0.06 ? 1 : 0,
    mono: f => f.sat < 0.06 ? 1 : 0,
    grayscale: f => f.sat < 0.06 ? 1 : 0,
    greyscale: f => f.sat < 0.06 ? 1 : 0,
    bw: f => f.sat < 0.06 ? 1 : 0,
    warm: f => f.warm > 0.08 ? Math.min(1, f.warm * 3) : 0,
    cool: f => f.warm < -0.08 ? Math.min(1, -f.warm * 3) : 0,
    cold: f => f.warm < -0.08 ? Math.min(1, -f.warm * 3) : 0
};
// Modifiers that read as part of a colour ("dark blue", "light pink") also
// work on their own via MOODS.

function isLookWord(t) {
    return COLOURS[t] !== undefined || MOODS[t] !== undefined;
}

function lookScore(t, f) {
    if (!f) return 0;
    const buckets = COLOURS[t];
    if (buckets) {
        let w = 0;
        for (const b of buckets) w += (f.c[b] ?? 0) + 1.5 * (f.a[b] ?? 0);
        // At least ~15% of the picture (vivid pixels counting extra), so a
        // stray pixel doesn't count.
        return w >= 0.15 ? 40 + 100 * Math.min(1, w) : 0;
    }
    const m = MOODS[t];
    if (m) {
        const v = m(f);
        return v > 0 ? 40 + 60 * Math.min(1, v) : 0;
    }
    return 0;
}

// ---- names --------------------------------------------------------------------

function words(rel) {
    return rel.split(/[^a-z0-9]+/).filter(w => w.length > 0);
}

// Optimal-string-alignment distance, giving up once it exceeds `max`.
function editDistance(a, b, max) {
    if (Math.abs(a.length - b.length) > max) return max + 1;
    let prev2 = null;
    let prev = new Array(b.length + 1);
    for (let j = 0; j <= b.length; j++) prev[j] = j;
    for (let i = 1; i <= a.length; i++) {
        const cur = new Array(b.length + 1);
        cur[0] = i;
        let rowMin = cur[0];
        for (let j = 1; j <= b.length; j++) {
            const cost = a[i - 1] === b[j - 1] ? 0 : 1;
            let v = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost);
            if (prev2 && i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1])
                v = Math.min(v, prev2[j - 2] + 1);
            cur[j] = v;
            if (v < rowMin) rowMin = v;
        }
        if (rowMin > max) return max + 1;
        prev2 = prev;
        prev = cur;
    }
    return prev[b.length];
}

// rel: lower-cased relative path; ws: its words.
function nameScore(t, rel, ws) {
    const at = rel.indexOf(t);
    if (at >= 0) {
        const wordStart = at === 0 || /[^a-z0-9]/.test(rel[at - 1]);
        // Hits in the file name beat hits in the folder name.
        const inFile = at > rel.lastIndexOf("/");
        return 100 + (wordStart ? 25 : 0) + (inFile ? 10 : 0);
    }
    if (t.length < 4) return 0;
    const max = t.length >= 7 ? 2 : 1;
    let best = max + 1;
    for (const w of ws) {
        if (w.length < 3) continue;
        // Whole word, or the start of a run-together word ("cozzy" ~ "cozypixels").
        let d = editDistance(t, w, max);
        if (d > max && w.length > t.length)
            d = Math.min(editDistance(t, w.slice(0, t.length), max),
                         editDistance(t, w.slice(0, t.length + 1), max));
        if (d < best) best = d;
        if (best === 1 && max === 1) break;
    }
    return best <= max ? 70 - 20 * best : 0;
}

// ---- query ------------------------------------------------------------------------

function tokens(q) {
    return q.toLowerCase().split(/[\s,]+/).filter(t => t.length > 0);
}

function tokenScore(t, rel, ws, f) {
    if (isLookWord(t)) {
        // Colour/mood words are judged on the picture. Having the word in
        // the name is a bonus, or a weak match on its own, so "warm" finds
        // warm images rather than "warmachine2", and "nyarch-dark" (a light
        // lavender) can't outrank actually dark images for "dark".
        // A mood word in a name ("neon_car", "pastel-city") is usually a
        // deliberate description, so it counts for more than a colour word.
        const look = lookScore(t, f);
        const named = ws.indexOf(t) >= 0;
        const mood = MOODS[t] !== undefined;
        if (look > 0) return look + (named ? (mood ? 40 : 30) : 0);
        return named ? (mood ? 90 : 70) : 0;
    }
    return nameScore(t, rel, ws);
}

// Score of one wallpaper for the query tokens; 0 = excluded.
function score(toks, rel, ws, f) {
    let total = 0;
    for (const t of toks) {
        const s = tokenScore(t, rel, ws, f);
        if (s === 0) return 0;
        total += s;
    }
    return total;
}

// Suggestions shown under an empty search box.
const EXAMPLES = ["dark blue", "pink", "warm", "pastel", "neon", "green forest", "monochrome"];
