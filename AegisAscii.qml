import QtQuick
import qs.Commons

// Pixel Aegis mark (shield + keyhole + plus). Reveal on open, then a
// visible accent scan. Driven by `active`, not Item.visible (parents stay
// "visible" while the overlay is closed).
Item {
  id: root

  property color color: Color.foreground
  property color scanColor: Color.accent
  property bool active: false
  property int cell: Style.space(5)

  // 1 = filled. Shield on the left, plus on the right.
  readonly property var rows: [
    "0011111110000100",
    "0111111111000100",
    "1100000001101111",
    "1100011101100100",
    "1100011101100100",
    "1100001001100000",
    "1110000001100000",
    "0111000011000000",
    "0011100111111000",
    "0001100000110000"
  ]

  property int revealed: 0
  property int scanRow: -1
  property int scanTick: 0
  property int filledCount: 0

  readonly property int cols: rows[0].length
  readonly property int rowCount: rows.length

  implicitWidth: cols * cell
  implicitHeight: rowCount * cell
  width: parent ? parent.width : implicitWidth
  height: implicitHeight

  function isOn(r, c) {
    return rows[r].charAt(c) === "1"
  }

  function fillIndex(r, c) {
    var n = 0
    for (var y = 0; y < rowCount; y++) {
      for (var x = 0; x < cols; x++) {
        if (!isOn(y, x)) continue
        if (y === r && x === c) return n
        n++
      }
    }
    return -1
  }

  function countFilled() {
    var n = 0
    for (var y = 0; y < rowCount; y++) {
      for (var x = 0; x < cols; x++) {
        if (isOn(y, x)) n++
      }
    }
    return n
  }

  function restart() {
    revealTimer.stop()
    scanTimer.stop()
    revealed = 0
    scanRow = -1
    scanTick = 0
    filledCount = countFilled()
    if (active) revealTimer.start()
  }

  onActiveChanged: restart()
  Component.onCompleted: {
    filledCount = countFilled()
    if (active) restart()
  }

  Item {
    id: grid
    width: root.cols * root.cell
    height: root.rowCount * root.cell
    anchors.horizontalCenter: parent.horizontalCenter

    Repeater {
      model: root.rowCount * root.cols
      Rectangle {
        required property int index
        readonly property int row: Math.floor(index / root.cols)
        readonly property int col: index % root.cols
        readonly property bool on: root.isOn(row, col)
        readonly property int order: on ? root.fillIndex(row, col) : -1
        visible: on
        x: col * root.cell
        y: row * root.cell
        width: root.cell
        height: root.cell
        color: row === root.scanRow ? root.scanColor : root.color
        opacity: (order >= 0 && order < root.revealed) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 70 } }
        Behavior on color { ColorAnimation { duration: 120 } }
      }
    }
  }

  Timer {
    id: revealTimer
    interval: 16
    repeat: true
    onTriggered: {
      if (root.revealed < root.filledCount) {
        root.revealed += 1
        return
      }
      stop()
      scanTimer.start()
    }
  }

  Timer {
    id: scanTimer
    interval: 140
    repeat: true
    running: false
    onTriggered: {
      root.scanTick += 1
      var n = root.rowCount
      var i = root.scanTick % (n + 10)
      root.scanRow = i < n ? i : -1
    }
  }
}
