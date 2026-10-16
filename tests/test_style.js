// node tests/test_style.js
const fs = require("fs"), path = require("path"), assert = require("assert")
// loads a QML JavaScript library: .pragma and .import lines out, its imports passed in
const cache = {}
function load(file) {
  if (cache[file]) return cache[file]
  const src = fs.readFileSync(path.join(__dirname, "../qml/js", file), "utf8")
  const deps = [...src.matchAll(/^\.import "(.+)" as (\w+)$/mg)].map(m => [path.normalize(path.join(path.dirname(file), m[1])), m[2]])
  const body = src.replace(".pragma library", "").replace(/^\.import .*$/mg, "")
  const names = [...new Set([...body.matchAll(/^(?:function|var) (\w+)/mg)].map(m => m[1]))]
  const mod = new Function(...deps.map(d => d[1]), body + "; return {" + names.join(",") + "};")(...deps.map(d => load(d[0])))
  return (cache[file] = mod)
}
const Style = load("Style.js"), Paint = load("Paint.js"), Trace = load("Trace.js")
let n = 0
function t(name, fn) { fn(); n++; console.log("  ok   " + name) }
function fakeCtx() {
  const calls = []
  const rec = name => (...a) => { for (const v of a) if (typeof v === "number" && !isFinite(v)) throw new Error(name + " got " + v); calls.push(name) }
  const grad = () => ({ addColorStop: rec("stop") })
  const ctx = { calls, createLinearGradient: (...a) => { rec("linear")(...a); return grad() }, createRadialGradient: (...a) => { rec("radial")(...a); return grad() } }
  for (const k of ["reset", "save", "restore", "translate", "transform", "setTransform", "rotate", "scale", "beginPath", "moveTo", "lineTo",
                   "arcTo", "arc", "rect", "ellipse", "quadraticCurveTo", "bezierCurveTo", "closePath", "fill", "stroke", "clip", "fillRect",
                   "roundedRect"]) ctx[k] = rec(k)
  return ctx
}
const PAL = { bg: "#1d1510", fg: "#eadbc8", ac: "#c8925a", hot: "#d27a52" }

