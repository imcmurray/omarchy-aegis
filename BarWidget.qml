import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "ianm.aegis"

  readonly property var vault: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(moduleName)
    : null

  readonly property bool unlocked: vault ? vault.unlocked === true : false
  readonly property bool hasVault: vault ? vault.hasVault === true : false
  readonly property bool cliPresent: vault ? vault.cliPresent === true : false
  readonly property bool busy: vault ? vault.busy === true : false

  readonly property color iconColor: bar ? bar.foreground : Color.foreground
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: Style.bar.iconCanvas
  readonly property real openPanelIndicatorHeight: Style.bar.iconCanvas

  readonly property string tooltip: {
    if (!vault || !vault.ready) return "omarchy-aegis"
    if (!cliPresent) return "omarchy-aegis · CLI missing"
    if (unlocked) return "omarchy-aegis · unlocked"
    if (hasVault) return "omarchy-aegis · locked"
    return "omarchy-aegis · no vault"
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("shell" in target && root.bar) target.shell = root.bar.shell
    if ("service" in target) target.service = root.vault
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open("{}")
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function lockVault() {
    if (vault && typeof vault.lock === "function") vault.lock()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onVaultChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: root.moduleName
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.tooltip
    iconComponent: Component {
      Item {
        AegisIcon {
          anchors.centerIn: parent
          iconSize: Style.bar.iconFont
          color: root.iconColor
          opacity: !root.cliPresent ? 0.4 : (root.unlocked ? 1.0 : 0.55)
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.lockVault()
      else root.toggle()
    }
  }
}
