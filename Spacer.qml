import QtQuick
import Quickshell
import Quickshell.Wayland

// Invisible 1x1 window that carries the exclusive zone for one edge of one
// monitor. The compositor only honours a zone from a window anchored to a
// single edge, so the docks themselves cannot do it.
PanelWindow {
  id: sp

  required property var svc
  required property string edge

  readonly property int zone: svc.edgeZone(screen ? screen.name : "", edge)

  anchors {
    top: sp.edge === "top"
    bottom: sp.edge === "bottom"
    left: sp.edge === "left"
    right: sp.edge === "right"
  }
  implicitWidth: 1
  implicitHeight: 1
  exclusionMode: sp.zone > 0 ? ExclusionMode.Normal : ExclusionMode.Ignore
  exclusiveZone: sp.zone
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "omarchy-dock-reserve"
}
