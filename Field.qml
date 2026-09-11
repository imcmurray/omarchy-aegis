import QtQuick
import qs.Commons
import qs.Ui

// TextField with an Omarchy-themed invalid state: Color.urgent border and
// the error in the field (placeholder if empty, caption if it has text).
Item {
  id: root

  property alias text: input.text
  property alias password: input.password
  property alias foreground: input.foreground
  property color accent: Color.accent
  property string placeholderText: ""
  property bool invalid: false
  property string errorText: ""
  property var nextField: null
  property var prevField: null
  property bool hasCursor: false

  signal accepted()
  signal keyPressed(var event)
  signal edited()

  readonly property Item input: input
  readonly property color urgentColor: Color.urgent
  readonly property bool showInlineError: invalid && errorText !== "" && input.text.length > 0

  implicitHeight: input.implicitHeight
  implicitWidth: input.implicitWidth
  height: implicitHeight

  function forceActiveFocus() { input.forceActiveFocus() }

  TextField {
    id: input
    anchors.fill: parent
    foreground: root.foreground
    accent: root.invalid ? root.urgentColor : root.accent
    password: root.password
    hasCursor: root.hasCursor
    placeholderText: (root.invalid && root.errorText !== "" && text.length === 0)
      ? root.errorText
      : root.placeholderText
    placeholderTextColor: (root.invalid && text.length === 0)
      ? root.urgentColor
      : Qt.darker(foreground, 1.6)
    KeyNavigation.tab: root.nextField && root.nextField.input ? root.nextField.input : root.nextField
    KeyNavigation.backtab: root.prevField && root.prevField.input ? root.prevField.input : root.prevField
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) { root.keyPressed(event) }
    onAccepted: root.accepted()
    onTextChanged: root.edited()
    rightPadding: root.showInlineError
      ? inlineError.implicitWidth + Style.space(16)
      : horizontalPadding + Border.right(Border.controlSpec(activeFocus ? "focus" : "normal", foreground, accent))
  }

  BorderSurface {
    visible: root.invalid
    anchors.fill: parent
    color: "transparent"
    radius: Style.cornerRadius
    borderSpec: Border.flat(root.urgentColor, Math.max(Style.normalBorderWidth, Style.space(2)))
  }

  Text {
    id: inlineError
    visible: root.showInlineError
    anchors.right: parent.right
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: root.errorText
    color: root.urgentColor
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
    width: Math.min(implicitWidth, parent.width * 0.55)
  }
}
