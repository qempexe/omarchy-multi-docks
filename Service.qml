import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
    opacity: 90, radius: 16, monitor: "", attention: "pulse"
  })
  // `hot` is the attention color. Monochrome keeps a fixed soft red, because a grey
  // pulse would be invisible.
  readonly property var mono: ({ bg: "#161616", fg: "#e0e0e0", ac: "#ffffff", hot: "#ff6b5e" })
  readonly property var defaultMargins: ({ top: 6, bottom: 6, left: 6, right: 6 })

  property var docks: [Object.assign({}, defaults)]
  property var theme: mono

  // Gap between the screen edge (or the Omarchy bar) and the docks, one value
  // per edge. Every dock on an edge shares it.
  property var margins: Object.assign({}, defaultMargins)

  // ---- Omarchy bar detection (per monitor) ----
  // barSizes[monitor][edge] = distance from that screen edge to the inner side
  // of the bar, 0 = no bar. barInfos[monitor] = what was found, for display.
  property var barSizes: ({})
  property var barInfos: ({})

  function barOffset(mon, edge) { const b = barSizes[mon]; return b ? (b[edge] || 0) : 0; }
  function barInfoFor(mon) { return barInfos[mon] || ""; }
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

  // ---- monitors ----
  // A dock whose monitor is empty, or not connected right now, lives on the
  // primary screen (the shell's first screen).
  function screenByName(name) {
    const list = Quickshell.screens;
    for (let k = 0; k < list.length; k++) if (list[k].name === name) return list[k];
    return null;
  }

  function screenFor(d) {
    const found = (d && d.monitor) ? screenByName(d.monitor) : null;
    if (found) return found;
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
  }

  function monOf(d) { const s = screenFor(d); return s ? s.name : ""; }
  function sameGroup(a, b) { return a.edge === b.edge && monOf(a) === monOf(b); }

  function edgeLen(mon, edge) {
    const s = screenByName(mon);
    const hz = edge === "top" || edge === "bottom";
    return s ? (hz ? s.width : s.height) : (hz ? 1920 : 1080);
  }

  function dockThick(d) { return d.size + 28; }

  // How far in from the screen edge the stuff on `edge` of monitor `mon`
  // reaches: the Omarchy bar, plus (when docks sit there) their margin and
  // thickness.
  function extent(list, mon, edge) {
    const bar = barOffset(mon, edge);
    const ds = list.filter(d => d.edge === edge && monOf(d) === mon);
    if (ds.length === 0) return bar;
    return bar + marginOf(edge) + ds.reduce((m, d) => Math.max(m, dockThick(d)), 0);
  }

  function cornersFor(list, mon, edge) {
    const hz = edge === "top" || edge === "bottom";
    return { start: extent(list, mon, hz ? "left" : "top"),
             end: extent(list, mon, hz ? "right" : "bottom") };
  }

  function usableLen(list, mon, edge) {
    const c = cornersFor(list, mon, edge);
    return Math.max(0, edgeLen(mon, edge) - c.start - c.end);
  }

  function slotLen(list, i) {
    const d = list[i], mon = monOf(d);
    const n = list.filter(x => sameGroup(x, d)).length;
    return Math.floor(usableLen(list, mon, d.edge) / n) - (n > 1 ? 6 : 0);
  }

  function capacity(list, i) {
    const step = list[i].size + 12 + 6;
    return Math.max(0, Math.floor((slotLen(list, i) - 10) / step) - 1);
  }

  function layoutOk(list) {
    for (let i = 0; i < list.length; i++) {
      const n = list.filter(x => sameGroup(x, list[i])).length;
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

  function edgeZone(mon, edge) {
    // The dock window is thickness + margin deep (see DockWindow), so the
    // reserved band matches it exactly.
    let zone = 0;
    for (let i = 0; i < docks.length; i++) {
      const d = docks[i];
      if (d.edge === edge && monOf(d) === mon && reserving(i))
        zone = Math.max(zone, dockThick(d) + marginOf(edge));
    }
    return zone;
  }

  // ---- mutations ----
  function patch(i, key, value) {
    const n = docks.slice();
    if (key === "reserve") {
      // Reserve is shared by every dock on the same edge of the same monitor.
      const ref = n[i];
      for (let j = 0; j < n.length; j++) {
        if (sameGroup(n[j], ref)) n[j] = Object.assign({}, n[j], { reserve: value });
      }
    } else {
      n[i] = Object.assign({}, n[i], { [key]: value });
    }
    if ((key === "edge" || key === "size" || key === "monitor") && !layoutOk(n)) {
      warn("Not enough room for those icons there. Remove some icons or pick a smaller size, another edge or another monitor.");
      return;
    }
    commit(n);
  }

  // Look settings (colors, opacity, radius) for one dock, every dock on its
  // edge, or all docks.
  function patchScope(i, key, value, scope) {
    if (scope !== "edge" && scope !== "all") { patch(i, key, value); return; }
    const ref = docks[i];
    commit(docks.map(d => (scope === "all" || sameGroup(d, ref))
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

  // The new dock goes on the same monitor as the dock whose settings are open.
  function addDock(from) {
    if (docks.length >= maxDocks) { warn("Maximum of " + maxDocks + " docks."); return; }
    const monitor = (from !== undefined && docks[from]) ? docks[from].monitor : "";
    const probe = { monitor: monitor };
    const count = e => docks.filter(d => d.edge === e && monOf(d) === monOf(probe)).length;
    const order = ["bottom", "top", "left", "right"].filter(e => count(e) < maxPerEdge)
      .sort((a, b) => count(a) - count(b));
    for (let k = 0; k < order.length; k++) {
      const next = docks.concat([Object.assign({}, defaults, { apps: [], edge: order[k], monitor: monitor })]);
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
      ac: pick("accent") || mono.ac,
      hot: pick("color1") || pick("color9") || mono.hot
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

  // ---- attention (windows that ask for focus) ----
  // Hyprland announces them with an `urgent>>ADDRESS` event and drops the mark
  // when the window is focused or closed. We follow those events ourselves, so
  // this does not depend on how much of Hyprland's window state Quickshell
  // exposes. urgentMap: window address (hex, no 0x) -> app class, "" until known.
  property var urgentMap: ({})
  readonly property string clientsPath: cacheDir + "/clients.json"
  property bool clientsAgain: false

  function classUrgent(cls) {
    const c = String(cls || "").toLowerCase();
    if (c === "") return false;
    for (const k in urgentMap) if (urgentMap[k] === c) return true;
    return false;
  }

  function normAddr(a) {
    return String(a || "").trim().toLowerCase().split(",")[0].replace(/^0x/, "");
  }

  function markUrgent(a) {
    const addr = normAddr(a);
    if (addr === "") return;
    if (!(addr in urgentMap)) {
      const n = Object.assign({}, urgentMap);
      n[addr] = "";
      urgentMap = n;
    }
    probeClients();
  }

  function clearUrgent(a) {
    const addr = normAddr(a);
    if (addr === "" || !(addr in urgentMap)) return;
    const n = Object.assign({}, urgentMap);
    delete n[addr];
    urgentMap = n;
  }

  function probeClients() {
    if (clientsProbe.running) { clientsAgain = true; return; }
    clientsProbe.running = true;
  }

  // Fill in the class of each urgent window, and forget windows that are gone.
  function resolveClients(json) {
    let list;
    try { list = JSON.parse(json); } catch (e) { return; }
    if (!Array.isArray(list)) return;
    const byAddr = {};
    for (const c of list) byAddr[normAddr(c.address)] = String(c["class"] || c["initialClass"] || "").toLowerCase();
    const n = {};
    let changed = false;
    for (const k in urgentMap) {
      if (!(k in byAddr)) { changed = true; continue; }
      n[k] = byAddr[k];
      if (n[k] !== urgentMap[k]) changed = true;
    }
    if (changed) urgentMap = n;
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "urgent") root.markUrgent(event.data);
      else if (event.name === "activewindowv2" || event.name === "closewindow") root.clearUrgent(event.data);
    }
  }

  Process {
    id: clientsProbe
    command: ["sh", "-c",
      'mkdir -p "$1" && hyprctl -j clients > "$1/clients.json" 2>/dev/null || true',
      "sh", root.cacheDir]
    running: false
    onExited: {
      clientsFile.reload();
      if (root.clientsAgain) { root.clientsAgain = false; running = true; }
    }
  }

  FileView {
    id: clientsFile
    path: root.clientsPath
    blockLoading: true
    printErrors: false
    onLoaded: root.resolveClients(text())
  }

  // `hyprctl -j layers` looks like
  //   { "DP-1": { "levels": { "0": [ {x,y,w,h,namespace,...} ], "1": [], ... } } }
  // so the layers sit one level deeper than a plain array per monitor.
  function scanBar(mon, sw, sh) {
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
    return { sizes: sizes, info: info.join(", ") };
  }

  function detectBar(json) {
    let data;
    try { data = JSON.parse(json); } catch (e) { return; }
    const list = Quickshell.screens;
    if (!data || list.length === 0) return;

    const sizes = {}, infos = {};
    for (let k = 0; k < list.length; k++) {
      const s = list[k];
      let mon = data[s.name];
      if (mon === undefined && list.length === 1) mon = data[Object.keys(data)[0]];
      const r = scanBar(mon, s.width, s.height);
      sizes[s.name] = r.sizes;
      infos[s.name] = r.info;
    }

    if (JSON.stringify(sizes) !== JSON.stringify(root.barSizes)) root.barSizes = sizes;
    if (JSON.stringify(infos) !== JSON.stringify(root.barInfos)) root.barInfos = infos;
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

  // ---- reserve-space spacers: one per monitor and edge ----
  Variants {
    model: Quickshell.screens

    Scope {
      id: perScreen
      required property var modelData

      Spacer { svc: root; screen: perScreen.modelData; edge: "top" }
      Spacer { svc: root; screen: perScreen.modelData; edge: "bottom" }
      Spacer { svc: root; screen: perScreen.modelData; edge: "left" }
      Spacer { svc: root; screen: perScreen.modelData; edge: "right" }
    }
  }
}
