import QtQuick
import qs.Commons

// Logo, full-width AEGIS, then a decrypt of POST-QUANTUM READY.
Item {
  id: root

  property color color: Color.foreground
  property color scanColor: Color.accent
  property bool active: false

  property bool shown: false
  property real wordOpacity: 0
  property real markOpacity: 0
  property real tagOpacity: 0
  property int tagDone: 0
  property string tagText: ""

  readonly property string tagTarget: "POST-QUANTUM READY"
  readonly property string tagGlyphs: "01█▓▒░▀▄"

  readonly property int tagBand: Math.max(Style.space(16), Math.min(Style.space(22), Math.round(height * 0.12)))
  readonly property int wordBand: Math.max(Style.space(24), Math.min(Style.space(52), Math.round(height * 0.28)))
  readonly property int markSize: {
    var leftover = height - wordBand - tagBand - Style.space(16)
    if (leftover < Style.space(36)) leftover = Style.space(36)
    var cap = Math.min(Math.round(width * 0.36), Style.space(100))
    return Math.max(Style.space(36), Math.min(leftover, cap))
  }

  implicitWidth: Style.space(200)
  implicitHeight: Style.space(160)

  function scrambleTail() {
    var left = tagTarget.length - tagDone
    if (left <= 0) return ""
    var n = Math.min(4, left)
    var out = ""
    for (var i = 0; i < n; i++) {
      var t = tagTarget.charAt(tagDone + i)
      if (t === " ") out += " "
      else out += tagGlyphs.charAt(Math.floor(Math.random() * tagGlyphs.length))
    }
    return out
  }

  function restart() {
    showAnim.stop()
    pulseAnim.stop()
    decryptTimer.stop()
    shown = false
    wordOpacity = 0
    markOpacity = 0
    tagOpacity = 0
    tagDone = 0
    tagText = ""
    if (active) showAnim.start()
  }

  onActiveChanged: restart()
  Component.onCompleted: if (active) restart()

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    spacing: Style.space(6)

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

    Text {
      id: tag
      width: parent.width
      height: root.tagBand
      textFormat: Text.PlainText
      text: root.tagText
      color: root.scanColor
      opacity: root.tagOpacity
      font.family: Style.font.family
      font.pixelSize: Math.max(Style.space(11), Math.round(root.tagBand * 0.85))
      font.letterSpacing: Style.space(3)
      fontSizeMode: Text.HorizontalFit
      minimumPixelSize: Style.space(10)
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
    NumberAnimation { target: root; property: "tagOpacity"; from: 0; to: 1; duration: 120 }
    ScriptAction { script: if (root.active) decryptTimer.start() }
  }

  Timer {
    id: decryptTimer
    interval: 28
    repeat: true
    running: false
    onTriggered: {
      if (root.tagDone < root.tagTarget.length) {
        root.tagDone += 1
        root.tagText = root.tagTarget.substring(0, root.tagDone) + root.scrambleTail()
        return
      }
      root.tagText = root.tagTarget
      stop()
      if (root.active) pulseAnim.start()
    }
  }

  SequentialAnimation {
    id: pulseAnim
    loops: Animation.Infinite
    running: false
    NumberAnimation { target: root; property: "markOpacity"; to: 0.6; duration: 1200; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "markOpacity"; to: 1; duration: 1200; easing.type: Easing.InOutSine }
  }
}
