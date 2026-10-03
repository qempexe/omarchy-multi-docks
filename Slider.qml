import QtQuick

Item {
  id: s
  property int from: 1
  property int to: 64
  property int value: 30
  property color fg: "#e0e0e0"
  property color ac: "#ffffff"
  property int trackWidth: 130
  property string suffix: ""
  signal picked(int v)

  implicitWidth: trackWidth + 8 + 42
  implicitHeight: 20

  readonly property real frac: Math.max(0, Math.min(1, (value - from) / Math.max(1, to - from)))

  function setFromFrac(f) {
    const v = Math.round(from + Math.max(0, Math.min(1, f)) * (to - from));
    if (v !== value) picked(v);
  }

  Rectangle {
    id: track
    x: 0
    y: (parent.height - height) / 2
    width: s.trackWidth
    height: 6
    radius: 3
    color: Qt.alpha(s.fg, 0.16)
  }
  Rectangle {
    x: 0
    y: track.y
    width: s.trackWidth * s.frac
    height: 6
    radius: 3
    color: Qt.alpha(s.ac, 0.65)
  }
  Rectangle {
    x: s.trackWidth * s.frac - width / 2
    y: (parent.height - height) / 2
    width: 12
    height: 12
    radius: 6
    color: s.fg
  }
  Text {
    textFormat: Text.PlainText
    x: s.trackWidth + 8
    y: (parent.height - height) / 2
    text: s.value + s.suffix
    color: s.fg
    font.pixelSize: 12
    width: 42
    horizontalAlignment: Text.AlignRight
  }

  MouseArea {
    anchors.fill: parent
    onPressed: m => s.setFromFrac(m.x / s.trackWidth)
    onPositionChanged: m => { if (pressed) s.setFromFrac(m.x / s.trackWidth); }
    onWheel: w => {
      const step = (w.modifiers & Qt.ShiftModifier) ? 5 : 1;
      const v = Math.max(s.from, Math.min(s.to, s.value + (w.angleDelta.y > 0 ? step : -step)));
      if (v !== s.value) s.picked(v);
    }
  }
}
