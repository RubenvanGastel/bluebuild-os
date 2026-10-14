.pragma library

// Seeded PRNG (mulberry32). Every surface that draws the scene builds the exact same
// debris from the same seeds, which keeps the wallpaper and lock screen identical.
function make(seed) {
    let a = seed >>> 0;
    return function () {
        a = (a + 0x6D2B79F5) | 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

function mix(a, b, f) {
    return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, a.a + (b.a - a.a) * f);
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}
