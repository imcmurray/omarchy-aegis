import QtQuick
import qs.Commons

// Logo above a full-width AEGIS wordmark. Passphrase sits below in the overlay.
Item {
  id: root

  property color color: Color.foreground
  property color scanColor: Color.accent
  property bool active: false

  property bool shown: false
  property real wordOpacity: 0
  property real markOpacity: 0

  readonly property int markSize: Math.max(Style.space(72), Math.round(width * 0.34))
  readonly property int letterSize: Math.max(Style.space(40), Math.round(width * 0.18))

  implicitWidth: width
  implicitHeight: col.implicitHeight
  width: parent ? parent.width : implicitWidth
  height: implicitHeight

  function restart() {
    showAnim.stop()
    pulseAnim.stop()
    shown = false
    wordOpacity = 0
    mark.opacity = 1
    if (active) showAnim.start()
  }

  onActiveChanged: restart()
  Component.onCompleted: if (active) restart()

  Column {
    id: col
    width: parent.width
    spacing: Style.space(12)

    AegisIcon {
      id: mark
      iconSize: root.markSize
      color: root.scanColor
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: root.shown ? mark.opacity : 0
      scale: root.shown ? 1 : 0.88
      transformOrigin: Item.Center
      Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
    }

    Text {
      id: word
      width: parent.width
      textFormat: Text.PlainText
      text: "AEGIS"
      color: root.color
      opacity: root.wordOpacity
      font.family: Style.font.family
      font.pixelSize: root.letterSize
      font.letterSpacing: Style.space(8)
      font.bold: true
      fontSizeMode: Text.HorizontalFit
      minimumPixelSize: Style.space(28)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.NoWrap
    }
  }

  SequentialAnimation {
    id: showAnim
    PropertyAction { target: root; property: "shown"; value: true }
    NumberAnimation { target: mark; property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "wordOpacity"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 200 }
    ScriptAction { script: if (root.active) pulseAnim.start() }
  }

  SequentialAnimation {
    id: pulseAnim
    loops: Animation.Infinite
    running: false
    NumberAnimation { target: mark; property: "opacity"; to: 0.6; duration: 1200; easing.type: Easing.InOutSine }
    NumberAnimation { target: mark; property: "opacity"; to: 1; duration: 1200; easing.type: Easing.InOutSine }
  }
}
