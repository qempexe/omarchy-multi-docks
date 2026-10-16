.pragma library
.import "Paint.js" as Paint
.import "Trace.js" as Trace
.import "parts/Ends.js" as Ends
.import "parts/Surfaces.js" as Surfaces
.import "parts/Lines.js" as Lines
.import "parts/Ornaments.js" as Ornaments

// How a dock's body looks: the settings for it, their options, the ready made looks,
// and the parameters Paint.js draws from. Plain functions, so they can be tested.
//
// A dock's body is one shape: its ends (parts/Ends.js), what it is made of
// (parts/Surfaces.js), its edge (parts/Lines.js) and decoration (parts/Ornaments.js).

function keysOf(mod) { var out = []; for (var i = 0; i < mod.list.length; i++) out.push(mod.list[i].key); return out; }
function labelsOf(mod) { var out = {}; for (var i = 0; i < mod.list.length; i++) out[mod.list[i].key] = mod.list[i].label; return out; }
function aboutsOf(mod) {
    var out = {};
    for (var i = 0; i < mod.list.length; i++) if (mod.list[i].about) out[mod.list[i].key] = mod.list[i].about;
    return out;
}
function keysWith(mod, flag, value) {
    var out = [];
    for (var i = 0; i < mod.list.length; i++) if (mod.list[i][flag] === value) out.push(mod.list[i].key);
    return out;
}

var ends = { options: keysOf(Ends), labels: labelsOf(Ends), abouts: aboutsOf(Ends) };
var surfaces = { options: keysOf(Surfaces), labels: labelsOf(Surfaces), abouts: aboutsOf(Surfaces) };
var lines = { options: keysOf(Lines), labels: labelsOf(Lines), abouts: aboutsOf(Lines) };
var ornaments = { options: keysOf(Ornaments), labels: labelsOf(Ornaments), abouts: aboutsOf(Ornaments) };
var pointingEnds = keysWith(Ends, "pointing", true);
var leaningSurfaces = keysWith(Surfaces, "leans", true);
var noGradient = keysWith(Surfaces, "noGradient", true);
var noTexture = keysWith(Surfaces, "noTexture", true);
var noDepth = keysWith(Surfaces, "noDepth", true);
var colorlessLines = keysWith(Lines, "usesColor", false);
var widthlessLines = keysWith(Lines, "usesWidth", false);

// every style setting: [allowed values] or [min, max] for numbers, and the default
var settings = {
    ends:        { options: ends.options, fallback: "rounded" },
    pointing:    { options: ["right", "left", "both"], fallback: "right" },
    flatSide:    { options: ["none", "edge", "windows"], fallback: "none" },
    surface:     { options: surfaces.options, fallback: "filled" },
    fill:        { options: ["solid", "gradient", "glass"], fallback: "solid" },
    gradientTo:  { options: ["accent", "lighter", "darker"], fallback: "accent" },
    gradientAcross: { bool: true, fallback: false },
    pattern:     { options: ["none", "stripes", "dots", "grid"], fallback: "none" },
    depth:       { options: ["flat", "raised", "sunken"], fallback: "flat" },
    lines:       { options: lines.options, fallback: "solid" },
    border:      { options: ["subtle", "text", "accent"], fallback: "subtle" },
    borderWidth: { range: [1, 4], fallback: 1 },
    railSide:    { options: ["windows", "edge", "both"], fallback: "windows" },
    outlineGradient: { bool: true, fallback: false },
    ornaments:   { options: ornaments.options, fallback: "none" },
    shadow:      { options: ["none", "soft", "strong"], fallback: "soft" },
    shadowColor: { options: ["dark", "accent"], fallback: "dark" }
};
var keys = [];
for (var sk in settings) keys.push(sk);

function defaults() {
    var out = {};
    for (var i = 0; i < keys.length; i++) out[keys[i]] = settings[keys[i]].fallback;
    return out;
}

// one value, checked
function cleanValue(key, v) {
    var s = settings[key];
    if (!s) return undefined;
    if (s.bool) return v === true || v === "true";
    if (s.range) {
        var n = typeof v === "number" ? v : parseFloat(v);
        return isFinite(n) ? Math.max(s.range[0], Math.min(s.range[1], Math.round(n))) : s.fallback;
    }
    return typeof v === "string" && s.options.indexOf(v) !== -1 ? v : s.fallback;
}

