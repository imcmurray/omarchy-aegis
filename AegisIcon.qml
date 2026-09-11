import QtQuick
import QtQuick.Effects
import qs.Commons

// Google Material Symbols "encrypted_add" (Apache-2.0), painted in the
// Omarchy theme foreground — not the Aegis site palette.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Image {
    id: mark
    anchors.fill: parent
    source: Qt.resolvedUrl("encrypted_add.svg")
    fillMode: Image.PreserveAspectFit
    sourceSize.width: Math.max(24, Math.round(root.width * 2))
    sourceSize.height: Math.max(24, Math.round(root.height * 2))
    visible: false
    layer.enabled: true
    asynchronous: true
  }

  MultiEffect {
    anchors.fill: mark
    source: mark
    colorization: 1.0
    colorizationColor: root.color
  }
}
