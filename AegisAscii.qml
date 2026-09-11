import QtQuick
import qs.Commons

// Omarchy-style block mark: line reveal, then a slow scan.
Item {
  id: root

  property color color: Color.foreground
  property color scanColor: Color.accent
  property int pixelSize: Math.max(8, Style.font.caption)

  readonly property var lines: [
    "    ▄▄██████▄▄",
    "  ▄██▀▀      ▀▀██▄",
    " ███    ▄██▄    ███",
    " ███    ████    ███",
    " ███     ██▄▄▄▄▄███",
    " ▀███     ▀▀   ███",
    "  ▀███▄      ▄█████",
    "    ▀██▄    ███▀▀",
    "      ▀▀    ███"
  ]

  property int revealed: 0
  property int scanRow: -1
  property int scanTick: 0

  implicitWidth: col.implicitWidth
  implicitHeight: col.implicitHeight
  width: parent ? parent.width : implicitWidth

  function restart() {
    revealTimer.stop()
    scanTimer.stop()
    revealed = 0
    scanRow = -1
    if (visible) revealTimer.start()
  }

  onVisibleChanged: restart()
  Component.onCompleted: if (visible) restart()

  Column {
    id: col
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 0

    Repeater {
      model: root.lines
      Text {
        required property int index
        required property string modelData
        textFormat: Text.PlainText
        text: modelData
        color: index === root.scanRow ? root.scanColor : root.color
        opacity: index < root.revealed ? 1 : 0
        font.family: Style.font.family
        font.pixelSize: root.pixelSize
        lineHeight: 1.0
        wrapMode: Text.NoWrap
        horizontalAlignment: Text.AlignHCenter
        Behavior on opacity { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 140 } }
      }
    }
  }

  Timer {
    id: revealTimer
    interval: 42
    repeat: true
    onTriggered: {
      if (root.revealed < root.lines.length) {
        root.revealed += 1
        return
      }
      stop()
      scanTimer.start()
    }
  }

  Timer {
    id: scanTimer
    interval: 200
    repeat: true
    running: false
    onTriggered: {
      var n = root.lines.length
      var cycle = n + 6
      var i = (root.scanRow < 0 ? 0 : root.scanRow + 1)
      if (i >= cycle) i = 0
      root.scanRow = i < n ? i : -1
    }
  }
}
