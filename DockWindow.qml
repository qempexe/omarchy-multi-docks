import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "Effects.js" as Fx

PanelWindow {
  id: win

  required property var svc
  property int idx: 0

  readonly property var cfg: svc.docks[idx] || svc.defaults
  readonly property var pal: svc.palette(cfg)

  // By category: each app gets a steady hue from its first desktop category,
  // used for its running dot and hover. Other modes use the accent.
  function toneFor(e) {
    if (cfg.style !== "category") return pal.ac;
    const cats = (e && e.categories) ? e.categories : [];
    const main = cats.filter(c => ["GTK", "Qt", "KDE", "GNOME", "Application"].indexOf(c) < 0)[0] || (e ? e.id : "");
    return Qt.hsla(svc.hueOf(main), 0.55, 0.68, 1);
  }
  readonly property bool hz: cfg.edge === "top" || cfg.edge === "bottom"
  // Window outline: the edge of the dock and its popups is a plain neutral
  // line, or the accent color when the outline setting is on.
  function edgeColor(base) { return cfg.outline ? Qt.alpha(pal.ac, 0.8) : Qt.alpha(pal.fg, base) }
  readonly property int pad: 8
  readonly property int cell: cfg.size + 12
  readonly property int step: cell + 6
  readonly property int thick: cell + pad * 2
  readonly property int along: (cfg.apps.length + 1) * step - 6 + pad * 2

  // Which monitor this dock is on (its own choice, or the primary screen).
  readonly property string mon: svc.monOf(cfg)
  screen: svc.screenFor(cfg)
  readonly property var screenNames: {
    const out = [];
    for (let k = 0; k < Quickshell.screens.length; k++) out.push(Quickshell.screens[k].name);
    return out;
  }
  readonly property bool monitorMissing: cfg.monitor !== "" && screenNames.indexOf(cfg.monitor) < 0

  readonly property int groupSize: Math.max(1, svc.docks.filter(d => svc.sameGroup(d, cfg)).length)
  readonly property int groupPos: svc.docks.slice(0, idx).filter(d => svc.sameGroup(d, cfg)).length

  readonly property var corners: svc.cornersFor(svc.docks, mon, cfg.edge)
  readonly property int usableW: Math.max(0, svc.edgeLen(mon, cfg.edge) - corners.start - corners.end)
  readonly property int slotStart: corners.start + Math.floor(usableW / groupSize) * groupPos
  readonly property int slotW: Math.max(thick, svc.slotLen(svc.docks, idx))

  readonly property int maxApps: svc.capacity(svc.docks, idx)
  readonly property bool full: cfg.apps.length >= maxApps
  readonly property int popEdge: ({ bottom: Edges.Top, top: Edges.Bottom, left: Edges.Right, right: Edges.Left })[cfg.edge]

  // Margin for this dock's edge (shared by every dock on that edge). It lives
  // inside the window, so the window is thick + margin deep and the visible
  // dock is inset by the margin. That keeps the auto-hide strip on the very
  // edge, and makes the reserved band the same size as the window.
  readonly property int margin: svc.marginOf(cfg.edge)
  readonly property int winThick: thick + margin
  // If the Omarchy bar is on this dock's edge, the window starts behind the
  // bar's inner side so the dock sits above it, never over it.
  readonly property int barOffset: svc.barOffset(mon, cfg.edge)

  // What the colors / opacity / radius settings apply to.
  property int scopeIdx: 0
  readonly property string scope: ["dock", "edge", "all"][scopeIdx]
  readonly property var scopeLabels: ["this dock", cfg.edge + " edge" + (screenNames.length > 1 ? " here" : ""), "all docks"]

  property int dragFrom: -1
  property int dragTo: -1
  property var hoverSlot: null
  property var previewSlot: null
  property var menuSlot: null
  property bool addOpen: false
  property bool setOpen: false
  property bool lingering: false
  // Pointer is on the dock or its reveal strip (after the optional show delay).
  property bool hoverOpen: false
  readonly property bool popOpen: menuSlot !== null || addOpen || setOpen || previewPop.visible
  readonly property bool open: !cfg.autohide || hoverOpen || popOpen || lingering

  // ---- auto-hide motion ----
  // hideT: 0 = shown, 1 = hidden. It is animated by hand (not a Behavior) so
  // showing and hiding can use different easings.
  property real hideT: 0
  readonly property string effect: cfg.hideEffect || "slide"
  readonly property int strip: Math.max(1, Math.min(thick, cfg.revealStrip || 3))
  readonly property var fx: Fx.state(effect, hideT, winThick - strip)
  readonly property int speed: cfg.hideSpeed || 180
  // Wave: delay between one icon and the next.
  readonly property int waveStep: Math.max(12, Math.min(45, Math.round(speed / 4)))

  NumberAnimation {
    id: hideAnim
    target: win
    property: "hideT"
  }

  function animateHide() {
    hideAnim.stop();
    hideAnim.to = open ? 0 : 1;
    const springy = Fx.springy(effect);
    hideAnim.easing.type = open
      ? (springy ? Easing.OutBack : Easing.OutCubic)
      : (springy ? Easing.InBack : Easing.InCubic);
    hideAnim.easing.overshoot = effect === "pop" ? 2.2 : 1.7;
    hideAnim.duration = speed;
    hideAnim.start();
  }

  // Tell the service whether we are on screen so it can hold or release the
  // reserved space (auto-hide docks only reserve while visible).
  onOpenChanged: { svc.setShown(idx, open); animateHide(); }
  onCfgChanged: svc.setShown(idx, open)
  Component.onCompleted: { hideT = open ? 0 : 1; svc.setShown(idx, open); }
  Component.onDestruction: svc.setShown(idx, false)

  anchors {
    top: cfg.edge === "top" || !hz
    bottom: cfg.edge === "bottom"
    left: cfg.edge === "left" || hz
    right: cfg.edge === "right"
  }
  margins {
    top: cfg.edge === "top" ? barOffset : (hz ? 0 : slotStart)
    bottom: cfg.edge === "bottom" ? barOffset : 0
    left: cfg.edge === "left" ? barOffset : (hz ? slotStart : 0)
    right: cfg.edge === "right" ? barOffset : 0
  }
  implicitWidth: hz ? slotW : winThick
  implicitHeight: hz ? winThick : slotW

  // The dock never reserves; spacers in Service.qml do.
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  color: "transparent"
  // Only the dock catches the mouse. With auto-hide, a band on the very edge
  // does too: the reveal strip while hidden, and while shown everything from
  // the edge up to the dock, so moving from the strip onto the dock never
  // leaves the window (and never closes it again under the pointer).
  mask: Region {
    item: barHit
    Region { item: edgeHit }
  }

  WlrLayershell.namespace: "omarchy-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: (addOpen || setOpen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  function windowsOf(e) {
    if (!e) return [];
    const raw = (e.id || "").toLowerCase();
    const id = raw.replace(/\.desktop$/, "");
    const last = id.split(".").pop();
    const sc = (e.startupClass || "").toLowerCase();
    return ToplevelManager.toplevels.values.filter(t => {
      const a = (t.appId || "").toLowerCase();
      if (!a) return false;
      if (a === raw || a === id || a === sc) return true;
      if (last && last !== id && a === last) return true;
      return false;
    });
  }

  // Hyprland marks a window urgent when it asks for attention (a chat message,
  // a finished build, ...) and clears the flag once the window is focused.
  // The service follows Hyprland's urgent events and knows the app class of
  // each urgent window. As a second source, Quickshell's own per-window flag is
  // used when this Quickshell version has it.
  function isUrgent(t) {
    if (!t) return false;
    if (svc.classUrgent(t.appId)) return true;
    try {
      const list = Hyprland.toplevels.values;
      for (let k = 0; k < list.length; k++) {
        if (list[k].wayland === t && list[k].urgent) return true;
      }
    } catch (e) {}
    return false;
  }

  // Every window that is asking for attention, across all docks.
  readonly property bool anyUrgent: {
    if (cfg.attention === "off") return false;
    for (let k = 0; k < cfg.apps.length; k++) {
      const ws = windowsOf((DesktopEntries.applications.values, DesktopEntries.byId(cfg.apps[k])));
      for (let j = 0; j < ws.length; j++) if (isUrgent(ws[j])) return true;
    }
    return false;
  }

  function activate(e, ws) {
    if (!e) return;
    if (ws.length === 0) { e.execute(); return; }
    // A window that wants attention comes first, then normal cycling.
    const u = ws.find(t => isUrgent(t));
    if (u && cfg.attention !== "off") { u.activate(); return; }
    const i = ws.findIndex(t => t.activated);
    ws[(i + 1) % ws.length].activate();
  }

  function closePopups() { menuSlot = null; addOpen = false; setOpen = false; previewSlot = null; }

  Timer { id: linger; interval: win.cfg.hideDelay; onTriggered: win.lingering = false }
  Timer { id: showDelay; interval: win.cfg.showDelay; onTriggered: win.hoverOpen = true }
  Timer {
    id: hoverDelay
    interval: 250
    onTriggered: {
      if (win.hoverSlot && win.hoverSlot.wins.length > 0 && win.menuSlot === null && !win.addOpen && !win.setOpen)
        win.previewSlot = win.hoverSlot;
    }
  }
  Timer {
    id: hoverLeave
    interval: 350
    onTriggered: { if (!previewHover.hovered) win.previewSlot = null; win.hoverSlot = null; }
  }

  HyprlandFocusGrab {
    windows: [menuPop, addPop, setPop]
    active: win.menuSlot !== null || win.addOpen || win.setOpen
    onCleared: { win.menuSlot = null; win.addOpen = false; win.setOpen = false; }
  }

  Item {
    id: stage
    anchors.fill: parent

    // Rest geometry of the dock (fully shown).
    readonly property real barAlong: win.cfg.stretch ? win.slotW : Math.min(win.along, win.slotW)
    readonly property real barW: win.hz ? barAlong : win.thick
    readonly property real barH: win.hz ? win.thick : barAlong
    function placeAlong(total) {
      return win.cfg.align === "start" ? 0 : win.cfg.align === "end" ? total - barAlong : (total - barAlong) / 2;
    }
    readonly property real restX: win.hz ? placeAlong(width) : (win.cfg.edge === "left" ? win.margin : width - barW - win.margin)
    readonly property real restY: win.hz ? (win.cfg.edge === "top" ? win.margin : height - barH - win.margin) : placeAlong(height)
    // +1 when "toward the edge" is +x / +y, -1 otherwise.
    readonly property int outward: (win.cfg.edge === "bottom" || win.cfg.edge === "right") ? 1 : -1

    // Hover anywhere on the input region (dock or reveal strip).
    HoverHandler {
      id: stageHover
      onHoveredChanged: {
        if (hovered) {
          linger.stop();
          if (!win.open && win.cfg.autohide && win.cfg.showDelay > 0) showDelay.restart();
          else win.hoverOpen = true;
        } else {
          showDelay.stop();
          if (win.hoverOpen) { win.lingering = true; linger.restart(); }
          win.hoverOpen = false;
        }
      }
    }

    // Input region pieces (see `mask`).
    Item {
      id: barHit
      x: stage.restX; y: stage.restY
      width: win.open ? stage.barW : 0
      height: win.open ? stage.barH : 0
    }
    Item {
      id: edgeHit
      readonly property real band: win.cfg.autohide ? (win.open ? win.margin + win.strip : win.strip) : 0
      x: win.hz ? stage.restX : (win.cfg.edge === "left" ? 0 : stage.width - band)
      y: win.hz ? (win.cfg.edge === "top" ? 0 : stage.height - band) : stage.restY
      width: win.hz ? stage.barW : band
      height: win.hz ? band : stage.barH
    }

    // Thin pill on the screen edge while an auto-hidden dock is away, so you
    // can see where it is. It turns the attention color when an app asks.
    Rectangle {
      id: edgeHint
      visible: win.cfg.autohide && win.cfg.edgeHint && opacity > 0.01
      readonly property real len: Math.max(28, Math.min(stage.barAlong * 0.35, 160))
      width: win.hz ? len : 3
      height: win.hz ? 3 : len
      radius: 1.5
      x: win.hz ? stage.restX + (stage.barW - width) / 2 : (win.cfg.edge === "left" ? 1 : stage.width - width - 1)
      y: win.hz ? (win.cfg.edge === "top" ? 1 : stage.height - height - 1) : stage.restY + (stage.barH - height) / 2
      color: win.anyUrgent ? win.pal.hot : win.pal.fg
      opacity: Math.max(0, Math.min(1, win.hideT)) * (win.anyUrgent ? hintPulse : 0.5)
      property real hintPulse: 1
      SequentialAnimation on hintPulse {
        running: edgeHint.visible && win.anyUrgent && win.cfg.attention === "pulse"
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
      }
    }

  Rectangle {
    id: bar
    width: stage.barW
    height: stage.barH
    x: stage.restX + (win.hz ? 0 : stage.outward * win.fx.off)
    y: stage.restY + (win.hz ? stage.outward * win.fx.off : 0)
    opacity: Math.max(0, Math.min(1, win.fx.opacity))
    visible: opacity > 0.005
    transform: Scale {
      // Grow from / shrink onto the edge (or the center for "pop").
      origin.x: win.fx.center || win.hz ? bar.width / 2 : (win.cfg.edge === "left" ? 0 : bar.width)
      origin.y: win.fx.center || !win.hz ? bar.height / 2 : (win.cfg.edge === "top" ? 0 : bar.height)
      xScale: win.fx.scale * (win.hz ? 1 : win.fx.fold)
      yScale: win.fx.scale * (win.hz ? win.fx.fold : 1)
    }
    radius: win.cfg.radius
    color: Qt.alpha(win.pal.bg, win.cfg.opacity / 100 * Math.max(0, Math.min(1, win.fx.bg)))
    border.width: win.anyUrgent ? 2 : 1
    border.color: win.anyUrgent ? Qt.alpha(win.pal.hot, barPulse * Math.max(0, Math.min(1, win.fx.bg)))
      : (win.cfg.outline ? Qt.alpha(win.pal.ac, 0.8 * Math.max(0, Math.min(1, win.fx.bg)))
                         : Qt.alpha(win.pal.fg, 0.14 * Math.max(0, Math.min(1, win.fx.bg))))
    property real barPulse: 0.9
    SequentialAnimation on barPulse {
      running: win.anyUrgent && win.cfg.attention === "pulse"
      loops: Animation.Infinite
      NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
      NumberAnimation { to: 0.9; duration: 900; easing.type: Easing.InOutSine }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.RightButton
      onPressed: { win.previewSlot = null; win.setOpen = true; }
    }

    Grid {
      id: grid
      columns: win.hz ? 1000 : 1
      spacing: 6
      function place(free) {
        return win.cfg.align === "start" ? win.pad : win.cfg.align === "end" ? free - win.pad : free / 2;
      }
      x: win.hz ? (win.cfg.stretch ? place(bar.width - width) : win.pad) : win.pad
      y: win.hz ? win.pad : (win.cfg.stretch ? place(bar.height - height) : win.pad)

      Repeater {
        model: win.cfg.apps

        delegate: Item {
          id: slot
          required property string modelData
          required property int index
          // Reading .values makes this binding re-run whenever Quickshell rescans
          // the desktop entries, so the entry can never go stale or dangling.
          readonly property var entry: { DesktopEntries.applications.values; return DesktopEntries.byId(modelData); }
          // Last icon name that resolved. Kept so a rescan, a theme change or a
          // momentarily missing entry does not blank the icon.
          property string iconName: ""
          property int iconTick: 0
          function refreshIcon() {
            const n = (entry && entry.icon) ? entry.icon : "";
            if (n !== "") { iconName = n; return; }
            if (iconName === "" && wins.length > 0) iconName = wins[0].appId || "";
          }
          onEntryChanged: refreshIcon()
          onWinsChanged: refreshIcon()

          // Resolve to a path that actually exists in the current icon theme.
          // Unresolvable names would otherwise render Quickshell's magenta
          // "missing texture" checkerboard.
          readonly property string iconSrc: {
            slot.iconTick;
            const cands = [];
            if (iconName !== "") { cands.push(iconName); cands.push(iconName.toLowerCase()); }
            if (entry) {
              if (entry.id) { cands.push(entry.id); cands.push(entry.id.toLowerCase()); }
              if (entry.startupClass) cands.push(entry.startupClass.toLowerCase());
            }
            if (wins.length > 0 && wins[0].appId) { cands.push(wins[0].appId); cands.push(wins[0].appId.toLowerCase()); }
            cands.push("application-x-executable", "application-default-icon", "applications-other");
            for (const c of cands) {
              if (!c) continue;
              if (c.startsWith("/")) return "file://" + c;
              const r = Quickshell.iconPath(c, true);
              if (r) return r;
            }
            return "";
          }
          // Icon theme can change after launch (theme switch), so re-check
          // every few seconds while nothing resolves.
          Timer {
            interval: 3000; repeat: true
            running: slot.iconSrc === ""
            onTriggered: slot.iconTick++
          }
          readonly property var wins: win.windowsOf(entry)
          readonly property color tone: win.toneFor(entry)
          readonly property bool attention: win.cfg.attention !== "off" && wins.some(t => win.isUrgent(t))
          property bool dragging: false
          property real off: 0
          readonly property real shift: {
            if (dragging) return off;
            if (win.dragFrom < 0) return 0;
            if (win.dragFrom < index && index <= win.dragTo) return -win.step;
            if (win.dragTo <= index && index < win.dragFrom) return win.step;
            return 0;
          }

          // Wave: each icon pops on its own, one after another.
          property real pt: 0
          readonly property real waveT: win.effect === "wave" ? Math.max(0, Math.min(1, pt)) : 0
          Connections {
            target: win
            function onOpenChanged() { waveAnim.run(slot.index, win.cfg.apps.length + 1); }
          }
          Component.onCompleted: { pt = win.open ? 0 : 1; refreshIcon(); }
          SequentialAnimation {
            id: waveAnim
            function run(i, n) {
              stop();
              if (win.effect !== "wave") { slot.pt = win.open ? 0 : 1; return; }
              pause.duration = (win.open ? i : n - 1 - i) * win.waveStep;
              grow.to = win.open ? 0 : 1;
              grow.duration = win.speed;
              grow.easing.type = win.open ? Easing.OutBack : Easing.InCubic;
              start();
            }
            PauseAnimation { id: pause }
            NumberAnimation { id: grow; target: slot; property: "pt" }
          }

          width: win.cell
          height: win.cell
          z: dragging ? 10 : 0
          opacity: (dragging ? 0.85 : 1) * (1 - waveT)
          scale: 1 - 0.6 * waveT

          transform: Translate {
            x: win.hz ? slot.shift : 0
            y: win.hz ? 0 : slot.shift
            Behavior on x { enabled: !slot.dragging; NumberAnimation { duration: 120 } }
            Behavior on y { enabled: !slot.dragging; NumberAnimation { duration: 120 } }
          }

          Rectangle {
            anchors.fill: parent
            radius: 12
            color: win.cfg.style === "category"
              ? Qt.alpha(slot.tone, ma.containsMouse || slot.dragging ? 0.22 : 0)
              : Qt.alpha(win.pal.fg, ma.containsMouse || slot.dragging ? 0.14 : 0)
          }

          IconImage {
            anchors.centerIn: parent
            implicitSize: win.cfg.size
            visible: slot.iconSrc !== ""
            source: slot.iconSrc
          }

          // Plain letter tile when no icon can be found at all.
          Rectangle {
            anchors.centerIn: parent
            width: win.cfg.size; height: win.cfg.size
            radius: width * 0.25
            visible: slot.iconSrc === ""
            color: Qt.alpha(win.pal.fg, 0.15)
            Text {
              anchors.centerIn: parent
              text: (slot.modelData || "?").charAt(0).toUpperCase()
              color: win.pal.fg
              font.pixelSize: parent.height * 0.5
              font.bold: true
            }
          }

          // Soft glow around the icon while an app wants attention.
          Rectangle {
            id: glow
            anchors.fill: parent
            radius: 12
            visible: slot.attention && win.cfg.attention === "pulse"
            color: Qt.alpha(win.pal.hot, 0.18)
            border.width: 2
            border.color: win.pal.hot
            opacity: 0.9
            SequentialAnimation on opacity {
              running: glow.visible
              loops: Animation.Infinite
              NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
              NumberAnimation { to: 0.9; duration: 900; easing.type: Easing.InOutSine }
            }
          }

          Rectangle {
            visible: slot.wins.length > 0
            width: slot.attention ? 8 : 5; height: width; radius: width / 2
            color: slot.attention ? win.pal.hot : slot.tone
            x: win.hz ? (parent.width - width) / 2 : (win.cfg.edge === "left" ? 1 : parent.width - width - 1)
            y: win.hz ? (win.cfg.edge === "top" ? 1 : parent.height - height - 1) : (parent.height - height) / 2
          }

          MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property real startPos: 0
            property bool moved: false

            function along(m) {
              const p = mapToItem(grid, m.x, m.y);
              return win.hz ? p.x : p.y;
            }

            function reset() {
              slot.dragging = false; slot.off = 0; moved = false;
              win.dragFrom = -1; win.dragTo = -1;
            }

            onEntered: { hoverLeave.stop(); win.hoverSlot = slot; hoverDelay.restart(); }
            onExited: { hoverDelay.stop(); hoverLeave.restart(); }

            onPressed: m => {
              if (m.button === Qt.RightButton) {
                win.previewSlot = null; win.setOpen = false; win.addOpen = false;
                win.menuSlot = slot;
              } else {
                startPos = along(m); moved = false;
              }
            }

            onPositionChanged: m => {
              if (!(pressedButtons & Qt.LeftButton)) return;
              const d = along(m) - startPos;
              if (!moved && Math.abs(d) < 10) return;
              moved = true;
              win.previewSlot = null;
              slot.dragging = true;
              slot.off = d;
              win.dragFrom = slot.index;
              win.dragTo = Math.max(0, Math.min(win.cfg.apps.length - 1, slot.index + Math.round(d / win.step)));
            }

            onReleased: m => {
              if (m.button !== Qt.LeftButton) return;
              if (moved) {
                const to = win.dragTo, from = slot.index;
                reset();
                if (to !== from) win.svc.moveApp(win.idx, from, to);
              } else {
                win.activate(slot.entry, slot.wins);
              }
            }

            onCanceled: reset()
          }
        }
      }

      Item {
        id: addBtn
        width: win.cell
        height: win.cell
        property real pt: 0
        readonly property real waveT: win.effect === "wave" ? Math.max(0, Math.min(1, pt)) : 0
        opacity: 1 - waveT
        scale: 1 - 0.6 * waveT
        Component.onCompleted: pt = win.open ? 0 : 1
        Connections {
          target: win
          function onOpenChanged() {
            addWave.stop();
            if (win.effect !== "wave") { addBtn.pt = win.open ? 0 : 1; return; }
            addPause.duration = win.open ? win.cfg.apps.length * win.waveStep : 0;
            addGrow.to = win.open ? 0 : 1;
            addGrow.duration = win.speed;
            addGrow.easing.type = win.open ? Easing.OutBack : Easing.InCubic;
            addWave.start();
          }
        }
        SequentialAnimation {
          id: addWave
          PauseAnimation { id: addPause }
          NumberAnimation { id: addGrow; target: addBtn; property: "pt" }
        }

        Rectangle {
          anchors.fill: parent
          radius: 12
          color: Qt.alpha(win.pal.fg, addMa.containsMouse ? 0.14 : 0)
        }
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: win.full ? "⋯" : "+"
          color: win.pal.fg
          font.pixelSize: win.cfg.size * 0.6
        }
        MouseArea {
          id: addMa
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onPressed: m => {
            win.previewSlot = null; win.menuSlot = null;
            if (m.button === Qt.RightButton || win.full) { win.addOpen = false; win.setOpen = true; }
            else { win.setOpen = false; win.addOpen = !win.addOpen; }
          }
        }
      }
    }
  }
  }

  PopupWindow {
    id: previewPop
    // Keep the last window list so the popup never collapses into a tiny
    // empty rounded box (the black "bullet") while it is being hidden.
    property var shownWins: []
    property var shownSlot: null
    Connections {
      target: win
      function onPreviewSlotChanged() {
        if (win.previewSlot !== null && win.previewSlot.wins.length > 0) {
          previewPop.shownSlot = win.previewSlot;
          previewPop.shownWins = win.previewSlot.wins;
        }
      }
    }
    visible: win.previewSlot !== null && win.previewSlot.wins.length > 0 && shownWins.length > 0
    anchor.item: shownSlot
    anchor.edges: win.popEdge
    anchor.gravity: win.popEdge
    anchor.adjustment: PopupAdjustment.Slide
    implicitWidth: Math.max(previewRow.implicitWidth + 16, 236)
    implicitHeight: Math.max(previewRow.implicitHeight + 16, 166)
    color: "transparent"

    HoverHandler {
      id: previewHover
      onHoveredChanged: if (hovered) hoverLeave.stop(); else hoverLeave.restart();
    }

    Rectangle {
      anchors.fill: parent
      radius: 14
      visible: previewPop.visible && previewPop.shownWins.length > 0
      color: win.pal.bg
      border.width: 1
      border.color: win.edgeColor(0.18)

      Row {
        id: previewRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
          model: previewPop.shownWins

          delegate: Item {
            id: card
            required property var modelData
            readonly property bool urgent: win.cfg.attention !== "off" && win.isUrgent(modelData)
            width: 220
            height: 150

            Rectangle {
              anchors.fill: parent
              radius: 10
              color: Qt.alpha(win.pal.fg, cardMa.containsMouse ? 0.16 : 0.06)
              border.width: card.urgent ? 2 : 0
              border.color: win.pal.hot
            }
            ScreencopyView {
              x: 6; y: 6
              width: 208; height: 118
              captureSource: card.modelData
              live: true
            }
            Text {
              textFormat: Text.PlainText
              x: 8; y: 126
              width: 204
              text: card.modelData.title
              color: win.pal.fg
              elide: Text.ElideRight
              font.pixelSize: 12
            }
            MouseArea {
              id: cardMa
              anchors.fill: parent
              hoverEnabled: true
              onClicked: { card.modelData.activate(); win.previewSlot = null; }
            }
          }
        }
      }
    }
  }

  PopupWindow {
    id: menuPop
    readonly property var items: {
      const s = win.menuSlot;
      if (!s || !s.entry) return [];
      const out = [{ t: "New window", f: () => s.entry.execute() }];
      (s.entry.actions || []).forEach(a => { out.push({ t: a.name, f: () => a.execute() }); });
      s.wins.forEach(t => { out.push({ t: "Focus: " + t.title.slice(0, 32), f: () => t.activate() }); });
      if (s.wins.length > 0) out.push({ t: "Close window(s)", f: () => s.wins.forEach(t => t.close()) });
      out.push({ t: "Remove from dock", f: () => win.svc.removeApp(win.idx, s.modelData) });
      return out;
    }
    visible: win.menuSlot !== null
    anchor.item: win.menuSlot
    anchor.edges: win.popEdge
    anchor.gravity: win.popEdge
    anchor.adjustment: PopupAdjustment.Slide
    implicitWidth: 240
    implicitHeight: menuCol.implicitHeight + 12
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      radius: 12
      color: win.pal.bg
      border.width: 1
      border.color: win.edgeColor(0.18)

      Column {
        id: menuCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }

        Repeater {
          model: menuPop.items

          delegate: Rectangle {
            id: row
            required property var modelData
            width: menuCol.width
            height: 28
            radius: 8
            color: Qt.alpha(win.pal.fg, rowMa.containsMouse ? 0.14 : 0)

            Text {
              textFormat: Text.PlainText
              anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
              text: row.modelData.t
              color: win.pal.fg
              elide: Text.ElideRight
              font.pixelSize: 13
            }
            MouseArea {
              id: rowMa
              anchors.fill: parent
              hoverEnabled: true
              onClicked: { const f = row.modelData.f; win.menuSlot = null; f(); }
            }
          }
        }
      }
    }
  }

  PopupWindow {
    id: addPop
    readonly property var choices: DesktopEntries.applications.values
      .filter(e => !e.noDisplay && win.cfg.apps.indexOf(e.id) < 0
        && e.name.toLowerCase().indexOf(search.text.toLowerCase()) >= 0)
      .sort((a, b) => a.name.localeCompare(b.name))
    visible: win.addOpen
    anchor.item: addBtn
    anchor.edges: win.popEdge
    anchor.gravity: win.popEdge
    anchor.adjustment: PopupAdjustment.Slide
    implicitWidth: 300
    implicitHeight: 380
    color: "transparent"
    onVisibleChanged: if (visible) { search.clear(); search.forceActiveFocus(); }

    Rectangle {
      anchors.fill: parent
      radius: 14
      color: win.pal.bg
      border.width: 1
      border.color: win.edgeColor(0.18)

      Rectangle {
        id: searchBox
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        height: 32
        radius: 8
        color: Qt.alpha(win.pal.fg, 0.08)

        // Clipboard-free field: see SearchField.qml for why this is not a TextInput.
        SearchField {
          id: search
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          color: win.pal.fg
          selectionColor: Qt.alpha(win.pal.fg, 0.3)
          fontPixelSize: 14
        }
        Text {
          textFormat: Text.PlainText
          anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
          visible: search.text === ""
          text: "Search apps…"
          color: Qt.alpha(win.pal.fg, 0.5)
          font.pixelSize: 14
        }
      }

      ListView {
        anchors { left: parent.left; right: parent.right; top: searchBox.bottom; bottom: parent.bottom; margins: 10 }
        clip: true
        model: addPop.choices

        delegate: Rectangle {
          id: choice
          required property var modelData
          width: ListView.view.width
          height: 36
          radius: 8
          color: Qt.alpha(win.pal.fg, choiceMa.containsMouse ? 0.14 : 0)

          IconImage {
            id: choiceIcon
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 24
            source: Quickshell.iconPath(choice.modelData.icon, "application-x-executable")
          }
          Text {
            textFormat: Text.PlainText
            anchors { left: choiceIcon.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
            text: choice.modelData.name
            color: win.pal.fg
            elide: Text.ElideRight
            font.pixelSize: 13
          }
          MouseArea {
            id: choiceMa
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { win.addOpen = false; win.svc.addApp(win.idx, choice.modelData.id); }
          }
        }
      }
    }
  }

  PopupWindow {
    id: setPop
    visible: win.setOpen
    anchor.item: addBtn
    anchor.edges: win.popEdge
    anchor.gravity: win.popEdge
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Resize
    // Never taller than the free part of the screen; the rows scroll instead.
    readonly property int room: Math.max(320, (win.screen ? win.screen.height : 1080)
      - (win.hz ? win.winThick + win.barOffset : 0) - 40)
    implicitWidth: panel.implicitWidth
    implicitHeight: Math.min(room, panel.implicitHeight)
    color: "transparent"

    SettingsPanel {
      id: panel
      anchors.fill: parent
      dock: win
      svc: win.svc
      shown: setPop.visible
      onCloseRequested: win.setOpen = false
    }
  }
}
