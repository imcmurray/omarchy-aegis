import QtQuick
import qs.Commons
import qs.Ui
import "Vault.js" as Vault

// Empty required errors sit in the placeholder (left). Other hints sit
// outside the field on the right (icon + word). Strength stays visible
// while typing so themes without a "good" green still read clearly.
// Validation/match labels hide while the field is focused.
Item {
  id: root

  property alias text: input.text
  property alias password: input.password
  property alias foreground: input.foreground
  property color accent: Color.accent
  property string placeholderText: ""
  property bool invalid: false
  property string errorText: ""
  property bool passwordMeter: false
  property string compareTo: ""
  property bool compareMustDiffer: false
  property var nextField: null
  property var prevField: null
  property bool hasCursor: false

  signal accepted()
  signal keyPressed(var event)
  signal edited()

  readonly property Item input: input
  readonly property var strength: Vault.passwordStrength(input.text)
  readonly property bool showCompare: !invalid && compareTo !== "" && input.text.length > 0
  readonly property bool compareOk: showCompare && (compareMustDiffer ? input.text !== compareTo : input.text === compareTo)
  readonly property bool showMeter: passwordMeter && !invalid && input.text.length > 0 && (!showCompare || (compareMustDiffer && compareOk))
  readonly property string hintText: {
    if (invalid && errorText) return errorText
    if (showCompare && !compareOk) return compareMustDiffer ? "must differ" : "mismatch"
    if (showCompare && compareOk && !compareMustDiffer) return "match"
    if (showMeter) return strength.label
    return ""
  }
  readonly property color hintColor: {
    if (invalid) return Color.urgent
    if (showCompare && !compareOk) return Color.urgent
    if (showCompare && compareOk && !compareMustDiffer) return Color.accent
    if (showMeter) {
      if (strength.role === "urgent") return Color.urgent
      if (strength.role === "muted") return Color.muted
      if (strength.role === "accent") return Color.accent
    }
    return Color.foreground
  }
  readonly property string hintIcon: {
    if (invalid && errorText) return "󰀪"
    if (showCompare && !compareOk) return "󰀪"
    if (showCompare && compareOk && !compareMustDiffer) return "󰄬"
    if (showMeter) return strength.icon || ""
    return ""
  }
  readonly property bool hintOnLeft: invalid && errorText !== "" && input.text.length === 0
  readonly property bool hintOnRight: {
    if (hintText === "" || hintOnLeft) return false
    if (invalid) return true
    if (showMeter) return true
    return !input.activeFocus
  }
  readonly property bool holdHintSlot: hintOnRight
  readonly property bool showRing: invalid || showMeter || (showCompare && !compareOk) || (showCompare && compareOk && !compareMustDiffer)

  implicitHeight: input.implicitHeight
  implicitWidth: input.implicitWidth
  height: implicitHeight

  function forceActiveFocus() { input.forceActiveFocus() }

  Row {
    anchors.fill: parent
    spacing: Style.space(8)

    Item {
      id: inputWrap
      width: parent.width - (root.holdHintSlot ? hintLabel.width + parent.spacing : 0)
      height: parent.height

      TextField {
        id: input
        anchors.fill: parent
        foreground: root.foreground
        accent: root.showRing ? root.hintColor : root.accent
        password: root.password
        hasCursor: root.hasCursor
        placeholderText: root.hintOnLeft ? root.errorText : root.placeholderText
        placeholderTextColor: root.hintOnLeft ? root.hintColor : Qt.darker(foreground, 1.6)
        KeyNavigation.tab: root.nextField && root.nextField.input ? root.nextField.input : root.nextField
        KeyNavigation.backtab: root.prevField && root.prevField.input ? root.prevField.input : root.prevField
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { root.keyPressed(event) }
        onAccepted: root.accepted()
        onTextChanged: root.edited()
      }

      BorderSurface {
        visible: root.showRing
        anchors.fill: parent
        color: "transparent"
        radius: Style.cornerRadius
        borderSpec: Border.flat(root.hintColor, Math.max(Style.normalBorderWidth, Style.space(2)))
      }
    }

    Row {
      id: hintLabel
      visible: root.hintOnRight
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)
      width: root.holdHintSlot ? Math.max(implicitWidth, Style.space(108)) : 0

      Text {
        visible: root.hintIcon !== ""
        textFormat: Text.PlainText
        text: root.hintIcon
        color: root.hintColor
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        textFormat: Text.PlainText
        text: root.hintText
        color: root.hintColor
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        width: Math.min(implicitWidth, Style.space(72))
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
