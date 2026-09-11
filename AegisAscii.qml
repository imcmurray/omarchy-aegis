import QtQuick
import qs.Commons

// Block-cell mark in the same spirit as Omarchy's logo.txt (half-blocks).
Text {
  id: root
  property color color: Color.foreground
  property int pixelSize: Math.max(8, Style.font.caption)

  textFormat: Text.PlainText
  horizontalAlignment: Text.AlignHCenter
  wrapMode: Text.NoWrap
  color: root.color
  font.family: Style.font.family
  font.pixelSize: root.pixelSize
  lineHeight: 1.0
  lineHeightMode: Text.ProportionalHeight
  text: "    ▄▄██████▄▄
  ▄██▀▀      ▀▀██▄
 ███    ▄██▄    ███
 ███    ████    ███
 ███     ██▄▄▄▄▄███
 ▀███     ▀▀   ███
  ▀███▄      ▄█████
    ▀██▄    ███▀▀
      ▀▀    ███"
}
