import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string cfgDir: home + "/.config/omarchy-dock"
  readonly property string cfgPath: cfgDir + "/config.json"
  // Omarchy 4 keeps the active theme under ~/.local/state; older releases used
  // ~/.config. Try the new location first and fall back to the old one.
  property bool legacyTheme: false
  readonly property string themeDir: home + (legacyTheme
    ? "/.config/omarchy/current" : "/.local/state/omarchy/current")
  readonly property string themePath: themeDir + "/theme/colors.toml"
  readonly property string themeNamePath: themeDir + "/theme.name"
  readonly property string cacheDir: home + "/.cache/omarchy-dock"
  readonly property string layersPath: cacheDir + "/layers.json"

  readonly property int maxDocks: 12
  readonly property var defaults: ({
    apps: [], edge: "bottom", align: "center", stretch: false,
    autohide: false, reserve: true, style: "theme", size: 44,
    opacity: 90, radius: 16
  })
  readonly property var mono: ({ bg: "#161616", fg: "#e0e0e0", ac: "#ffffff" })
  readonly property var defaultMargins: ({ top: 6, bottom: 6, left: 6, right: 6 })

  property var docks: [Object.assign({}, defaults)]
  property var theme: mono

  // Gap between the screen edge (or the Omarchy bar) and the docks, one value
  // per edge. Every dock on an edge shares it.
  property var margins: Object.assign({}, defaultMargins)

  // ---- Omarchy bar detection ----
  // Distance from each screen edge to the inner side of the bar, 0 = no bar.
  property var barSizes: ({ top: 0, bottom: 0, left: 0, right: 0 })
  property string barInfo: ""

  function barOffset(edge) { return barSizes[edge] || 0; }
  function marginOf(edge) { const v = margins[edge]; return v === undefined ? 6 : v; }

  function palette(style) { return style === "theme" ? theme : mono; }

  // ---- persistence ----
  function save() {
    Quickshell.execDetached(["sh", "-c",
      'mkdir -p "$1" && printf %s "$2" > "$3"', "sh",
      cfgDir, JSON.stringify({ docks: docks, margins: margins }, null, 2), cfgPath]);
  }

  function commit(next) {
    docks = next;
    save();
  }

  readonly property int maxPerEdge: 3
  property string notice: ""

  Timer { id: noticeTimer; interval: 4000; onTriggered: root.notice = "" }
  function warn(text) { notice = text; noticeTimer.restart(); }

  function edgeLen(edge) {
    const s = Quickshell.screens[0];
    const hz = edge === "top" || edge === "bottom";
    return s ? (hz ? s.width : s.height) : (hz ? 1920 : 1080);
  }

  function dockThick(d) { return d.size + 28; }

  // How far in from the screen edge the stuff on `edge` reaches: the Omarchy
  // bar, plus (when docks sit there) their margin and thickness.
  function extent(list, edge) {
    const bar = barOffset(edge);
    const ds = list.filter(d => d.edge === edge);
    if (ds.length === 0) return bar;
    return bar + marginOf(edge) + ds.reduce((m, d) => Math.max(m, dockThick(d)), 0);
  }

  function cornersFor(list, edge) {
    const hz = edge === "top" || edge === "bottom";
    return { start: extent(list, hz ? "left" : "top"),
             end: extent(list, hz ? "right" : "bottom") };
  }

  function usableLen(list, edge) {
    const c = cornersFor(list, edge);
    return Math.max(0, edgeLen(edge) - c.start - c.end);
  }

  function slotLen(list, i) {
    const e = list[i].edge;
    const n = list.filter(x => x.edge === e).length;
    return Math.floor(usableLen(list, e) / n) - (n > 1 ? 6 : 0);
  }

  function capacity(list, i) {
    const step = list[i].size + 12 + 6;
    return Math.max(0, Math.floor((slotLen(list, i) - 10) / step) - 1);
  }

  function layoutOk(list) {
    for (let i = 0; i < list.length; i++) {
      const n = list.filter(x => x.edge === list[i].edge).length;
      if (n > maxPerEdge || list[i].apps.length > capacity(list, i)) return false;
    }
    return true;
  }

  // ---- reserve space ----
  // Whether each dock is currently on screen (index -> bool). Docks report
  // this from DockWindow; it only matters for auto-hide docks.
  property var shown: ({})

  function setShown(i, v) {
    if ((shown[i] === true) === v) return;
    const n = Object.assign({}, shown);
    if (v) n[i] = true; else delete n[i];
    shown = n;
  }

  // A dock holds its space while it is visible. With auto-hide on, the space
  // is given back as soon as the dock slides away and taken again when it
  // reappears; the Reserve space setting itself never changes.
  function reserving(i) {
    const d = docks[i];
    return !!d && d.reserve && (!d.autohide || shown[i] === true);
  }

  function edgeZone(edge) {
    // The dock window is thickness + margin deep (see DockWindow), so the
    // reserved band matches it exactly.
    let zone = 0;
    for (let i = 0; i < docks.length; i++) {
      const d = docks[i];
      if (d.edge === edge && reserving(i))
        zone = Math.max(zone, dockThick(d) + marginOf(edge));
    }
    return zone;
  }

  // ---- mutations ----
  function patch(i, key, value) {
    const n = docks.slice();
    if (key === "reserve") {
      const edge = n[i].edge;
      for (let j = 0; j < n.length; j++) {
        if (n[j].edge === edge) n[j] = Object.assign({}, n[j], { reserve: value });
      }
    } else {
      n[i] = Object.assign({}, n[i], { [key]: value });
    }
    if ((key === "edge" || key === "size") && !layoutOk(n)) {
      warn("Not enough room for those icons there. Remove some icons or pick a smaller size or another edge.");
      return;
    }
    commit(n);
  }

  // Look settings (colors, opacity, radius) for one dock, every dock on its
  // edge, or all docks.
  function patchScope(i, key, value, scope) {
    if (scope !== "edge" && scope !== "all") { patch(i, key, value); return; }
    const edge = docks[i].edge;
    commit(docks.map(d => (scope === "all" || d.edge === edge)
      ? Object.assign({}, d, { [key]: value }) : d));
  }

  function setMargin(edge, value) {
    const old = margins;
    margins = Object.assign({}, old, { [edge]: value });
    if (!layoutOk(docks)) {
      margins = old;
      warn("That margin leaves too little room for the icons on the other edges.");
      return;
    }
    save();
  }

  function addApp(i, id) {
    if (docks[i].apps.indexOf(id) >= 0) return;
    const n = docks.slice();
    n[i] = Object.assign({}, n[i], { apps: n[i].apps.concat([id]) });
    if (!layoutOk(n)) { warn("This dock is full. Use a smaller icon size or fewer docks on this edge."); return; }
    commit(n);
  }

  function removeApp(i, id) { patch(i, "apps", docks[i].apps.filter(a => a !== id)); }

  function moveApp(i, from, to) {
    const a = docks[i].apps.slice();
    a.splice(to, 0, a.splice(from, 1)[0]);
    patch(i, "apps", a);
  }

  function addDock() {
    if (docks.length >= maxDocks) { warn("Maximum of " + maxDocks + " docks."); return; }
    const count = e => docks.filter(d => d.edge === e).length;
    const order = ["bottom", "top", "left", "right"].filter(e => count(e) < maxPerEdge)
      .sort((a, b) => count(a) - count(b));
    for (let k = 0; k < order.length; k++) {
      const next = docks.concat([Object.assign({}, defaults, { apps: [], edge: order[k] })]);
      if (layoutOk(next)) { commit(next); return; }
    }
    warn("No room for another dock. Shrink icons or remove some apps first.");
  }

  function removeDock(i) {
    if (docks.length > 1) commit(docks.filter((d, j) => j !== i));
  }

  FileView {
    id: cfgFile
    path: root.cfgPath
    blockLoading: true
    printErrors: false
    onLoaded: {
      try {
        const j = JSON.parse(text());
        const d = j.docks;
        if (d && d.length)
          root.docks = d.slice(0, root.maxDocks).map(x => Object.assign({}, root.defaults, x));
        if (j.margins) {
          const m = Object.assign({}, root.defaultMargins);
          for (const k of ["top", "bottom", "left", "right"]) {
            const v = Number(j.margins[k]);
            if (isFinite(v)) m[k] = Math.max(0, Math.min(64, Math.round(v)));
          }
          root.margins = m;
        }
      } catch (e) {}
    }
  }

  // ---- theme colors ----
  function parseTheme(t) {
    const pick = k => {
      const m = t.match(new RegExp("^\\s*" + k + "\\s*=\\s*[\"']?(#[0-9a-fA-F]{6})", "m"));
      return m ? m[1] : null;
    };
    const next = {
      bg: pick("background") || mono.bg,
      fg: pick("foreground") || mono.fg,
      ac: pick("accent") || mono.ac
    };
    if (JSON.stringify(next) !== JSON.stringify(theme)) theme = next;
  }

  FileView {
    id: themeFile
    path: root.themePath
    blockLoading: true
    printErrors: false
    watchChanges: true
    onLoaded: root.parseTheme(text())
    onLoadFailed: root.legacyTheme = !root.legacyTheme
    onFileChanged: reload()
  }

  FileView {
    id: themeNameFile
    path: root.themeNamePath
    blockLoading: true
    printErrors: false
    watchChanges: true
    onFileChanged: themeFile.reload()
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: themeFile.reload()
  }

  // ---- Omarchy bar probing ----
  // Shell out to hyprctl and drop the JSON in our cache dir, then read it
  // back with a FileView. This avoids depending on any less-portable
  // Quickshell stdout API.
  Process {
    id: barProbe
    command: ["sh", "-c",
      'mkdir -p "$1" && hyprctl -j layers > "$1/layers.json" 2>/dev/null || true',
      "sh", root.cacheDir]
    running: false
    onExited: barLayers.reload()
  }

  FileView {
    id: barLayers
    path: root.layersPath
    blockLoading: true
    printErrors: false
    onLoaded: root.detectBar(text())
  }

  // `hyprctl -j layers` looks like
  //   { "DP-1": { "levels": { "0": [ {x,y,w,h,namespace,...} ], "1": [], ... } } }
  // so the layers sit one level deeper than a plain array per monitor.
  function detectBar(json) {
    let data;
    try { data = JSON.parse(json); } catch (e) { return; }
    const screen = Quickshell.screens[0];
    if (!screen || !data) return;
    const sw = screen.width, sh = screen.height;

    const mon = (screen.name && data[screen.name]) ? data[screen.name] : data[Object.keys(data)[0]];
    let layers = [];
    if (Array.isArray(mon)) layers = mon;
    else if (mon && mon.levels) {
      for (const k in mon.levels) layers = layers.concat(mon.levels[k] || []);
    }

    const named = [], shaped = [];
    for (const l of layers) {
      const ns = String(l.namespace || "").toLowerCase();
      if (ns.indexOf("omarchy-dock") === 0) continue;   // our own dock + spacers
      const x = l.x | 0, y = l.y | 0, w = l.w | 0, h = l.h | 0;
      if (w <= 0 || h <= 0) continue;

      let edge = "", size = 0;
      if (w >= sw * 0.5 && h <= sh * 0.25) {
        if (y < sh * 0.1) { edge = "top"; size = y + h; }
        else if (sh - (y + h) < sh * 0.1) { edge = "bottom"; size = sh - y; }
      } else if (h >= sh * 0.5 && w <= sw * 0.25) {
        if (x < sw * 0.1) { edge = "left"; size = x + w; }
        else if (sw - (x + w) < sw * 0.1) { edge = "right"; size = sw - x; }
      }
      if (edge === "") continue;

      const hit = { edge, size, ns };
      (ns.indexOf("bar") >= 0 ? named : shaped).push(hit);
    }

    // A layer whose name says "bar" wins; otherwise fall back to any thin
    // strip hugging a screen edge (the shell's own bar may use a generic name).
    const picks = named.length > 0 ? named : shaped;
    const sizes = { top: 0, bottom: 0, left: 0, right: 0 };
    const info = [];
    for (const p of picks) {
      if (p.size > sizes[p.edge]) sizes[p.edge] = p.size;
      info.push(p.edge + " " + p.size + "px (" + p.ns + ")");
    }

    if (JSON.stringify(sizes) !== JSON.stringify(root.barSizes)) root.barSizes = sizes;
    const text = info.join(", ");
    if (root.barInfo !== text) root.barInfo = text;
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: { if (!barProbe.running) barProbe.running = true; }
  }

  // ---- one window per dock ----
  Variants {
    model: Array.from({ length: root.docks.length }, (_, i) => i)

    DockWindow {
      required property int modelData
      idx: modelData
      svc: root
    }
  }

  // ---- reserve-space spacers ----
  PanelWindow {
    anchors.top: true
    implicitWidth: 1
    implicitHeight: 1
    exclusionMode: root.edgeZone("top") > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: root.edgeZone("top")
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-dock-reserve"
  }
  PanelWindow {
    anchors.bottom: true
    implicitWidth: 1
    implicitHeight: 1
    exclusionMode: root.edgeZone("bottom") > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: root.edgeZone("bottom")
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-dock-reserve"
  }
  PanelWindow {
    anchors.left: true
    implicitWidth: 1
    implicitHeight: 1
    exclusionMode: root.edgeZone("left") > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: root.edgeZone("left")
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-dock-reserve"
  }
  PanelWindow {
    anchors.right: true
    implicitWidth: 1
    implicitHeight: 1
    exclusionMode: root.edgeZone("right") > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: root.edgeZone("right")
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-dock-reserve"
  }
}
