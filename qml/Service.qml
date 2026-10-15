import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "dock"

Scope {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string cfgDir: home + "/.config/omarchy-dock"
  readonly property string cfgPath: cfgDir + "/config.json"
  // omarchy 4 keeps the theme in ~/.local/state, older versions in ~/.config. try new first
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
    opacity: 90, radius: 16, monitor: "", attention: "pulse",
    hideEffect: "slide", hideSpeed: 180, showDelay: 0, hideDelay: 450,
    revealStrip: 3, edgeHint: true, outline: false,
    customBg: "#141414", customFg: "#e0e0e0", accentColor: "#ff6a1f"
  })

  // color modes: theme, theme + your accent, greys, or theme with a tint per app category
  readonly property var styles: ["theme", "custom", "monochrome", "category"]
  // custom color swatches: backgrounds, text, accents
  readonly property var swatches: [
    "#141414", "#1d1510", "#1a1b26", "#282a36", "#2e3440", "#2d353b", "#1f1f28", "#3b2a1f",
    "#e0e0e0", "#eadbc8", "#ffffff", "#c0caf5", "#d8dee9", "#dcd7ba", "#f8f8f2", "#e0def4",
    "#d4a35a", "#c8925a", "#7aa2f7", "#cba6f7", "#a7c080", "#88c0d0", "#fabd2f", "#ff6a1f"
  ]

  function validHex(v, fallback) {
    const t = String(v === undefined || v === null ? "" : v).trim();
    return /^#[0-9a-fA-F]{6}$/.test(t) ? t.toLowerCase() : fallback;
  }

  // stable hue (0..1) per category name
  function hueOf(name) {
    const t = String(name || "");
    let h = 0;
    for (let k = 0; k < t.length; k++) h = (h * 31 + t.charCodeAt(k)) % 360;
    return h / 360;
  }

  // hide effects, in settings order
  readonly property var hideEffects: ["slide", "fade", "glide", "zoom", "fold", "bounce", "pop", "wave"]

  // allowed range per number, used to clean hand edited configs and resets
  readonly property var ranges: ({
    size: [1, 64], opacity: [1, 100], radius: [1, 64],
    hideSpeed: [60, 800], showDelay: [0, 1000], hideDelay: [0, 2000], revealStrip: [1, 12]
  })

  function cleanDock(x) {
    const d = Object.assign({}, defaults, x);
    for (const k in ranges) {
      const v = Number(d[k]);
      d[k] = isFinite(v) ? Math.max(ranges[k][0], Math.min(ranges[k][1], Math.round(v))) : defaults[k];
    }
    if (hideEffects.indexOf(d.hideEffect) < 0) d.hideEffect = defaults.hideEffect;
    if (["bottom", "top", "left", "right"].indexOf(d.edge) < 0) d.edge = defaults.edge;
    if (["start", "center", "end"].indexOf(d.align) < 0) d.align = defaults.align;
    if (["off", "dot", "pulse"].indexOf(d.attention) < 0) d.attention = defaults.attention;
    if (d.style === "mono") d.style = "monochrome";
    if (styles.indexOf(d.style) < 0) d.style = defaults.style;
    for (const c of ["customBg", "customFg", "accentColor"]) d[c] = validHex(d[c], defaults[c]);
    if (!Array.isArray(d.apps)) d.apps = [];
    // app ids only: plain strings, no control chars, no dupes
    d.apps = d.apps.filter((a, i, all) => typeof a === "string" && a.length > 0 && a.length <= 255
                                         && !/[\u0000-\u001f\u007f]/.test(a) && all.indexOf(a) === i).slice(0, 64);
    for (const b of ["stretch", "autohide", "reserve", "edgeHint", "outline"]) d[b] = d[b] === true;
    d.monitor = typeof d.monitor === "string" && d.monitor.length <= 64 ? d.monitor : "";
    return d;
  }
  // hot = attention color. mono keeps a soft red, a grey pulse would be invisible
  readonly property var mono: ({ bg: "#161616", fg: "#e0e0e0", ac: "#ffffff", hot: "#ff6b5e" })
  readonly property var defaultMargins: ({ top: 6, bottom: 6, left: 6, right: 6 })

  // empty until the config is read, so a default bottom dock never reserves space at startup
  property var docks: []
  property var theme: mono

  // gap between the edge (or the omarchy bar) and the docks, one per edge, shared
  property var margins: Object.assign({}, defaultMargins)

  // omarchy bar detection, per monitor
  // barSizes[mon][edge] = edge -> inner side of the bar (0 = no bar)
  // barInfos[mon] = what we found, for the settings
  property var barSizes: ({})
  property var barInfos: ({})

  function barOffset(mon, edge) { const b = barSizes[mon]; return b ? (b[edge] || 0) : 0; }
  function barInfoFor(mon) { return barInfos[mon] || ""; }
  function marginOf(edge) { const v = margins[edge]; return v === undefined ? 6 : v; }

  // colors for a dock or a style name. custom = your own bg/text/accent, attention stays the theme's
  function palette(d) {
    const style = typeof d === "string" ? d : (d ? d.style : "theme");
    if (style === "monochrome") return mono;
    if (style === "custom") return {
      bg: validHex(d && d.customBg, defaults.customBg),
      fg: validHex(d && d.customFg, defaults.customFg),
      ac: validHex(d && d.accentColor, defaults.accentColor),
      hot: theme.hot
    };
    return theme;
  }

  // saving
  function save() {
    Quickshell.execDetached(["sh", "-c",
      'umask 077; mkdir -p "$1" && chmod 700 "$1" && printf %s "$2" > "$3.tmp" && mv -f "$3.tmp" "$3"', "sh",
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

  // monitors. no monitor set, or not connected -> primary screen
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

  // how far in from the edge things reach on mon/edge: bar + docks (margin + thickness)
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

  // reserve space. index -> is that dock on screen right now (only matters with auto-hide)
  property var shown: ({})

  function setShown(i, v) {
    if ((shown[i] === true) === v) return;
    const n = Object.assign({}, shown);
    if (v) n[i] = true; else delete n[i];
    shown = n;
  }

  // a visible dock holds its space. with auto-hide it gives it back while hidden,
  // the setting itself doesn't change
  function reserving(i) {
    const d = docks[i];
    return !!d && d.reserve && (!d.autohide || shown[i] === true);
  }

  function edgeZone(mon, edge) {
    // window is thickness + margin deep (see DockWindow), so the band matches exactly
    let zone = 0;
    for (let i = 0; i < docks.length; i++) {
      const d = docks[i];
      if (d.edge === edge && monOf(d) === mon && reserving(i))
        zone = Math.max(zone, dockThick(d) + marginOf(edge));
    }
    return zone;
  }

  // changes
  function patch(i, key, value) {
    const n = docks.slice();
    if (key === "reserve") {
      // reserve is shared by every dock on the same edge of the same monitor
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

  // look settings for one dock, its edge, or everything
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

  // new dock goes on the monitor of the dock whose settings are open
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

  // reset everything except what the dock is (apps, edge, position, monitor)
  function resetDock(i) {
    const d = docks[i];
    if (!d) return;
    const n = docks.slice();
    n[i] = cleanDock({ apps: d.apps, edge: d.edge, align: d.align, monitor: d.monitor, reserve: d.reserve });
    if (!layoutOk(n)) { warn("The default icon size does not fit here. Remove some icons first."); return; }
    commit(n);
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
          root.docks = d.slice(0, root.maxDocks).map(x => root.cleanDock(x));
        if (j.margins) {
          const m = Object.assign({}, root.defaultMargins);
          for (const k of ["top", "bottom", "left", "right"]) {
            const v = Number(j.margins[k]);
            if (isFinite(v)) m[k] = Math.max(0, Math.min(64, Math.round(v)));
          }
          root.margins = m;
        }
      } catch (e) {}
      root.ensureDock();
    }
    onLoadFailed: root.ensureDock()
  }

  // no config yet (or an unreadable one): start with a single default dock
  function ensureDock() {
    if (docks.length === 0) docks = [Object.assign({}, defaults)];
  }

  // theme colors
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

  // bar probing: hyprctl into our cache dir, read back with a FileView
  // (avoids depending on quickshell's stdout api)
  Process {
    id: barProbe
    command: ["sh", "-c",
      'umask 077; mkdir -p "$1" && chmod 700 "$1" && rm -f "$1/layers.json" && ' +
      'hyprctl -j layers > "$1/layers.json" 2>/dev/null || true',
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

  // attention. hyprland sends urgent>>ADDRESS and drops it on focus/close.
  // we follow those events ourselves instead of relying on what quickshell exposes.
  // urgentMap: address (hex, no 0x) -> app class ("" until known)
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

  // fill in the class of each urgent window, forget the ones that are gone
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
      // titles in here, so private: owner-only dir/file, old copy removed first (> keeps the old mode)
      'umask 077; mkdir -p "$1" && chmod 700 "$1" && rm -f "$1/clients.json" && ' +
      'hyprctl -j clients > "$1/clients.json" 2>/dev/null || true',
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

  // hyprctl -j layers: { "DP-1": { "levels": { "0": [ {x,y,w,h,namespace} ], ... } } }
  // so one level deeper than a plain array per monitor
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

    // a layer with "bar" in its name wins, else any thin strip on an edge
    // (the shell's bar might have a generic name)
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

  // one window per dock
  Variants {
    model: Array.from({ length: root.docks.length }, (_, i) => i)

    DockWindow {
      required property int modelData
      idx: modelData
      svc: root
    }
  }

  // spacers for reserved space, one per monitor and edge
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
