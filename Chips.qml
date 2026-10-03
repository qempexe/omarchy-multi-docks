import QtQuick

Row {
  id: r
  property var options: []
  property string value: ""
  property color fg: "#e0e0e0"
  property color ac: "#ffffff"
  signal picked(string v)

  spacing: 4

  Repeater {
    model: r.options

    delegate: Rectangle {
      id: chip
      required property string modelData
      width: label.implicitWidth + 16
      height: 24
      radius: 8
      color: modelData === r.value ? Qt.alpha(r.ac, 0.3) : Qt.alpha(r.fg, mouse.containsMouse ? 0.18 : 0.08)

      Text {
        id: label
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: chip.modelData
        color: r.fg
        font.pixelSize: 12
      }

      MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: r.picked(chip.modelData)
      }
    }
  }
}
