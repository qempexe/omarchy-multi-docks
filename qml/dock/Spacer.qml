import QtQuick
import Quickshell
import Quickshell.Wayland

// invisible 1x1 window carrying the exclusive zone for one edge of one monitor.
// the compositor only honours zones from single-edge windows, so the docks can't do it
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