// the style keys of a dock, each checked. `outline: true` from older configs becomes
// an accent line, so a dock looks the same after an update
function clean(d) {
    var out = {};
    var had = d && typeof d === "object";
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        out[k] = cleanValue(k, had ? d[k] : undefined);
    }
    if (had && d.outline === true && d.border === undefined) out.border = "accent";
    // Scroll ends were round ends with the Scrolls ornament's curls: they are that now
    if (had && d.ends === "scroll") {
        out.ends = "capsule";
        if (d.ornaments === undefined || d.ornaments === "none") out.ornaments = "scrolls";
    }
    return out;
}

// ---- ready made looks ------------------------------------------------------------------
// Each sets every style key it names; the rest go back to their defaults, so nothing from
// the previous look lingers. Colors, opacity, size and placement stay as they are.

var looks = [
    { key: "plain",    label: "Plain",    set: {} },
    { key: "glass",    label: "Glass",    set: { ends: "capsule", surface: "frost", fill: "glass", lines: "solid", border: "subtle" } },
    { key: "outline",  label: "Outline",  set: { surface: "faint", lines: "solid", border: "accent", shadow: "none" } },
    { key: "neon",     label: "Neon",     set: { ends: "capsule", surface: "faint", lines: "neon", shadow: "none" } },
    { key: "metal",    label: "Metal",    set: { ends: "chamfer", surface: "metal", lines: "solid", ornaments: "rivets", shadow: "strong" } },
    { key: "arcade",   label: "Arcade",   set: { ends: "castle", surface: "crt", lines: "solid", border: "accent", shadow: "none" } },
    { key: "paper",    label: "Paper",    set: { ends: "folded", surface: "filled", lines: "sketch", border: "text", shadow: "soft" } },
    { key: "workshop", label: "Workshop", set: { surface: "wood", lines: "stitched", border: "text", ornaments: "studs", shadow: "strong" } },
    { key: "saddle",   label: "Saddle",   set: { surface: "leather", lines: "stitched", border: "accent", ornaments: "rivets" } },
    { key: "ribbon",   label: "Ribbon",   set: { ends: "ribbon", surface: "twotone", lines: "solid", border: "accent" } },
    { key: "arrows",   label: "Arrows",   set: { ends: "arrow", pointing: "both", lines: "solid", border: "accent", shadow: "soft" } },
    { key: "deco",     label: "Deco",     set: { ends: "plaque", surface: "filled", lines: "double", border: "accent", ornaments: "deco" } },
    { key: "salon",    label: "Salon",    set: { ends: "cartouche", surface: "velvet", lines: "gilded", ornaments: "rosettes", shadow: "strong" } },
    { key: "palace",   label: "Palace",   set: { ends: "dome", surface: "damask", lines: "gilded", ornaments: "crown", shadow: "strong" } },
    { key: "chapel",   label: "Chapel",   set: { ends: "fleur", surface: "stained", lines: "gilded", ornaments: "filigree" } },
    { key: "nebula",   label: "Nebula",   set: { ends: "capsule", surface: "nebula", lines: "glow", border: "accent", ornaments: "stars", shadow: "none" } }
];
var lookByKey = {}, lookKeys = [], lookLabels = {};
for (var li = 0; li < looks.length; li++) {
    lookByKey[looks[li].key] = looks[li];
    lookKeys.push(looks[li].key);
    lookLabels[looks[li].key] = looks[li].label;
}

// a whole look: every style key, from the defaults and the look's own settings
function lookSet(key) {
    var L = lookByKey[key];
    if (!L) return null;
    var out = defaults();
    for (var k in L.set) out[k] = cleanValue(k, L.set[k]);
    return out;
}
// the look a dock is wearing right now, or ""
function lookOf(d) {
    for (var i = 0; i < looks.length; i++) {
        var want = lookSet(looks[i].key), same = true;
        for (var j = 0; j < keys.length; j++) if (d[keys[j]] !== want[keys[j]]) { same = false; break; }
        if (same) return looks[i].key;
    }
    return "";
}
// just the style part of a dock (for undo)
function styleOf(d) {
    var out = {};
    for (var i = 0; i < keys.length; i++) out[keys[i]] = d[keys[i]];
    return out;
}

// ---- colors ----------------------------------------------------------------------------

