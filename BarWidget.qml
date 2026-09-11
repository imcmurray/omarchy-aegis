import QtQuick
import Quickshell
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

  readonly property string tooltip: {
    if (!vault || !vault.ready) return "Aegis"
    if (!cliPresent) return "Aegis · CLI missing"
    if (unlocked) return "Aegis · unlocked"
    if (hasVault) return "Aegis · locked"
    return "Aegis · no vault"
  }

  function summonOverlay() {
    if (root.bar && root.bar.shell && typeof root.bar.shell.toggle === "function") {
      root.bar.shell.toggle(root.moduleName, "{}")
      return
    }
    Quickshell.execDetached(["omarchy-shell", "shell", "toggle", root.moduleName, "{}"])
  }

  function lockVault() {
    if (vault && typeof vault.lock === "function") vault.lock()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.tooltip
    iconComponent: Component {
      Item {
        AegisIcon {
          anchors.centerIn: parent
          iconSize: parent.width
          color: root.iconColor
          opacity: !root.cliPresent ? 0.4 : (root.unlocked ? 1.0 : 0.55)
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.lockVault()
      else root.summonOverlay()
    }
  }
}