t("defaults and cleaning", () => {
  const d = Style.defaults()
  for (const k of Style.keys) assert.ok(k in d, k)
  const c = Style.clean({ ends: "nope", borderWidth: "9", lines: "chain", gradientAcross: "true", evil: 1 })
  assert.strictEqual(c.ends, "rounded"); assert.strictEqual(c.borderWidth, 4); assert.strictEqual(c.lines, "chain")
  assert.strictEqual(c.gradientAcross, true); assert.ok(!("evil" in c))
  // an older config with the outline switch on keeps its accent edge
  assert.strictEqual(Style.clean({ outline: true }).border, "accent")
  assert.strictEqual(Style.clean({ outline: true, border: "text" }).border, "text")
  assert.strictEqual(Style.clean(undefined).ends, "rounded")
  // Scroll ends are gone: round ends with the Scrolls ornament look the same
  assert.ok(Style.settings.ends.options.indexOf("scroll") < 0)
  const sc = Style.clean({ ends: "scroll" })
  assert.strictEqual(sc.ends, "capsule"); assert.strictEqual(sc.ornaments, "scrolls")
  assert.strictEqual(Style.clean({ ends: "scroll", ornaments: "studs" }).ornaments, "studs")
})
t("every look only uses real values, and is recognised", () => {
  assert.ok(Style.looks.length >= 12)
  for (const L of Style.looks) {
    for (const k in L.set) assert.strictEqual(Style.cleanValue(k, L.set[k]), L.set[k], L.key + "." + k)
    const d = Object.assign({ opacity: 90, radius: 16 }, Style.lookSet(L.key))
    assert.strictEqual(Style.lookOf(d), L.key)
  }
  assert.strictEqual(Style.lookSet("nope"), null)
})
t("every end, surface, line and ornament paints on every edge", () => {
  let k = 0
  const opts = Style.settings
  for (const ends of opts.ends.options) for (const edge of ["bottom", "top", "left", "right"]) {
    const d = Object.assign(Style.defaults(), { opacity: 90, radius: 16, ends,
      surface: opts.surface.options[k % opts.surface.options.length],
      lines: opts.lines.options[k % opts.lines.options.length],
      ornaments: opts.ornaments.options[k % opts.ornaments.options.length],
      fill: ["solid", "gradient", "glass"][k % 3], pattern: ["none", "stripes", "dots", "grid"][k % 4],
      depth: ["flat", "raised", "sunken"][k % 3], shadow: ["none", "soft", "strong"][k % 3],
      pointing: ["right", "left", "both"][k % 3], flatSide: ["none", "edge", "windows"][k % 3] })
    k++
    const m = Style.marginFor(d)
    const vert = edge === "left" || edge === "right"
    const ctx = fakeCtx()
    Paint.paint(ctx, Style.params(d, PAL, vert ? 72 + 2 * m : 400 + 2 * m, vert ? 400 + 2 * m : 72 + 2 * m, m, { edge }))
    assert.ok(ctx.calls.length > 3, ends + " " + edge)
  }
  for (const l of opts.lines.options) for (const o of opts.ornaments.options) {
    const d = Object.assign(Style.defaults(), { opacity: 90, radius: 16, lines: l, ornaments: o })
    Paint.paint(fakeCtx(), Style.params(d, PAL, 300, 90, 11, { edge: "bottom" }))
  }
})
t("pointed and curled ends get room for the icons, plain ones none", () => {
  const room = ends => Style.endRoom(Object.assign(Style.defaults(), { ends, radius: 16 }), 72, 8)
  assert.strictEqual(room("rounded"), 0); assert.strictEqual(room("square"), 0)
  assert.ok(room("arrow") > 10, "arrow " + room("arrow"))
  assert.ok(room("puzzle") > 5 && room("castle") > 5)
  // the Scrolls ornament needs room for its curls, on any end
  for (const ornaments of ["crown", "laurels"])
    assert.ok(Style.endRoom(Object.assign(Style.defaults(), { ends: "rounded", radius: 16, ornaments }), 72, 8) > 35, ornaments)
  for (const ends of ["rounded", "capsule", "arrow"]) {
    const curled = Style.endRoom(Object.assign(Style.defaults(), { ends, radius: 16, ornaments: "scrolls" }), 72, 8)
    assert.ok(curled > 40 && curled >= room(ends), ends + " " + curled)
  }
  for (const e of Style.settings.ends.options) { const r = room(e); assert.ok(r >= 0 && r < 72, e + " " + r) }
  // the icons sit clear of the outline: one step in from the room the shape is inside
  const d = Object.assign(Style.defaults(), { ends: "arrow", radius: 16 })
  const r = Style.endRoom(d, 72, 8)
  const tr = Trace.trace(c => Paint.outline(c, 0, 0, 600, 72, 16, "arrow", "", "", "right", "end"))
  assert.ok(tr.len > 1200)
  assert.ok(r >= 30, "an arrow's notch reaches about half the thickness in: " + r)
})
t("capsule ends are fully round, rounded ones follow Corner radius, the rest draw their own", () => {
  const p = ends => Style.params(Object.assign(Style.defaults(), { opacity: 90, radius: 12, ends }), PAL, 300, 90, 11, {})
  assert.ok(p("capsule").r >= 45); assert.strictEqual(p("rounded").r, 12); assert.strictEqual(p("arrow").r, 0)
  assert.ok(Style.endRoom(Object.assign(Style.defaults(), { ends: "capsule", radius: 12 }), 72, 8) > 0)
})
t("colors: lines, glass, gradients and light docks", () => {
  const d = Object.assign(Style.defaults(), { opacity: 50, radius: 16, border: "accent", fill: "gradient", gradientTo: "darker" })
  const p = Style.params(d, PAL, 300, 90, 11, { edge: "top" })
  assert.ok(p.line.startsWith("rgba(200,146,90"), p.line)
  assert.ok(p.fill.endsWith(",0.5)"), p.fill)
  assert.ok(p.fill2 !== "")
  assert.strictEqual(p.inner, "end"); assert.strictEqual(Style.params(d, PAL, 90, 300, 11, { edge: "right" }).vertical, true)
  assert.strictEqual(Style.params(d, PAL, 300, 90, 11, { edge: "bottom" }).inner, "start")
  const light = Style.params(Object.assign({}, d, { fill: "glass" }), { bg: "#f5f0e8", fg: "#222222", ac: "#c8925a", hot: "#f00" }, 300, 90, 11, {})
  assert.ok(light.glass && light.light.indexOf("0.7") > 0)
  assert.strictEqual(Style.params(Object.assign({}, d, { surface: "clear" }), PAL, 300, 90, 11, {}).fill2, "")
})
console.log("\nALL OK (" + n + ")")
