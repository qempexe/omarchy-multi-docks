import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "Effects.js" as Fx

// Settings of one dock:
//
//   * Header card: which dock this is, Reset dock (asks twice), close, and a
//     live preview of the dock with its real icons, colors and shape.
//   * Four tabs: Place, Hide, Look, Docks (Alt+Left / Alt+Right to switch).
//   * Every setting is a SettingRow with a one-line hint and a reset arrow once
//     it differs from the default. Settings that do nothing right now are dimmed.
//   * Footer: Esc closes, changes apply instantly.
Item {
  id: root

  required property var dock          // the DockWindow
  required property var svc           // the Service
  property bool shown: false
  signal closeRequested()

  readonly property var cfg: dock.cfg
  readonly property var pal: dock.pal
  readonly property string fontFamily: "monospace"

  property int tab: 0
  property bool confirmReset: false
  property bool confirmRemove: false
  onShownChanged: if (!shown) { confirmReset = false; confirmRemove = false; }

  // ---- colors (from this dock's palette) ---------------------------------------------
  function luma(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }
  readonly property color ink: Qt.color(pal.fg)
  readonly property color accent: Qt.color(pal.ac)
  readonly property color panelSolid: Qt.color(pal.bg)
  readonly property color panelBg: Qt.rgba(panelSolid.r, panelSolid.g, panelSolid.b, 0.97)
  readonly property color inkOnFg: luma(accent) > 0.55 ? Qt.rgba(0.07, 0.07, 0.09, 1) : Qt.rgba(0.97, 0.97, 0.98, 1)
  function tint(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }

  // ---- what each tab holds ---------------------------------------------------------
  readonly property var tabs: ["Place", "Hide", "Look", "Docks"]
  readonly property bool manyScreens: dock.screenNames.length > 1 || cfg.monitor !== ""
  readonly property string scopeHint: "Applies to " + (dock.scope === "dock" ? "this dock only"
    : dock.scope === "all" ? "every dock" : "every dock on the " + cfg.edge + " edge" + (dock.screenNames.length > 1 ? " of this monitor" : "")) + ". Set with Apply to."

  readonly property var scopeRow: ({
    key: "scope", label: "Apply to", kind: "enum",
    hint: "How far the settings below reach. Resets to this dock when the shell restarts.",
    options: dock.scopeLabels, fallback: dock.scopeLabels[0]
  })

  readonly property var rows: [
    [
      { key: "monitor", label: "Monitor", kind: "enum", show: manyScreens,
        hint: dock.monitorMissing ? cfg.monitor + " is not connected, so the dock waits on the primary screen."
          : "Primary is the shell's first screen.",
        options: ["primary"].concat(dock.screenNames), fallback: "primary" },
      { key: "edge", label: "Edge", kind: "enum", hint: "Which side of the screen the dock lives on.",
        options: ["bottom", "top", "left", "right"], fallback: "bottom" },
      { key: "align", label: "Position", kind: "enum", hint: "Where it sits along that edge.",
        options: ["start", "center", "end"], fallback: "center" },
      { key: "stretch", label: "Full length", kind: "bool", hint: "Fill the whole slot instead of only fitting the icons.", fallback: false },
      { key: "margin", label: "Margin", kind: "int", min: 0, max: 64, fallback: 6,
        hint: "Gap to the screen edge or the Omarchy bar. Shared by every dock on the " + cfg.edge + " edge." }
    ],
    [
      { key: "autohide", label: "Auto-hide", kind: "bool", hint: "Get out of the way until the pointer touches the edge.", fallback: false },
      { key: "reserve", label: "Reserve space", kind: "bool", fallback: true,
        hint: "Keep tiled windows out of the dock's way. Shared by the docks on this edge; while auto-hidden the space is given back." },
      scopeRow,
      { key: "hideEffect", label: "Effect", kind: "effect", scoped: true, auto: true, fallback: "slide",
        hint: "How the dock leaves and comes back. " + scopeHint,
        options: svc.hideEffects, labels: Fx.labels },
      { key: "hideSpeed", label: "Speed", kind: "int", min: 60, max: 800, step: 20, scoped: true, auto: true, fallback: 180,
        hint: "Length of the animation. Lower is snappier." },
      { key: "showDelay", label: "Show delay", kind: "int", min: 0, max: 1000, step: 50, scoped: true, auto: true, fallback: 0,
        hint: "Wait this long on the edge before the dock appears, so brushing past does nothing." },
      { key: "hideDelay", label: "Hide delay", kind: "int", min: 0, max: 2000, step: 50, scoped: true, auto: true, fallback: 450,
        hint: "How long it stays after the pointer leaves." },
      { key: "revealStrip", label: "Reveal strip", kind: "int", min: 1, max: 12, scoped: true, auto: true, fallback: 3,
        hint: "Thickness of the edge zone that brings the dock back. Sliding effects leave this much of it showing." },
      { key: "edgeHint", label: "Edge hint", kind: "bool", scoped: true, auto: true, fallback: true,
        hint: "A small line on the edge marks a hidden dock, and turns red when an app asks for attention." }
    ],
    [
      scopeRow,
      { key: "style", label: "Colors", kind: "scheme", scoped: true, fallback: "theme",
        hint: "Follow theme matches your Omarchy theme live. Custom lets you choose the background, text and accent. Monochrome removes every hue. By category tints each app by its kind. " + scopeHint,
        options: svc.styles,
        labels: { theme: "Follow theme", custom: "Custom", monochrome: "Monochrome", category: "By category" } },
      { key: "customColors", label: "Custom colors", kind: "palette", scoped: true, show: cfg.style === "custom",
        hint: "Choose Background, Text or Accent, then pick a swatch or type a hex.",
        presets: svc.swatches,
        targets: [{ key: "customBg", label: "Background" }, { key: "customFg", label: "Text" }, { key: "accentColor", label: "Accent" }],
        fallback: { customBg: svc.defaults.customBg, customFg: svc.defaults.customFg, accentColor: svc.defaults.accentColor } },
      { key: "attention", label: "Attention", kind: "enum", scoped: true, fallback: "pulse",
        hint: "How an app that asks for attention shows up.",
        options: ["off", "dot", "pulse"], labels: { off: "Off", dot: "Dot", pulse: "Pulse" } },
      { key: "opacity", label: "Opacity", kind: "int", min: 1, max: 100, scoped: true, fallback: 90,
        hint: "Background opacity. Icons stay solid." },
      { key: "radius", label: "Corner radius", kind: "int", min: 1, max: 64, scoped: true, fallback: 16,
        hint: "Roundness of the dock." },
      { key: "outline", label: "Window outline", kind: "bool", scoped: true, fallback: false,
        hint: "Draw the edge of the dock, its popups and this panel in the accent color. Off keeps a plain line." },
      { key: "size", label: "Icon size", kind: "int", min: 1, max: 64, fallback: 44,
        hint: "Always this dock only. Refused when the icons would not fit." }
    ],
    []
  ]

  // What each color mode looks like, for the Colors tiles.
  readonly property var schemes: ({
    theme: svc.palette("theme"),
    custom: svc.palette({ style: "custom", customBg: cfg.customBg, customFg: cfg.customFg, accentColor: cfg.accentColor }),
    monochrome: svc.palette("monochrome"),
    category: svc.palette("theme")
  })

  function val(r) {
    switch (r.key) {
    case "scope": return dock.scopeLabels[dock.scopeIdx];
    case "monitor": return cfg.monitor === "" ? "primary" : cfg.monitor;
    case "margin": return dock.margin;
    case "customColors": return { customBg: cfg.customBg, customFg: cfg.customFg, accentColor: cfg.accentColor };
    default: return cfg[r.key];
    }
  }

  function setValue(r, v) {
    switch (r.key) {
    case "scope": dock.scopeIdx = Math.max(0, dock.scopeLabels.indexOf(v)); return;
    case "monitor": svc.patch(dock.idx, "monitor", v === "primary" ? "" : v); return;
    case "margin": svc.setMargin(cfg.edge, v); return;
    case "customColors":
      if (v.reset) {
        for (const k of ["customBg", "customFg", "accentColor"]) svc.patchScope(dock.idx, k, svc.defaults[k], dock.scope);
      } else svc.patchScope(dock.idx, v.key, v.value, dock.scope);
      return;
    }
    if (r.scoped) svc.patchScope(dock.idx, r.key, v, dock.scope);
    else svc.patch(dock.idx, r.key, v);
  }

  function stepTab(d) { tab = (tab + d + tabs.length) % tabs.length; }

  function resetDock() {
    if (!confirmReset) { confirmReset = true; confirmTimer.restart(); return; }
    confirmReset = false;
    svc.resetDock(dock.idx);
  }

  function removeDock() {
    if (!confirmRemove) { confirmRemove = true; confirmTimer.restart(); return; }
    confirmRemove = false;
    root.closeRequested();
    svc.removeDock(dock.idx);
  }

  Timer { id: confirmTimer; interval: 2500; onTriggered: { root.confirmReset = false; root.confirmRemove = false; } }

  Shortcut { sequence: "Escape"; context: Qt.WindowShortcut; onActivated: root.closeRequested() }
  Shortcut { sequence: "Alt+Right"; context: Qt.WindowShortcut; onActivated: root.stepTab(1) }
  Shortcut { sequence: "Alt+Left"; context: Qt.WindowShortcut; onActivated: root.stepTab(-1) }

  implicitWidth: 440
  implicitHeight: mainCol.implicitHeight + 28

  // Small text button used in the header and the Docks tab.
  component TextButton: Rectangle {
    id: tb
    property string text: ""
    property bool hot: false
    property bool wide: false
    signal clicked()
    implicitWidth: tbLabel.implicitWidth + 16
    implicitHeight: wide ? 30 : 24
    radius: 6
    color: hot ? root.accent : (tbArea.containsMouse ? root.tint(0.16) : root.tint(0.08))
    Behavior on color { ColorAnimation { duration: 100 } }
    Text {
      id: tbLabel
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: tb.text
      color: tb.hot ? root.inkOnFg : root.ink
      font.family: root.fontFamily
      font.pixelSize: 9
    }
    MouseArea {
      id: tbArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: tb.clicked()
    }
  }

  Rectangle {
    anchors.fill: parent
    color: root.panelBg
    border.color: root.cfg.outline ? Qt.alpha(root.accent, 0.8) : root.tint(0.14)
    border.width: 1
    radius: 12
    clip: true

    ColumnLayout {
      id: mainCol
      anchors.fill: parent
      anchors.margins: 14
      spacing: 12

      // ---- header: which dock + live preview ------------------------------------
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: headerCol.implicitHeight + 24
        radius: 10
        color: root.tint(0.05)
        border.width: 1
        border.color: root.tint(0.08)

        ColumnLayout {
          id: headerCol
          anchors.fill: parent
          anchors.margins: 12
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 2

              Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: "Dock " + (root.dock.idx + 1) + " of " + root.svc.docks.length
                color: root.ink
                font.family: root.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
              }
              Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: root.cfg.edge + " · " + root.cfg.align + " · " + root.dock.mon
                  + " · " + root.cfg.apps.length + "/" + root.dock.maxApps + " icons"
                  + (root.cfg.autohide ? " · " + Fx.labels[root.cfg.hideEffect] : "")
                color: root.ink
                opacity: 0.6
                font.family: root.fontFamily
                font.pixelSize: 9
                elide: Text.ElideRight
              }
            }

            TextButton {
              Layout.alignment: Qt.AlignTop
              text: root.confirmReset ? "Really reset?" : "Reset dock"
              hot: root.confirmReset
              onClicked: root.resetDock()
            }
            Rectangle {
              Layout.alignment: Qt.AlignTop
              implicitWidth: 24; implicitHeight: 24; radius: 6
              color: closeArea.containsMouse ? root.tint(0.16) : root.tint(0.08)
              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: "×"
                color: root.ink
                font.pixelSize: 15
              }
              MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
              }
            }
          }

          // live preview: the dock's own icons, colors, opacity and corners.
          // With many icons it scrolls sideways: mouse wheel, drag, or the bar.
          Rectangle {
            id: strip
            Layout.fillWidth: true
            readonly property bool overflow: previewFlick.contentWidth > previewFlick.width + 1
            implicitHeight: overflow ? 54 : 44
            radius: 8
            color: root.tint(0.04)
            clip: true
            Behavior on implicitHeight { NumberAnimation { duration: 120 } }

            function scrollBy(d) {
              const max = Math.max(0, previewFlick.contentWidth - previewFlick.width);
              previewFlick.contentX = Math.max(0, Math.min(max, previewFlick.contentX + d));
            }
            function scrollTo(frac) {
              const max = Math.max(0, previewFlick.contentWidth - previewFlick.width);
              previewFlick.contentX = Math.max(0, Math.min(max, frac * max));
            }

            Rectangle {
              id: pill
              anchors.horizontalCenter: parent.horizontalCenter
              y: 7
              width: Math.min(parent.width - 24, previewRow.implicitWidth + 16)
              height: 30
              radius: Math.min(root.cfg.radius, 15)
              color: Qt.alpha(root.pal.bg, root.cfg.opacity / 100)
              border.width: root.dock.anyUrgent ? 2 : 1
              border.color: root.dock.anyUrgent ? root.pal.hot : root.dock.edgeColor(0.14)
              clip: true

              Flickable {
                id: previewFlick
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                contentWidth: previewRow.implicitWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                interactive: strip.overflow
                clip: true

                Row {
                  id: previewRow
                  y: (previewFlick.height - height) / 2
                  spacing: 6
                  Repeater {
                    model: root.cfg.apps
                    delegate: Item {
                      required property string modelData
                      readonly property var entry: { DesktopEntries.applications.values; return DesktopEntries.byId(modelData); }
                      readonly property string src: {
                        const n = (entry && entry.icon) ? entry.icon : modelData;
                        if (n.startsWith("/")) return "file://" + n;
                        return Quickshell.iconPath(n, true) || "";
                      }
                      width: 20; height: 20
                      IconImage {
                        anchors.fill: parent
                        visible: parent.src !== ""
                        source: parent.src
                      }
                      Rectangle {
                        anchors.fill: parent
                        visible: parent.src === ""
                        radius: 5
                        color: Qt.alpha(root.pal.fg, 0.15)
                      }
                    }
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: root.cfg.apps.length === 0 ? "No apps pinned yet  +" : "+"
                    color: root.pal.fg
                    opacity: 0.7
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }

              // soft fades where more icons are hidden
              Rectangle {
                visible: previewFlick.contentX > 1
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 1
                width: 22
                radius: parent.radius
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0.0; color: root.panelSolid }
                  GradientStop { position: 1.0; color: Qt.alpha(root.panelSolid, 0) }
                }
              }
              Rectangle {
                visible: previewFlick.contentX < previewFlick.contentWidth - previewFlick.width - 1
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 1
                width: 22
                radius: parent.radius
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0.0; color: Qt.alpha(root.panelSolid, 0) }
                  GradientStop { position: 1.0; color: root.panelSolid }
                }
              }
            }

            // scrollbar under the dock, only when it overflows
            Item {
              id: track
              visible: strip.overflow
              x: pill.x + 6
              y: pill.y + pill.height + 6
              width: pill.width - 12
              height: 8

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: root.tint(0.10)
              }
              Rectangle {
                readonly property real ratio: Math.min(1, previewFlick.width / Math.max(1, previewFlick.contentWidth))
                readonly property real pos: previewFlick.contentX / Math.max(1, previewFlick.contentWidth - previewFlick.width)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(24, track.width * ratio)
                height: trackArea.containsMouse || trackArea.pressed ? 6 : 4
                radius: height / 2
                x: (track.width - width) * Math.max(0, Math.min(1, pos))
                color: root.accent
                Behavior on height { NumberAnimation { duration: 90 } }
              }
              MouseArea {
                id: trackArea
                anchors.fill: parent
                anchors.topMargin: -4
                anchors.bottomMargin: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: m => strip.scrollTo(m.x / Math.max(1, track.width))
                onPositionChanged: m => { if (pressed) strip.scrollTo(m.x / Math.max(1, track.width)); }
              }
            }

            // mouse wheel scrolls sideways (either wheel direction)
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.NoButton
              enabled: strip.overflow
              onWheel: w => {
                const d = w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x;
                strip.scrollBy(-d * 0.6);
              }
            }
          }
        }
      }

      // ---- tabs ---------------------------------------------------------------------
      Item {
        Layout.fillWidth: true
        implicitHeight: 30

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 1
          color: root.tint(0.10)
        }

        RowLayout {
          anchors.fill: parent
          spacing: 0

          Repeater {
            model: root.tabs
            delegate: Item {
              required property string modelData
              required property int index
              readonly property bool on: index === root.tab
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.fillHeight: true

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: parent.modelData
                color: root.ink
                opacity: parent.on ? 1.0 : (tabArea.containsMouse ? 0.8 : 0.5)
                font.family: root.fontFamily
                font.pixelSize: 10
                font.weight: parent.on ? Font.DemiBold : Font.Normal
              }
              Rectangle {
                visible: parent.on
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
                radius: 1
                color: root.accent
              }
              MouseArea {
                id: tabArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.tab = parent.index
              }
            }
          }
        }
      }

      // ---- the active tab -------------------------------------------------------------
      Flickable {
        id: flick
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: card.implicitHeight
        contentWidth: width
        contentHeight: card.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Rectangle {
          id: card
          width: flick.width
          implicitHeight: rowsCol.implicitHeight + 8
          radius: 10
          color: root.tint(0.035)
          border.width: 1
          border.color: root.tint(0.07)

          ColumnLayout {
            id: rowsCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 4
            spacing: 0

            Repeater {
              model: root.rows[root.tab].filter(r => r.show !== false)

              delegate: ColumnLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 0

                Rectangle {
                  visible: parent.index > 0
                  Layout.fillWidth: true
                  implicitHeight: 1
                  color: root.tint(0.07)
                }

                SettingRow {
                  Layout.fillWidth: true
                  Layout.topMargin: 12
                  Layout.bottomMargin: 12

                  readonly property var r: parent.modelData
                  label: r.label
                  hint: r.hint || ""
                  kind: r.kind
                  options: r.options || []
                  labels: r.labels || ({})
                  presets: r.presets || []
                  targets: r.targets || []
                  schemes: root.schemes
                  min: r.min !== undefined ? r.min : 0
                  max: r.max !== undefined ? r.max : 100
                  step: r.step !== undefined ? r.step : 1
                  defaultValue: r.fallback !== undefined ? r.fallback : null
                  dimmed: !!r.auto && !root.cfg.autohide
                  live: root.shown
                  value: root.val(r)

                  fg: root.ink
                  accent: root.accent
                  bg: root.inkOnFg
                  panel: root.panelSolid
                  fontFamily: root.fontFamily

                  onEdited: v => root.setValue(r, v)
                }
              }
            }

            // ---- Docks tab -------------------------------------------------------------
            ColumnLayout {
              visible: root.tab === 3
              Layout.fillWidth: true
              Layout.topMargin: 12
              Layout.bottomMargin: 12
              spacing: 8

              Text {
                textFormat: Text.PlainText
                text: "All docks"
                color: root.ink
                font.family: root.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
              }
              Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: "Up to " + root.svc.maxDocks + " docks, " + root.svc.maxPerEdge + " per edge of each monitor. Right-click any dock to open its own settings."
                color: root.ink
                opacity: 0.55
                font.family: root.fontFamily
                font.pixelSize: 8
                wrapMode: Text.Wrap
              }

              // one line per dock, this one highlighted
              Repeater {
                model: root.svc.docks
                delegate: Rectangle {
                  required property var modelData
                  required property int index
                  readonly property bool me: index === root.dock.idx
                  Layout.fillWidth: true
                  implicitHeight: 34
                  radius: 8
                  color: me ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16) : root.tint(0.05)
                  border.width: me ? 1.5 : 1
                  border.color: me ? root.accent : root.tint(0.08)

                  Text {
                    textFormat: Text.PlainText
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Dock " + (parent.index + 1)
                    color: root.ink
                    font.family: root.fontFamily
                    font.pixelSize: 9
                    font.weight: parent.me ? Font.DemiBold : Font.Normal
                  }
                  Text {
                    textFormat: Text.PlainText
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.edge + " · " + root.svc.monOf(parent.modelData) + " · "
                      + parent.modelData.apps.length + " icons" + (parent.modelData.autohide ? " · " + Fx.labels[parent.modelData.hideEffect] : "")
                    color: root.ink
                    opacity: 0.6
                    font.family: root.fontFamily
                    font.pixelSize: 8
                  }
                }
              }

              RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                TextButton {
                  Layout.fillWidth: true
                  wide: true
                  text: "Add dock (" + root.svc.docks.length + "/" + root.svc.maxDocks + ")"
                  onClicked: { root.closeRequested(); root.svc.addDock(root.dock.idx); }
                }
                TextButton {
                  Layout.fillWidth: true
                  wide: true
                  visible: root.svc.docks.length > 1
                  text: root.confirmRemove ? "Really remove?" : "Remove this dock"
                  hot: root.confirmRemove
                  onClicked: root.removeDock()
                }
              }

              Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: "Omarchy bar: " + (root.svc.barInfoFor(root.dock.mon) !== "" ? root.svc.barInfoFor(root.dock.mon) : "not detected")
                color: root.ink
                opacity: 0.4
                font.family: root.fontFamily
                font.pixelSize: 8
                wrapMode: Text.Wrap
              }
            }

            // refused changes show up here, in every tab
            Text {
              textFormat: Text.PlainText
              visible: root.svc.notice !== ""
              Layout.fillWidth: true
              Layout.bottomMargin: 12
              text: root.svc.notice
              color: root.pal.hot
              font.family: root.fontFamily
              font.pixelSize: 9
              wrapMode: Text.Wrap
            }
          }
        }
      }

      // ---- footer -------------------------------------------------------------------
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Rectangle {
          implicitWidth: escLabel.implicitWidth + 10
          implicitHeight: 16
          radius: 4
          color: root.tint(0.08)
          Text {
            id: escLabel
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: "Esc"
            color: root.ink
            opacity: 0.75
            font.family: root.fontFamily
            font.pixelSize: 8
          }
        }
        Text {
          textFormat: Text.PlainText
          text: "close"
          color: root.ink
          opacity: 0.45
          font.family: root.fontFamily
          font.pixelSize: 8
        }
        Item { Layout.fillWidth: true }
        Text {
          textFormat: Text.PlainText
          text: "Changes apply instantly"
          color: root.ink
          opacity: 0.45
          font.family: root.fontFamily
          font.pixelSize: 8
        }
      }
    }
  }
}
