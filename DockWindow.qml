import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
  id: win

  required property var svc
  property int idx: 0

  readonly property var cfg: svc.docks[idx] || svc.defaults
  readonly property var pal: svc.palette(cfg.style)
  readonly property bool hz: cfg.edge === "top" || cfg.edge === "bottom"
  readonly property int pad: 8
  readonly property int cell: cfg.size + 12
  readonly property int step: cell + 6
  readonly property int thick: cell + pad * 2
  readonly property int along: (cfg.apps.length + 1) * step - 6 + pad * 2

  readonly property int groupSize: Math.max(1, svc.docks.filter(d => d.edge === cfg.edge).length)
  readonly property int groupPos: svc.docks.slice(0, idx).filter(d => d.edge === cfg.edge).length

  readonly property var corners: svc.cornersFor(svc.docks, cfg.edge)
  readonly property int usableW: Math.max(0, svc.edgeLen(cfg.edge) - corners.start - corners.end)
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
  readonly property int barOffset: svc.barOffset(cfg.edge)

  // What the colors / opacity / radius settings apply to.
  property int scopeIdx: 0
  readonly property string scope: ["dock", "edge", "all"][scopeIdx]
  readonly property var scopeLabels: ["this dock", cfg.edge + " edge", "all docks"]

  property int dragFrom: -1
  property int dragTo: -1
  property var hoverSlot: null
  property var previewSlot: null
  property var menuSlot: null
  property bool addOpen: false
  property bool setOpen: false
  property bool lingering: false
  readonly property bool popOpen: menuSlot !== null || addOpen || setOpen || previewPop.visible
  readonly property bool open: !cfg.autohide || barHover.hovered || popOpen || lingering

  // Tell the service whether we are on screen so it can hold or release the
  // reserved space (auto-hide docks only reserve while visible).
  onOpenChanged: svc.setShown(idx, open)
  onCfgChanged: svc.setShown(idx, open)
  Component.onCompleted: svc.setShown(idx, open)
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
  mask: Region { item: bar }

  WlrLayershell.namespace: "omarchy-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: addOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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

  function activate(e, ws) {
    if (!e) return;
    if (ws.length === 0) { e.execute(); return; }
    const i = ws.findIndex(t => t.activated);
    ws[(i + 1) % ws.length].activate();
  }

  function closePopups() { menuSlot = null; addOpen = false; setOpen = false; previewSlot = null; }

  Timer { id: linger; interval: 450; onTriggered: win.lingering = false }
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

  Rectangle {
    id: bar
    readonly property real hidden: win.open ? 0 : win.winThick - 3
    readonly property real barAlong: win.cfg.stretch ? win.slotW : Math.min(win.along, win.slotW)
    function placeAlong(total) {
      return win.cfg.align === "start" ? 0 : win.cfg.align === "end" ? total - barAlong : (total - barAlong) / 2;
    }
    width: win.hz ? barAlong : win.thick
    height: win.hz ? win.thick : barAlong
    x: win.hz ? placeAlong(parent.width) : (win.cfg.edge === "left" ? win.margin - hidden : parent.width - width - win.margin + hidden)
    y: win.hz ? (win.cfg.edge === "top" ? win.margin - hidden : parent.height - height - win.margin + hidden) : placeAlong(parent.height)
    radius: win.cfg.radius
    color: Qt.alpha(win.pal.bg, win.cfg.opacity / 100)
    border.width: 1
    border.color: Qt.alpha(win.pal.fg, 0.14)

    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    HoverHandler {
      id: barHover
      onHoveredChanged: if (!hovered) { win.lingering = true; linger.restart(); }
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
          readonly property var entry: DesktopEntries.byId(modelData)
          readonly property var wins: win.windowsOf(entry)
          property bool dragging: false
          property real off: 0
          readonly property real shift: {
            if (dragging) return off;
            if (win.dragFrom < 0) return 0;
            if (win.dragFrom < index && index <= win.dragTo) return -win.step;
            if (win.dragTo <= index && index < win.dragFrom) return win.step;
            return 0;
          }

          width: win.cell
          height: win.cell
          z: dragging ? 10 : 0
          opacity: dragging ? 0.85 : 1

          transform: Translate {
            x: win.hz ? slot.shift : 0
            y: win.hz ? 0 : slot.shift
            Behavior on x { enabled: !slot.dragging; NumberAnimation { duration: 120 } }
            Behavior on y { enabled: !slot.dragging; NumberAnimation { duration: 120 } }
          }

          Rectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.alpha(win.pal.fg, ma.containsMouse || slot.dragging ? 0.14 : 0)
          }

          IconImage {
            anchors.centerIn: parent
            implicitSize: win.cfg.size
            source: Quickshell.iconPath(slot.entry ? slot.entry.icon : "", "application-x-executable")
          }

          Rectangle {
            visible: slot.wins.length > 0
            width: 5; height: 5; radius: 3
            color: win.pal.ac
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

  PopupWindow {
    id: previewPop
    visible: win.previewSlot !== null && win.previewSlot.wins.length > 0
    anchor.item: win.previewSlot
    anchor.edges: win.popEdge
    anchor.gravity: win.popEdge
    anchor.adjustment: PopupAdjustment.Slide
    implicitWidth: previewRow.implicitWidth + 16
    implicitHeight: previewRow.implicitHeight + 16
    color: "transparent"

    HoverHandler {
      id: previewHover
      onHoveredChanged: if (hovered) hoverLeave.stop(); else hoverLeave.restart();
    }

    Rectangle {
      anchors.fill: parent
      radius: 14
      color: win.pal.bg
      border.width: 1
      border.color: Qt.alpha(win.pal.fg, 0.18)

      Row {
        id: previewRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
          model: win.previewSlot ? win.previewSlot.wins : []

          delegate: Item {
            id: card
            required property var modelData
            width: 220
            height: 150

            Rectangle {
              anchors.fill: parent
              radius: 10
              color: Qt.alpha(win.pal.fg, cardMa.containsMouse ? 0.16 : 0.06)
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
      border.color: Qt.alpha(win.pal.fg, 0.18)

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
    onVisibleChanged: if (visible) { search.text = ""; search.forceActiveFocus(); }

    Rectangle {
      anchors.fill: parent
      radius: 14
      color: win.pal.bg
      border.width: 1
      border.color: Qt.alpha(win.pal.fg, 0.18)

      Rectangle {
        id: searchBox
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        height: 32
        radius: 8
        color: Qt.alpha(win.pal.fg, 0.08)

        TextInput {
          id: search
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          verticalAlignment: TextInput.AlignVCenter
          color: win.pal.fg
          font.pixelSize: 14
          clip: true
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
    implicitWidth: setCol.implicitWidth + 28
    implicitHeight: setCol.implicitHeight + 28
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      radius: 14
      color: win.pal.bg
      border.width: 1
      border.color: Qt.alpha(win.pal.fg, 0.18)

      Column {
        id: setCol
        anchors.centerIn: parent
        spacing: 10

        Grid {
          columns: 2
          rowSpacing: 8
          columnSpacing: 14
          verticalItemAlignment: Grid.AlignVCenter

          Text { textFormat: Text.PlainText; text: "Edge"; color: win.pal.fg; font.pixelSize: 13 }
          Chips {
            fg: win.pal.fg; ac: win.pal.ac
            options: ["bottom", "top", "left", "right"]
            value: win.cfg.edge
            onPicked: v => win.svc.patch(win.idx, "edge", v)
          }
          Text { textFormat: Text.PlainText; text: "Position"; color: win.pal.fg; font.pixelSize: 13 }
          Chips {
            fg: win.pal.fg; ac: win.pal.ac
            options: ["start", "center", "end"]
            value: win.cfg.align
            onPicked: v => win.svc.patch(win.idx, "align", v)
          }
          Text { textFormat: Text.PlainText; text: "Full length"; color: win.pal.fg; font.pixelSize: 13 }
          Chips {
            fg: win.pal.fg; ac: win.pal.ac
            options: ["on", "off"]
            value: win.cfg.stretch ? "on" : "off"
            onPicked: v => win.svc.patch(win.idx, "stretch", v === "on")
          }
          Text { textFormat: Text.PlainText; text: "Auto-hide"; color: win.pal.fg; font.pixelSize: 13 }
          Chips {
            fg: win.pal.fg; ac: win.pal.ac
            options: ["on", "off"]
            value: win.cfg.autohide ? "on" : "off"
            onPicked: v => win.svc.patch(win.idx, "autohide", v === "on")
          }
          Text { textFormat: Text.PlainText; text: "Reserve space"; color: win.pal.fg; font.pixelSize: 13 }
          Chips {
            fg: win.pal.fg; ac: win.pal.ac
            options: ["on", "off"]
            value: win.cfg.reserve ? "on" : "off"
            onPicked: v => win.svc.patch(win.idx, "reserve", v === "on")
          }
          Text { textFormat: Text.PlainText; text: "Look applies to"; color: win.pal.fg; font.pixelSize: 13 }
          Chips {
            fg: win.pal.fg; ac: win.pal.ac
            options: win.scopeLabels
            value: win.scopeLabels[win.scopeIdx]
            onPicked: v => win.scopeIdx = win.scopeLabels.indexOf(v)
          }
          Text { textFormat: Text.PlainText; text: "Colors"; color: win.pal.fg; font.pixelSize: 13 }
          Chips {
            fg: win.pal.fg; ac: win.pal.ac
            options: ["theme", "monochrome"]
            value: win.cfg.style
            onPicked: v => win.svc.patchScope(win.idx, "style", v, win.scope)
          }
          Text { textFormat: Text.PlainText; text: "Icon size"; color: win.pal.fg; font.pixelSize: 13 }
          Slider {
            fg: win.pal.fg; ac: win.pal.ac
            from: 1; to: 64
            value: win.cfg.size
            onPicked: v => win.svc.patch(win.idx, "size", v)
          }
          Text { textFormat: Text.PlainText; text: "Opacity"; color: win.pal.fg; font.pixelSize: 13 }
          Slider {
            fg: win.pal.fg; ac: win.pal.ac
            from: 1; to: 100
            value: win.cfg.opacity
            suffix: "%"
            onPicked: v => win.svc.patchScope(win.idx, "opacity", v, win.scope)
          }
          Text { textFormat: Text.PlainText; text: "Corner radius"; color: win.pal.fg; font.pixelSize: 13 }
          Slider {
            fg: win.pal.fg; ac: win.pal.ac
            from: 1; to: 64
            value: win.cfg.radius
            onPicked: v => win.svc.patchScope(win.idx, "radius", v, win.scope)
          }
          Text { textFormat: Text.PlainText; text: "Margin (" + win.cfg.edge + ")"; color: win.pal.fg; font.pixelSize: 13 }
          Slider {
            fg: win.pal.fg; ac: win.pal.ac
            from: 0; to: 64
            value: win.margin
            suffix: "px"
            onPicked: v => win.svc.setMargin(win.cfg.edge, v)
          }
        }

        Text {
          textFormat: Text.PlainText
          text: "Icons: " + win.cfg.apps.length + " / " + win.maxApps
          color: Qt.alpha(win.pal.fg, 0.7)
          font.pixelSize: 12
        }
        Text {
          textFormat: Text.PlainText
          width: 260
          wrapMode: Text.WordWrap
          text: "Margin is shared by every dock on the " + win.cfg.edge + " edge. Omarchy bar: "
            + (win.svc.barInfo !== "" ? win.svc.barInfo : "not detected")
          color: Qt.alpha(win.pal.fg, 0.7)
          font.pixelSize: 12
        }
        Text {
          textFormat: Text.PlainText
          visible: win.svc.notice !== ""
          width: 260
          wrapMode: Text.WordWrap
          text: win.svc.notice
          color: "#ff8a80"
          font.pixelSize: 12
        }

        Row {
          spacing: 8
          Chips {
            fg: win.pal.fg; ac: win.pal.ac
            options: ["Add dock (" + win.svc.docks.length + "/" + win.svc.maxDocks + ")"]
            onPicked: { win.setOpen = false; win.svc.addDock(); }
          }
          Chips {
            fg: win.pal.fg; ac: win.pal.ac
            options: ["Remove this dock"]
            onPicked: { win.setOpen = false; win.svc.removeDock(win.idx); }
          }
        }
      }
    }
  }
}
