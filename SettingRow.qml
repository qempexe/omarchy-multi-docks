import QtQuick
import QtQuick.Layouts
import "Effects.js" as Fx

// One setting in the dock settings: a label and a plain-language hint on the
// left, the value / switch / reset on the right, and the control underneath.
//
//   kind  enum    segmented control (<= 4 options) or wrapping chips
//         bool    switch
//         int     slider with - / + nudge buttons and a notch at the default
//         effect  tiles, each one plays its auto-hide effect on a tiny dock
//         scheme  tiles, each one draws a tiny dock in that color mode
//         palette Background / Text / Accent, each from swatches or a hex.
//                 `value` is { key: color }, edits come as { key, value },
//                 the reset arrow sends { reset: true }
//
// Text and soft tints come from `fg`; selected / filled parts use `accent`.
// Numbers are shown plain, with no px / ms / % suffix.
Item {
  id: root

  property string label: ""
  property string hint: ""
  property string kind: "enum"
  property var options: []
  property var labels: ({})          // option -> friendly text
  property var value: null
  property var defaultValue: null
  property real min: 0
  property real max: 100
  property real step: 1
  property bool dimmed: false        // setting has no effect right now
  property bool live: true           // effect tiles animate only while shown
  property color fg: "white"
  property color accent: fg
  property color bg: "black"         // text on top of an accent fill
  property color panel: "black"      // opaque panel background
  property string fontFamily: "monospace"
  property var schemes: ({})         // scheme -> { bg, fg, ac } for the scheme tiles
  property var presets: []           // swatches for kind "palette"
  property var targets: []           // palette: [{ key, label }]
  property int target: 0             // palette: which one is being edited
  readonly property string targetKey: targets.length > target ? targets[target].key : ""
  function colorOf(k) { return (value && value[k]) ? String(value[k]) : "#000000" }

  signal edited(var v)

  function tint(a) { return Qt.rgba(fg.r, fg.g, fg.b, a) }
  function accentTint(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }
  function str(v) { return (v === null || v === undefined) ? "" : String(v) }
  function same(a, b) { return str(a) === str(b) }
  function labelFor(o) { return labels[o] !== undefined ? labels[o] : String(o) }
  function clamp01(t) { return Math.max(0, Math.min(1, t)) }
  function nudge(dir) {
    const cur = Number(value);
    const v = Math.max(min, Math.min(max, cur + dir * step));
    if (v !== cur) edited(v);
  }

  readonly property bool boolValue: value === true || value === "true"
  readonly property bool atDefault: {
    if (defaultValue === null) return true;
    if (kind === "palette")
      return targets.every(t => String(colorOf(t.key)).toLowerCase() === String(defaultValue[t.key]).toLowerCase());
    return same(value, defaultValue);
  }
  readonly property real span: Math.max(1e-9, max - min)
  readonly property real frac: clamp01((Number(value) - min) / span)
  readonly property real defFrac: clamp01((Number(defaultValue) - min) / span)
  readonly property bool useSegments: kind === "enum" && options.length <= 4
  function validHex(t) { return /^#[0-9a-fA-F]{6}$/.test(String(t)) }

  implicitWidth: 400
  implicitHeight: col.implicitHeight
  opacity: dimmed ? 0.4 : 1.0
  Behavior on opacity { NumberAnimation { duration: 140 } }

  // Small square button used for - / + and reset.
  component IconButton: Rectangle {
    id: btn
    property string glyph: ""
    property color ink: "white"
    signal clicked()
    implicitWidth: 22
    implicitHeight: 22
    radius: 6
    color: area.containsMouse ? Qt.rgba(ink.r, ink.g, ink.b, 0.18) : Qt.rgba(ink.r, ink.g, ink.b, 0.08)
    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: btn.glyph
      color: btn.ink
      font.family: root.fontFamily
      font.pixelSize: 11
    }
    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.clicked()
    }
  }

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 9

    // ---- head: label + hint | stepper / switch / reset ----------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: root.label
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: 10
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }
        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: root.hint
          visible: root.hint !== ""
          color: root.fg
          opacity: 0.55
          font.family: root.fontFamily
          font.pixelSize: 8
          wrapMode: Text.Wrap
        }
      }

      RowLayout {
        visible: root.kind === "int"
        spacing: 4
        Layout.alignment: Qt.AlignTop

        IconButton { glyph: "−"; ink: root.fg; onClicked: root.nudge(-1) }
        Text {
          textFormat: Text.PlainText
          Layout.preferredWidth: 34
          horizontalAlignment: Text.AlignHCenter
          text: root.str(root.value)
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: 10
          font.weight: Font.DemiBold
        }
        IconButton { glyph: "+"; ink: root.fg; onClicked: root.nudge(1) }
      }

      Rectangle {
        visible: root.kind === "bool"
        Layout.alignment: Qt.AlignTop
        implicitWidth: 40
        implicitHeight: 22
        radius: 11
        color: root.boolValue ? root.accent : root.tint(0.14)
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
          width: 16; height: 16; radius: 8
          y: 3
          x: root.boolValue ? parent.width - width - 3 : 3
          color: root.boolValue ? root.bg : root.tint(0.75)
          Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.edited(!root.boolValue)
        }
      }

      // back to the default, only once it differs
      IconButton {
        visible: !root.atDefault
        Layout.alignment: Qt.AlignTop
        glyph: "↺"
        ink: root.fg
        onClicked: root.edited(root.kind === "palette" ? { reset: true } : root.defaultValue)
      }
    }

    // ---- enum: segmented control -----------------------------------------------
    Rectangle {
      visible: root.useSegments
      Layout.fillWidth: true
      implicitHeight: 28
      radius: 7
      color: root.tint(0.06)
      border.width: 1
      border.color: root.tint(0.08)

      RowLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 2

        Repeater {
          model: root.useSegments ? root.options : []
          delegate: Rectangle {
            required property var modelData
            readonly property bool on: root.same(root.value, modelData)
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            radius: 6
            color: on ? root.accent : (seg.containsMouse ? root.tint(0.10) : "transparent")
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              width: parent.width - 8
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: root.labelFor(parent.modelData)
              color: parent.on ? root.bg : root.fg
              font.family: root.fontFamily
              font.pixelSize: 9
              font.weight: parent.on ? Font.DemiBold : Font.Normal
            }
            MouseArea {
              id: seg
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.edited(parent.modelData)
            }
          }
        }
      }
    }

    // ---- enum with many options: wrapping chips -------------------------------------
    Flow {
      visible: root.kind === "enum" && !root.useSegments
      Layout.fillWidth: true
      spacing: 6

      Repeater {
        model: (root.kind === "enum" && !root.useSegments) ? root.options : []
        delegate: Rectangle {
          required property var modelData
          readonly property bool on: root.same(root.value, modelData)
          implicitWidth: chipText.implicitWidth + 20
          implicitHeight: 26
          radius: 6
          color: on ? root.accent : (chipArea.containsMouse ? root.tint(0.12) : root.tint(0.07))
          Text {
            id: chipText
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: root.labelFor(parent.modelData)
            color: parent.on ? root.bg : root.fg
            font.family: root.fontFamily
            font.pixelSize: 9
          }
          MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.edited(parent.modelData)
          }
        }
      }
    }

    // ---- effect: tiles that play the real effect ---------------------------------
    GridLayout {
      visible: root.kind === "effect"
      Layout.fillWidth: true
      columns: 4
      columnSpacing: 8
      rowSpacing: 8

      Repeater {
        model: root.kind === "effect" ? root.options : []
        delegate: Rectangle {
          id: tile
          required property var modelData
          readonly property bool on: root.same(root.value, modelData)
          // 0 = shown, 1 = hidden, looping.
          property real t: 0
          readonly property var fx: Fx.state(modelData, t, 9)

          Layout.preferredWidth: Math.floor((root.width - 24) / 4)
          Layout.preferredHeight: 58
          radius: 8
          color: on ? root.accentTint(0.16) : (tileArea.containsMouse ? root.tint(0.10) : root.tint(0.05))
          border.width: on ? 1.5 : 1
          border.color: on ? root.accent : root.tint(0.10)
          Behavior on color { ColorAnimation { duration: 100 } }

          SequentialAnimation on t {
            running: root.live && root.visible && root.kind === "effect"
            loops: Animation.Infinite
            PauseAnimation { duration: 650 }
            NumberAnimation {
              to: 1; duration: 420
              easing.type: Fx.springy(tile.modelData) ? Easing.InBack : Easing.InCubic
            }
            PauseAnimation { duration: 450 }
            NumberAnimation {
              to: 0; duration: 420
              easing.type: Fx.springy(tile.modelData) ? Easing.OutBack : Easing.OutCubic
              easing.overshoot: tile.modelData === "pop" ? 2.2 : 1.7
            }
          }

          // a little screen with its dock on the bottom edge
          Rectangle {
            id: screenBox
            anchors.horizontalCenter: parent.horizontalCenter
            y: 7
            width: parent.width - 18
            height: 28
            radius: 4
            color: root.tint(0.04)
            border.width: 1
            border.color: root.tint(0.10)
            clip: true

            Rectangle {
              id: miniDock
              width: 38
              height: 10
              radius: 3
              x: (screenBox.width - width) / 2
              y: screenBox.height - height - 3 + tile.fx.off
              opacity: Math.max(0, Math.min(1, tile.fx.opacity))
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.22 * Math.max(0, Math.min(1, tile.fx.bg)))
              transform: Scale {
                origin.x: miniDock.width / 2
                origin.y: tile.fx.center ? miniDock.height / 2 : miniDock.height
                xScale: tile.fx.scale
                yScale: tile.fx.scale * tile.fx.fold
              }

              Row {
                anchors.centerIn: parent
                spacing: 3
                Repeater {
                  model: 5
                  delegate: Rectangle {
                    required property int index
                    readonly property real w: tile.modelData === "wave"
                      ? Math.max(0, Math.min(1, tile.t * 1.8 - (4 - index) * 0.2)) : 0
                    width: 5; height: 5; radius: 1.5
                    color: tile.on ? root.accent : root.fg
                    opacity: 1 - w
                    scale: 1 - 0.6 * w
                  }
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: root.labelFor(tile.modelData)
            color: root.fg
            opacity: tile.on ? 1.0 : 0.7
            font.family: root.fontFamily
            font.pixelSize: 8
            font.weight: tile.on ? Font.DemiBold : Font.Normal
          }
          MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.edited(tile.modelData)
          }
        }
      }
    }

    // ---- scheme: tiles that draw a tiny dock in each color mode ---------------------
    GridLayout {
      visible: root.kind === "scheme"
      Layout.fillWidth: true
      columns: 4
      columnSpacing: 8
      rowSpacing: 8

      Repeater {
        model: root.kind === "scheme" ? root.options : []
        delegate: Rectangle {
          id: stile
          required property var modelData
          readonly property bool on: root.same(root.value, modelData)
          readonly property var sc: root.schemes[modelData] || ({ bg: "#161616", fg: "#e0e0e0", ac: "#ffffff" })
          readonly property bool byCategory: modelData === "category"

          Layout.preferredWidth: Math.floor((root.width - 24) / 4)
          Layout.preferredHeight: 58
          radius: 8
          color: on ? root.accentTint(0.16) : (stileArea.containsMouse ? root.tint(0.10) : root.tint(0.05))
          border.width: on ? 1.5 : 1
          border.color: on ? root.accent : root.tint(0.10)
          Behavior on color { ColorAnimation { duration: 100 } }

          // a little dock painted in that scheme
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 9
            width: parent.width - 22
            height: 22
            radius: 6
            color: stile.sc.bg
            border.width: 1
            border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)

            Row {
              anchors.centerIn: parent
              spacing: 4
              Repeater {
                model: 4
                delegate: Item {
                  required property int index
                  width: 9; height: 14
                  Rectangle {
                    width: 9; height: 9; radius: 2.5
                    color: Qt.alpha(stile.sc.fg, 0.55)
                  }
                  Rectangle {   // running dot: accent, or one hue per app
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 11
                    width: 3; height: 3; radius: 1.5
                    color: stile.byCategory ? Qt.hsla(index * 0.23 + 0.05, 0.55, 0.68, 1) : stile.sc.ac
                  }
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: root.labelFor(stile.modelData)
            color: root.fg
            opacity: stile.on ? 1.0 : 0.7
            font.family: root.fontFamily
            font.pixelSize: 8
            font.weight: stile.on ? Font.DemiBold : Font.Normal
          }
          MouseArea {
            id: stileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.edited(stile.modelData)
          }
        }
      }
    }

    // ---- palette: pick Background, Text or Accent, then a swatch or a hex -------------
    ColumnLayout {
      visible: root.kind === "palette"
      Layout.fillWidth: true
      spacing: 10

      // which color is being edited; each segment shows its current color
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 30
        radius: 7
        color: root.tint(0.06)
        border.width: 1
        border.color: root.tint(0.08)

        RowLayout {
          anchors.fill: parent
          anchors.margins: 3
          spacing: 2

          Repeater {
            model: root.kind === "palette" ? root.targets : []
            delegate: Rectangle {
              required property var modelData
              required property int index
              readonly property bool on: index === root.target
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.fillHeight: true
              radius: 6
              color: on ? root.accent : (tgArea.containsMouse ? root.tint(0.10) : "transparent")
              Behavior on color { ColorAnimation { duration: 100 } }

              Row {
                anchors.centerIn: parent
                spacing: 6
                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 10; height: 10; radius: 5
                  color: root.colorOf(parent.parent.modelData.key)
                  border.width: 1
                  border.color: parent.parent.on ? root.bg : root.tint(0.35)
                }
                Text {
                  textFormat: Text.PlainText
                  text: parent.parent.modelData.label
                  color: parent.parent.on ? root.bg : root.fg
                  font.family: root.fontFamily
                  font.pixelSize: 9
                  font.weight: parent.parent.on ? Font.DemiBold : Font.Normal
                }
              }
              MouseArea {
                id: tgArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.target = parent.index; hexField.focus = false; }
              }
            }
          }
        }
      }

      // swatches
      GridLayout {
        Layout.fillWidth: true
        columns: 8
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
          model: root.kind === "palette" ? root.presets : []
          delegate: Rectangle {
            required property var modelData
            readonly property bool on: root.colorOf(root.targetKey).toLowerCase() === String(modelData).toLowerCase()
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignHCenter
            radius: 12
            color: modelData
            border.width: on ? 2 : 1
            border.color: on ? root.accent : root.tint(0.2)
            scale: swArea.containsMouse ? 1.12 : 1.0
            Behavior on scale { NumberAnimation { duration: 90 } }
            MouseArea {
              id: swArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.edited({ key: root.targetKey, value: String(parent.modelData).toLowerCase() })
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
          width: 28; height: 28; radius: 6
          color: root.validHex(hexField.shown) ? hexField.shown : "transparent"
          border.width: 1
          border.color: root.tint(0.25)
        }

        // Hex field. Not a TextInput on purpose: a TextInput keeps reading the
        // clipboard in the background. This one only takes typed hex digits.
        Rectangle {
          Layout.preferredWidth: 110
          implicitHeight: 28
          radius: 6
          color: root.tint(0.06)
          border.width: 1
          border.color: hexField.activeFocus ? root.accent : (hexField.bad ? "#e0604c" : root.tint(0.12))

          Item {
            id: hexField
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            activeFocusOnTab: true
            property string draft: ""
            readonly property string current: root.colorOf(root.targetKey)
            readonly property string shown: activeFocus ? draft : current
            readonly property bool bad: activeFocus && draft.length === 7 && !root.validHex(draft)
            function commit() {
              if (root.validHex(draft) && draft.toLowerCase() !== current.toLowerCase())
                root.edited({ key: root.targetKey, value: draft.toLowerCase() });
            }
            onActiveFocusChanged: { if (activeFocus) draft = current; else commit(); }

            Text {
              id: hexText
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: hexField.shown
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: 10
            }
            Rectangle {   // caret
              visible: hexField.activeFocus
              x: hexText.implicitWidth + 1
              anchors.verticalCenter: parent.verticalCenter
              width: 1; height: 12
              color: root.fg
            }

            Keys.onPressed: e => {
              if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                commit();
                e.accepted = true;
              } else if (e.key === Qt.Key_Backspace) {
                draft = draft.slice(0, -1);
                e.accepted = true;
              } else if (/^[0-9a-fA-F#]$/.test(e.text) && draft.length < 7) {
                if (e.text === "#") { if (draft === "") draft = "#"; }
                else draft = (draft === "" ? "#" : draft) + e.text;
                e.accepted = true;
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onClicked: hexField.forceActiveFocus()
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: "Type a hex like #d4a35a, Enter to use it."
          color: root.fg
          opacity: 0.4
          font.family: root.fontFamily
          font.pixelSize: 8
          wrapMode: Text.Wrap
        }
      }
    }

    // ---- int: slider -------------------------------------------------------------
    ColumnLayout {
      visible: root.kind === "int"
      Layout.fillWidth: true
      spacing: 1

      Item {
        id: slider
        Layout.fillWidth: true
        implicitHeight: 22
        readonly property real knob: 16

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: 6
          radius: 3
          color: root.tint(0.12)

          Rectangle {
            width: handle.x + handle.width / 2
            height: parent.height
            radius: parent.radius
            color: root.accent
          }
        }
        // notch where the default sits
        Rectangle {
          visible: root.defaultValue !== null
          width: 2; height: 12; radius: 1
          x: (slider.width - slider.knob) * root.defFrac + slider.knob / 2 - 1
          anchors.verticalCenter: parent.verticalCenter
          color: root.tint(0.35)
        }
        Rectangle {
          id: handle
          width: slider.knob; height: slider.knob; radius: slider.knob / 2
          x: (slider.width - width) * root.frac
          anchors.verticalCenter: parent.verticalCenter
          color: root.accent
          border.width: 3
          border.color: root.panel
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          function apply(mx) {
            const room = Math.max(1, slider.width - slider.knob);
            const t = Math.max(0, Math.min(1, (mx - slider.knob / 2) / room));
            let v = root.min + t * (root.max - root.min);
            v = Math.round((v - root.min) / root.step) * root.step + root.min;
            v = Math.max(root.min, Math.min(root.max, v));
            // only real changes, so dragging does not rewrite the config each pixel
            if (v !== Number(root.value)) root.edited(v);
          }
          onPressed: m => apply(m.x)
          onPositionChanged: m => { if (pressed) apply(m.x); }
          onWheel: w => root.nudge(w.angleDelta.y > 0 ? ((w.modifiers & Qt.ShiftModifier) ? 5 : 1)
                                                      : ((w.modifiers & Qt.ShiftModifier) ? -5 : -1))
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Text {
          textFormat: Text.PlainText
          text: root.str(root.min)
          color: root.fg; opacity: 0.4
          font.family: root.fontFamily; font.pixelSize: 8
        }
        Item { Layout.fillWidth: true }
        Text {
          textFormat: Text.PlainText
          text: root.str(root.max)
          color: root.fg; opacity: 0.4
          font.family: root.fontFamily; font.pixelSize: 8
        }
      }
    }
  }
}