function rgb(c) {
    if (c && typeof c === "object" && typeof c.r === "number") return [c.r * 255, c.g * 255, c.b * 255];
    var h = typeof c === "string" ? c : "";
    if (!/^#[0-9a-fA-F]{6}$/.test(h)) return [128, 128, 128];
    return [parseInt(h.substr(1, 2), 16), parseInt(h.substr(3, 2), 16), parseInt(h.substr(5, 2), 16)];
}
function mix(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }
function css(c, a) {
    var al = typeof a === "number" ? Math.max(0, Math.min(1, a)) : 1;
    return "rgba(" + Math.round(c[0]) + "," + Math.round(c[1]) + "," + Math.round(c[2]) + "," + al + ")";
}
function lum(c) { return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255; }

// ---- where the dock is -----------------------------------------------------------------

// which side of the shape faces the windows, in the painter's terms (start = its top
// before the flip for side docks)
function innerFor(edge) { return edge === "bottom" || edge === "right" ? "start" : "end"; }
function isVertical(edge) { return edge === "left" || edge === "right"; }

// how much room the canvas leaves around the shape, for shadows, glows and ornaments
function marginFor(d) {
    var Ln = Lines.byKey[d.lines] || {};
    var S = Surfaces.byKey[d.surface] || {};
    if (d.shadow === "strong") return 16;
    if (d.shadow === "soft" || Ln.glow === true || S.ownShadow === true) return 11;
    return 3;
}

// the corner radius the painter gets: capsule ends are fully round, rounded ends use
// the Corner radius setting, every other end draws its own corners
function radiusOf(d) {
    if (d.ends === "capsule") return 999;
    if (d.ends === "rounded") return typeof d.radius === "number" ? d.radius : 16;
    return 0;
}

// ---- the parameters Paint.js draws from ------------------------------------------------
//
// d: the dock's settings, pal: { bg, fg, ac, hot } as "#rrggbb", w/h: the canvas,
// margin: room around the shape, opts: { edge, tone (accent override) }

function params(d, pal, w, h, margin, opts) {
    var o = opts || {};
    var edge = o.edge || "bottom";
    var opacity = typeof d.opacity === "number" ? d.opacity : 90;
    var base = rgb(pal.bg), fg = rgb(pal.fg), mine = rgb(o.tone || pal.ac);
    var S = Surfaces.byKey[d.surface] || Surfaces.byKey.filled;
    var k = typeof S.fill === "number" ? S.fill : 1;
    if (d.fill === "glass") k *= 0.55;
    var alpha = k * opacity / 100;
    var target = d.gradientTo === "lighter" ? mix(base, [255, 255, 255], 0.2)
               : d.gradientTo === "darker" ? mix(base, [0, 0, 0], 0.35)
               : mix(base, mine, 0.45);
    var Ln = Lines.byKey[d.lines] || Lines.byKey.none;
    var lw = 0, lineBase = mine, lineAlpha = 0.85;
    if (Ln.usesColor !== false) {
        lw = d.borderWidth;
        if (d.border === "text") { lineBase = fg; lineAlpha = 0.55; }
        else if (d.border === "subtle") { lineBase = fg; lineAlpha = 0.16; }
    }
    var lineColor = Ln.usesColor !== false ? css(lineBase, lineAlpha) : "";
    var grad = d.outlineGradient === true;
    var lineGrad = grad && lw > 0 ? [css(lineBase, lineAlpha), css(mix(lineBase, [255, 255, 255], 0.55), Math.max(lineAlpha, 0.6))] : [];
    var markGrad = grad ? [css(mine, 0.9), css(mix(mine, [255, 255, 255], 0.55), 0.9)] : [];

    var blur = 0, shadow = "";
    if (d.shadow !== "none") {
        if (d.shadowColor === "accent") { blur = d.shadow === "strong" ? 14 : 8; shadow = css(mine, d.shadow === "strong" ? 0.8 : 0.55); }
        else { blur = d.shadow === "strong" ? 14 : 8; shadow = css([0, 0, 0], d.shadow === "strong" ? 0.55 : 0.35); }
    }
    if (Ln.glow === true && blur === 0) { blur = 8; shadow = css(mine, 0.5); }
    if (S.ownShadow === true && blur === 0) { blur = 10; shadow = css([0, 0, 0], 0.5); }
    blur = Math.min(blur, Math.max(0, margin - 2));

    var inner = innerFor(edge);
    var edgeSide = inner === "start" ? "end" : "start";
    var flat = d.flatSide === "edge" ? edgeSide : (d.flatSide === "windows" ? inner : "");
    var lightBase = lum(base) > 0.6;
    var dense = S.noDepth !== true;
    return {
        width: w, height: h, margin: margin, vertical: isVertical(edge),
        dir: d.pointing === "left" || d.pointing === "both" ? d.pointing : "right",
        flat: flat,
        pattern: dense && d.pattern !== "none" ? d.pattern : "", patternColor: css(fg, 0.07),
        depth: dense && d.depth !== "flat" ? d.depth : "",
        light: lightBase ? css([255, 255, 255], 0.7) : css([255, 255, 255], 0.16),
        dark: lightBase ? css([0, 0, 0], 0.18) : css([0, 0, 0], 0.35),
        r: radiusOf(d), ends: d.ends,
        edge: "", concave: false, inner: inner,
        surface: d.surface, lines: d.lines, ornament: d.ornaments,
        fill: css(base, alpha),
        fill2: d.fill === "gradient" && S.noGradient !== true ? css(target, alpha) : "",
        gradAcross: d.gradientAcross === true,
        glass: d.fill === "glass" && S.noGradient !== true,
        glassColor: lightBase ? css([255, 255, 255], 0.8) : css(fg, 0.22),
        line: lineColor, lineWidth: lw, lineGrad: lineGrad, markGrad: markGrad, lineAngle: 0,
        mark: css(mine, 0.9), markWidth: Math.max(1, d.borderWidth), bracket: 7,
        second: css(mix(base, mine, 0.28), alpha),
        splitColor: css(mix(base, mine, 0.5), alpha),
        frameColors: [css(mix(mine, [255, 255, 255], 0.55)), css(mine), css(mix(mine, [0, 0, 0], 0.45)), css(mix(mine, [255, 255, 255], 0.3))],
        velvetSheen: css(mix(base, lightBase ? [255, 255, 255] : mine, lightBase ? 0.35 : 0.3), alpha),
        head: css(mix(base, mine, 0.7), Math.max(alpha, 0.85)),
        metal: [css(mix(base, [255, 255, 255], lightBase ? 0.5 : 0.22), alpha), css(base, alpha),
                css(mix(base, [0, 0, 0], lightBase ? 0.12 : 0.3), alpha), css(mix(base, [255, 255, 255], lightBase ? 0.25 : 0.1), alpha)],
        frost: css(lightBase ? [255, 255, 255] : mix(base, [255, 255, 255], 0.35), lightBase ? 0.55 : 0.32 * opacity / 100),
        key: css(lightBase ? mix(base, [0, 0, 0], 0.4) : mix(base, mine, 0.55), Math.max(alpha, 0.6)),
        railSide: d.railSide,
        shadow: shadow, shadowBlur: blur, shadowShift: 0
    };
}

// ---- room for the icons ------------------------------------------------------------------
//
// Pointed, notched and curled ends reach into the dock. This measures how far, on the
// shape's real outline, across the band the icons sit in, so the first and last icon
// never touch the end. Remembered per kind of end and thickness.
var roomCache = {};
// ornaments that sit inside each end (Scrolls, Crown, Laurels), as a share of the thickness
var ORNAMENT_ROOM = { scrolls: 0.62, crown: 0.72, laurels: 0.55 };
function endRoom(d, thick, band) {
    var e = Ends.byKey[d.ends];
    var curls = typeof ORNAMENT_ROOM[d.ornaments] === "number";
    if (!e || ((d.ends === "rounded" || d.ends === "square") && !curls)) return 0;
    var r = Math.min(radiusOf(d), thick / 2);
    var dir = d.pointing === "left" || d.pointing === "both" ? d.pointing : "right";
    var key = d.ends + "|" + dir + "|" + Math.round(thick) + "|" + Math.round(band) + "|" + r + "|" + d.ornaments;
    if (roomCache[key] !== undefined) return roomCache[key];
    var L = 600, T = thick;
    var tr = Trace.trace(function (c) { Paint.outline(c, 0, 0, L, T, r, d.ends, "", "", dir, "end"); });
    var pts = tr.pts, worst = 0;
    for (var row = 0; row <= 12; row++) {
        var v = band + (T - 2 * band) * row / 12, xs = [];
        for (var i = 0; i < pts.length; i++) {
            var p = pts[i], q = pts[(i + 1) % pts.length];
            if ((p[1] <= v && q[1] > v) || (q[1] <= v && p[1] > v)) xs.push(p[0] + (q[0] - p[0]) * (v - p[1]) / (q[1] - p[1]));
        }
        xs.sort(function (a, b) { return a - b; });
        for (var j = 0; j + 1 < xs.length; j += 2) {
            if (xs[j] <= L / 2 && xs[j + 1] >= L / 2) worst = Math.max(worst, xs[j], L - xs[j + 1]);
        }
    }
    // ornaments that sit inside each end
    if (curls) worst = Math.max(worst, T * ORNAMENT_ROOM[d.ornaments]);
    var out = Math.ceil(worst > 0.5 ? worst + 2 : 0);
    roomCache[key] = out;
    return out;
}
