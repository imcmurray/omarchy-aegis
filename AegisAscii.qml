import QtQuick
import qs.Commons

// Logo above a full-width AEGIS wordmark. Shrinks to the height the
// overlay gives it so Unlock / Import stay on screen.
Item {
  id: root

  property color color: Color.foreground
  property color scanColor: Color.accent
  property bool active: false

  property bool shown: false
  property real wordOpacity: 0
  property real markOpacity: 0

  readonly property int wordBand: Math.max(Style.space(28), Math.min(Style.space(56), Math.round(height * 0.34)))
  readonly property int markSize: {
    var leftover = height - wordBand - Style.space(10)
    if (leftover < Style.space(40)) leftover = Style.space(40)
    var cap = Math.min(Math.round(width * 0.38), Style.space(110))
    return Math.max(Style.space(40), Math.min(leftover, cap))
  }

  implicitWidth: Style.space(200)
  implicitHeight: Style.space(140)

  function restart() {
    showAnim.stop()
    pulseAnim.stop()
    shown = false
    wordOpacity = 0
    markOpacity = 0
    if (active) showAnim.start()
  }

  onActiveChanged: restart()
  Component.onCompleted: if (active) restart()

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    spacing: Style.space(8)

    AegisIcon {
      id: mark
      iconSize: root.markSize
      color: root.scanColor
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: root.markOpacity
      scale: root.shown ? 1 : 0.88
      transformOrigin: Item.Center
      Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
    }

    Text {
      id: word
      width: parent.width
      height: root.wordBand
      textFormat: Text.PlainText
      text: "AEGIS"
      color: root.color
      opacity: root.wordOpacity
      font.family: Style.font.family
      font.pixelSize: root.wordBand
      font.letterSpacing: Style.space(10)
      font.bold: true
      fontSizeMode: Text.Fit
      minimumPixelSize: Style.space(22)
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      wrapMode: Text.NoWrap
    }
  }

  SequentialAnimation {
    id: showAnim
    PropertyAction { target: root; property: "shown"; value: true }
    NumberAnimation { target: root; property: "markOpacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "wordOpacity"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 200 }
    ScriptAction { script: if (root.active) pulseAnim.start() }
  }

  SequentialAnimation {
    id: pulseAnim
    loops: Animation.Infinite
    running: false
    NumberAnimation { target: root; property: "markOpacity"; to: 0.6; duration: 1200; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "markOpacity"; to: 1; duration: 1200; easing.type: Easing.InOutSine }
  }
}
