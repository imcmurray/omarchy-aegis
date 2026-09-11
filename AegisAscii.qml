import QtQuick
import qs.Commons

// Wordmark + the real encrypted_add SVG (not a pixel blob).
Item {
  id: root

  property color color: Color.foreground
  property color scanColor: Color.accent
  property bool active: false
  property int letterSize: Math.max(Style.space(36), Math.round(Style.font.heading * 2.4))
  property int markSize: Math.round(letterSize * 1.15)

  property bool shown: false

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight
  width: parent ? parent.width : implicitWidth
  height: implicitHeight

  function restart() {
    showAnim.stop()
    pulseAnim.stop()
    shown = false
    mark.opacity = 1
    if (active) showAnim.start()
  }

  onActiveChanged: restart()
  Component.onCompleted: if (active) restart()

  Row {
    id: row
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.space(16)
    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : 0.94
    transformOrigin: Item.Center

    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    Text {
      textFormat: Text.PlainText
      text: "AEGIS"
      color: root.color
      font.family: Style.font.family
      font.pixelSize: root.letterSize
      font.letterSpacing: Style.space(3)
      font.bold: true
      verticalAlignment: Text.AlignVCenter
      height: root.markSize
    }

    AegisIcon {
      id: mark
      iconSize: root.markSize
      color: root.scanColor
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  SequentialAnimation {
    id: showAnim
    PropertyAction { target: root; property: "shown"; value: true }
    PauseAnimation { duration: 400 }
    ScriptAction { script: if (root.active) pulseAnim.start() }
  }

  SequentialAnimation {
    id: pulseAnim
    loops: Animation.Infinite
    running: false
    NumberAnimation { target: mark; property: "opacity"; to: 0.55; duration: 1100; easing.type: Easing.InOutSine }
    NumberAnimation { target: mark; property: "opacity"; to: 1; duration: 1100; easing.type: Easing.InOutSine }
  }
}
