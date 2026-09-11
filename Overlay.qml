import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "Vault.js" as Vault

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var service: null

  readonly property var vault: service || (shell && typeof shell.serviceFor === "function"
    ? shell.serviceFor("ianm.aegis") : null)

  property bool opened: false
  property string mode: "search"
  property string filterText: ""
  property int selectedIndex: 0
  property int hoverIndex: -1
  property string selectedId: ""
  property bool cursorActive: false

  property string passphrase: ""
  property string passphraseConfirm: ""
  property string composeId: ""
  property string composeName: ""
  property string composeUsername: ""
  property string composePassword: ""
  property string composeUrl: ""
  property string composeTotp: ""
  property string composeNotes: ""
  property var composeTags: []
  property var composeCustomFields: []
  property var composeFolderId: null
  property string composeFolderName: ""
  property int composeCreatedAt: 0
  readonly property bool editing: composeId !== ""
  property string folderFilter: ""
  property bool backupReplace: false
  property string pluginCommit: ""
  property string composeSnapshot: ""
  property string pendingLeave: ""
  property string invalidField: ""
  property string invalidMessage: ""
  property string backupPath: Vault.defaultExportPath(Quickshell.env("HOME"))
  property string backupPass: ""
  property string livePass: ""
  property bool backupImport: false

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property color accent: Color.accent
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  readonly property string productName: "omarchy-aegis"
  readonly property string headerSubtitle: {
    if (root.screen === "missing") return "CLI missing"
    if (root.screen === "create") return "Create vault"
    if (root.screen === "unlock") return "Unlock vault"
    if (root.screen === "compose") return root.editing ? "Edit entry" : "New entry"
    if (root.screen === "backup") return root.backupImport ? "Import backup" : "Export backup"
    if (root.filterText) return "Search"
    return ""
  }
  property int headerHeight: Math.max(Style.space(40), Style.font.heading + (headerSubtitle !== "" ? Style.font.caption + Style.space(4) : 0) + Style.spacing.controlPaddingY)
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(560), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(560), panel.height - Style.gapsOut * 2)
  property int rowHeight: Math.max(Style.space(48), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)

  readonly property bool cliPresent: vault ? vault.cliPresent === true : false
  readonly property bool protocolOk: vault ? vault.protocolSupported === true : false
  readonly property bool hasVault: vault ? vault.hasVault === true : false
  readonly property bool unlocked: vault ? vault.unlocked === true : false
  readonly property bool busy: vault ? vault.busy === true : false
  readonly property string busyKind: vault ? String(vault.busyKind || "") : ""
  readonly property string errorMessage: vault ? String(vault.errorMessage || "") : ""
  readonly property string toastMessage: vault ? String(vault.toastMessage || "") : ""
  readonly property int entriesRevision: vault ? vault.entriesRevision : 0
  readonly property int foldersRevision: vault ? vault.foldersRevision : 0
  readonly property var folderList: vault && vault.folders ? vault.folders : []
  readonly property string pluginVersion: (manifest && manifest.version) ? String(manifest.version) : "0.5.0"
  readonly property string repoUrl: "https://github.com/imcmurray/omarchy-aegis"
  readonly property string issuesUrl: "https://github.com/imcmurray/omarchy-aegis/issues/new/choose"
  readonly property string vaultDataDir: {
    var data = Quickshell.env("AEGIS_DATA")
    if (data) return data
    var xdg = Quickshell.env("XDG_DATA_HOME")
    if (xdg) return xdg + "/aegis"
    return (Quickshell.env("HOME") || "") + "/.local/share/aegis"
  }
  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl(".") || "")
    if (url.indexOf("file://") === 0) {
      var path = url.substring(7)
      if (path.charAt(0) !== "/") path = "/" + path
      path = decodeURIComponent(path)
      if (path.charAt(path.length - 1) === "/") path = path.slice(0, -1)
      return path
    }
    return url
  }
  readonly property string screen: deriveScreen()

  function deriveScreen() {
    if (!vault || !vault.ready) return "boot"
    if (!cliPresent) return "missing"
    if (!protocolOk) return "missing"
    if (mode === "compose" && unlocked) return "compose"
    if (mode === "backup") return "backup"
    if (!hasVault) return "create"
    if (!unlocked) return "unlock"
    return "search"
  }

  function open(payloadJson) {
    root.opened = true
    root.mode = "search"
    root.filterText = ""
    root.selectedIndex = 0
    root.hoverIndex = -1
    root.selectedId = ""
    root.cursorActive = true
    clearCompose()
    clearSecrets()
    if (vault && vault.unlocked) {
      if (!vault.entries || vault.entries.length === 0) vault.search("")
      rebuildDisplay()
    } else if (vault && typeof vault.refreshStatus === "function") {
      vault.refreshStatus()
    }
    Qt.callLater(function() { focusScreen() })
  }

  function close() {
    root.opened = false
    clearSecrets()
  }

  function composeState() {
    return JSON.stringify({
      id: root.composeId,
      name: root.composeName,
      username: root.composeUsername,
      password: root.composePassword,
      url: root.composeUrl,
      totp: root.composeTotp,
      notes: root.composeNotes,
      folder: root.composeFolderName
    })
  }

  function takeComposeSnapshot() {
    root.composeSnapshot = root.composeState()
  }

  function isComposeDirty() {
    return root.screen === "compose" && root.composeState() !== root.composeSnapshot
  }

  function openIssues() {
    var url = root.issuesUrl
    if (typeof Qt.openUrlExternally === "function") Qt.openUrlExternally(url)
    else Quickshell.execDetached(["xdg-open", url])
  }

  function reallyDismiss() {
    root.opened = false
    root.clearCompose()
    root.clearSecrets()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "ianm.aegis")
  }

  function dismiss() {
    if (root.isComposeDirty()) {
      root.pendingLeave = "dismiss"
      discardConfirm.selectedIndex = 0
      discardConfirm.opened = true
      return
    }
    reallyDismiss()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function clearSecrets() {
    root.passphrase = ""
    root.passphraseConfirm = ""
    root.composePassword = ""
    root.composeTotp = ""
    root.backupPass = ""
    root.livePass = ""
  }

  function clearCompose() {
    root.composeId = ""
    root.composeName = ""
    root.composeUsername = ""
    root.composePassword = ""
    root.composeUrl = ""
    root.composeTotp = ""
    root.composeNotes = ""
    root.composeTags = []
    root.composeCustomFields = []
    root.composeFolderId = null
    root.composeFolderName = ""
    root.composeCreatedAt = 0
  }

  function startNewEntry() {
    root.clearCompose()
    root.mode = "compose"
    root.takeComposeSnapshot()
  }

  function fillCompose(entry) {
    if (!entry) return
    root.composeId = String(entry.id || "")
    root.composeName = String(entry.name || "")
    root.composeUsername = String(entry.username || "")
    root.composePassword = String(entry.password || "")
    root.composeUrl = String(entry.url || "")
    root.composeTotp = String(entry.totp_secret || "")
    root.composeNotes = String(entry.notes || "")
    root.composeTags = entry.tags || []
    root.composeCustomFields = entry.custom_fields || []
    root.composeFolderId = entry.folder_id || null
    root.composeFolderName = Vault.folderName(root.folderList, entry.folder_id)
    root.composeCreatedAt = Number(entry.created_at || 0)
    root.mode = "compose"
    root.takeComposeSnapshot()
  }

  function startEditSelected() {
    var id = currentId()
    if (!id || !vault) return
    vault.getEntry(id, function(entry) { root.fillCompose(entry) })
  }

  function generateComposePassword() {
    if (!vault) return
    vault.generatePassword(function(pw) { root.composePassword = pw })
  }

  function requestDelete() {
    if (!root.editing) return
    deleteConfirm.selectedIndex = 1
    deleteConfirm.opened = true
  }

  function confirmDelete() {
    deleteConfirm.opened = false
    if (!vault || !root.composeId) return
    var id = root.composeId
    vault.deleteEntry(id, function() {
      root.clearCompose()
      root.clearSecrets()
      root.takeComposeSnapshot()
      root.mode = "search"
    })
  }

  function confirmDiscard() {
    discardConfirm.opened = false
    var leave = root.pendingLeave
    root.pendingLeave = ""
    root.clearCompose()
    root.clearSecrets()
    root.takeComposeSnapshot()
    if (leave === "dismiss") root.reallyDismiss()
    else root.mode = "search"
  }

  function handleEscape() {
    if (deleteConfirm.opened) {
      deleteConfirm.opened = false
      return
    }
    if (discardConfirm.opened) {
      discardConfirm.opened = false
      root.pendingLeave = ""
      return
    }
    if (root.isComposeDirty()) {
      root.pendingLeave = "search"
      discardConfirm.selectedIndex = 0
      discardConfirm.opened = true
      return
    }
    if (root.mode === "compose" || root.mode === "backup") {
      root.mode = "search"
      root.clearCompose()
      root.clearSecrets()
      return
    }
    if (root.screen === "search" && root.filterText) {
      root.filterText = ""
      return
    }
    root.dismiss()
  }

  function routeKeys(event) {
    if (deleteConfirm.opened) {
      if (deleteConfirm.handleKey(event)) event.accepted = true
      return
    }
    if (discardConfirm.opened) {
      if (discardConfirm.handleKey(event)) event.accepted = true
      return
    }
    if (event.key === Qt.Key_Escape) {
      root.handleEscape()
      event.accepted = true
      return
    }
    var ctrl = event.modifiers & Qt.ControlModifier
    var shift = event.modifiers & Qt.ShiftModifier
    if (root.screen === "compose") {
      if (ctrl && event.key === Qt.Key_S) { root.submitCompose(); event.accepted = true }
      else if (ctrl && event.key === Qt.Key_G) { root.generateComposePassword(); event.accepted = true }
      else if (ctrl && event.key === Qt.Key_D) { root.requestDelete(); event.accepted = true }
      return
    }
    if (root.screen === "backup") {
      if (ctrl && event.key === Qt.Key_S) { root.submitBackup(); event.accepted = true }
      return
    }
    if (root.screen !== "search") return
    if (ctrl && shift && event.key === Qt.Key_E) { root.mode = "backup"; root.backupImport = false; event.accepted = true }
    else if (ctrl && shift && event.key === Qt.Key_I) { root.mode = "backup"; root.backupImport = true; event.accepted = true }
    else if (ctrl && event.key === Qt.Key_U) { root.copySelected("username"); event.accepted = true }
    else if (ctrl && event.key === Qt.Key_T) { root.copySelected("totp"); event.accepted = true }
    else if (ctrl && event.key === Qt.Key_L) { if (vault) vault.lock(); event.accepted = true }
    else if (ctrl && event.key === Qt.Key_N) { root.startNewEntry(); event.accepted = true }
    else if (ctrl && event.key === Qt.Key_E) { root.startEditSelected(); event.accepted = true }
    else if (event.key === Qt.Key_Up) { root.select(-1); event.accepted = true }
    else if (event.key === Qt.Key_Down) { root.select(1); event.accepted = true }
    else if (event.key === Qt.Key_PageUp) { root.select(-8); event.accepted = true }
    else if (event.key === Qt.Key_PageDown) { root.select(8); event.accepted = true }
    else if (event.key === Qt.Key_Home) { root.selectAbsolute(0); event.accepted = true }
    else if (event.key === Qt.Key_End) { root.selectAbsolute(displayModel.count - 1); event.accepted = true }
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (ctrl) root.startEditSelected()
      else root.copySelected("password")
      event.accepted = true
    }
  }

  function selectAbsolute(index) {
    if (displayModel.count === 0) return
    commitSelection(Math.max(0, Math.min(index, displayModel.count - 1)))
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function focusScreen() {
    if (root.screen === "search") {
      searchField.forceActiveFocus()
      return
    }
    if (root.screen === "unlock" || root.screen === "create") {
      passField.forceActiveFocus()
      return
    }
    if (root.screen === "compose") {
      composeNameField.forceActiveFocus()
      return
    }
    if (root.screen === "backup") {
      backupPathField.forceActiveFocus()
      return
    }
    keyCatcher.forceActiveFocus()
  }

  function rebuildDisplay() {
    displayModel.clear()
    var list = vault && vault.entries ? vault.entries : []
    var needle = String(root.filterText || "").trim().toLowerCase()
    var shown = 0
    for (var i = 0; i < list.length; i++) {
      var row = list[i]
      if (!row || !row.id) continue
      if (root.folderFilter && String(row.folder_id || "") !== root.folderFilter) continue
      if (needle) {
        var hay = (row.name + " " + row.username + " " + row.url + " " + row.tags).toLowerCase()
        if (hay.indexOf(needle) === -1) continue
      }
      displayModel.append(row)
      shown++
    }
    var next = 0
    if (root.selectedId) {
      for (var j = 0; j < displayModel.count; j++) {
        if (String(displayModel.get(j).id || "") === root.selectedId) {
          next = j
          break
        }
      }
    } else if (selectedIndex >= 0 && selectedIndex < displayModel.count) {
      next = selectedIndex
    }
    if (displayModel.count === 0) {
      root.selectedIndex = 0
      root.cursorActive = false
    } else {
      commitSelection(next)
    }
  }

  function commitSelection(index) {
    if (index < 0 || index >= displayModel.count) return
    root.selectedIndex = index
    root.cursorActive = true
    root.selectedId = String(displayModel.get(index).id || "")
  }

  function select(delta) {
    if (displayModel.count === 0) return
    if (!cursorActive) {
      commitSelection(delta < 0 ? displayModel.count - 1 : 0)
    } else {
      commitSelection((selectedIndex + delta + displayModel.count) % displayModel.count)
    }
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function currentId() {
    if (root.selectedId) {
      for (var i = 0; i < displayModel.count; i++) {
        if (String(displayModel.get(i).id || "") === root.selectedId)
          return root.selectedId
      }
    }
    if (selectedIndex < 0 || selectedIndex >= displayModel.count) return ""
    return String(displayModel.get(selectedIndex).id || "")
  }

  function copySelected(field) {
    var id = currentId()
    if (!id || !vault) return
    vault.copyField(id, field || "password")
  }

  function setInvalid(fieldId, message) {
    root.invalidField = fieldId
    root.invalidMessage = message
    Qt.callLater(function() {
      if (fieldId === "pass") passField.forceActiveFocus()
      else if (fieldId === "confirm") confirmField.forceActiveFocus()
      else if (fieldId === "name") composeNameField.forceActiveFocus()
      else if (fieldId === "backupPath") backupPathField.forceActiveFocus()
      else if (fieldId === "backupPass") backupPassField.forceActiveFocus()
      else if (fieldId === "backupLive") backupLiveField.forceActiveFocus()
    })
  }

  function clearInvalid(fieldId) {
    if (!fieldId || root.invalidField === fieldId) {
      root.invalidField = ""
      root.invalidMessage = ""
    }
  }

  function submitPassphrase() {
    if (!vault || busy) return
    if (root.screen === "unlock") {
      if (!root.passphrase) {
        root.setInvalid("pass", "Passphrase is required")
        return
      }
      vault.unlock(root.passphrase)
      root.passphrase = ""
      return
    }
    if (root.screen === "create") {
      if (!root.passphrase) {
        root.setInvalid("pass", "Passphrase is required")
        return
      }
      if (!root.passphraseConfirm) {
        root.setInvalid("confirm", "Confirm the passphrase")
        return
      }
      if (root.passphrase !== root.passphraseConfirm) {
        root.setInvalid("confirm", "Passphrases do not match")
        return
      }
      vault.createVault(root.passphrase)
      root.passphrase = ""
      root.passphraseConfirm = ""
    }
  }

  function submitCompose() {
    if (!vault || busy) return
    if (!String(root.composeName || "").trim()) {
      root.setInvalid("name", "Name is required")
      return
    }
    var folderName = String(root.composeFolderName || "").trim()
    if (!folderName) {
      root.composeFolderId = null
      saveEntryNow()
      return
    }
    var existing = Vault.findFolderByName(root.folderList, folderName)
    if (existing) {
      root.composeFolderId = existing.id
      saveEntryNow()
      return
    }
    vault.upsertFolder(folderName, function(folder) {
      root.composeFolderId = folder.id
      saveEntryNow()
    })
  }

  function saveEntryNow() {
    if (!vault) return
    vault.upsertEntry({
      id: root.composeId,
      name: root.composeName,
      username: root.composeUsername,
      password: root.composePassword,
      url: root.composeUrl,
      totp_secret: root.composeTotp,
      notes: root.composeNotes,
      tags: root.composeTags,
      custom_fields: root.composeCustomFields,
      folder_id: root.composeFolderId,
      created_at: root.composeCreatedAt
    })
    root.clearCompose()
    root.clearSecrets()
    root.mode = "search"
  }

  function submitBackup() {
    if (!vault || busy) return
    if (!String(root.backupPath || "").trim()) {
      root.setInvalid("backupPath", "Path is required")
      return
    }
    if (!root.backupPass) {
      root.setInvalid("backupPass", "Backup passphrase is required")
      return
    }
    if (root.backupImport) {
      if (!root.livePass) {
        root.setInvalid("backupLive", "New live passphrase is required")
        return
      }
      if (root.backupPass === root.livePass) {
        root.setInvalid("backupLive", "Must differ from backup passphrase")
        return
      }
      vault.importVault(root.backupPath, root.backupPass, root.livePass, root.backupReplace)
    } else {
      vault.exportVault(root.backupPath, root.backupPass)
    }
    root.backupPass = ""
    root.livePass = ""
  }

  onEntriesRevisionChanged: rebuildDisplay()
  onFoldersRevisionChanged: rebuildDisplay()
  onFilterTextChanged: if (root.screen === "search") rebuildDisplay()
  onFolderFilterChanged: if (root.screen === "search") rebuildDisplay()
  onScreenChanged: {
    root.clearInvalid()
    Qt.callLater(focusScreen)
  }

  ListModel { id: displayModel }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-aegis"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { root.routeKeys(event) }

        Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.handleEscape() }
        Shortcut { sequence: "Ctrl+N"; enabled: root.opened && root.screen === "search"; onActivated: root.startNewEntry() }
        Shortcut { sequence: "Ctrl+E"; enabled: root.opened && root.screen === "search"; onActivated: root.startEditSelected() }
        Shortcut { sequence: "Ctrl+Return"; enabled: root.opened && root.screen === "search"; onActivated: root.startEditSelected() }
        Shortcut { sequence: "Ctrl+U"; enabled: root.opened && root.screen === "search"; onActivated: root.copySelected("username") }
        Shortcut { sequence: "Ctrl+T"; enabled: root.opened && root.screen === "search"; onActivated: root.copySelected("totp") }
        Shortcut { sequence: "Ctrl+L"; enabled: root.opened && root.unlocked; onActivated: if (vault) vault.lock() }
        Shortcut { sequence: "Ctrl+Shift+E"; enabled: root.opened && root.screen === "search"; onActivated: { root.mode = "backup"; root.backupImport = false } }
        Shortcut { sequence: "Ctrl+Shift+I"; enabled: root.opened && root.screen === "search"; onActivated: { root.mode = "backup"; root.backupImport = true } }
        Shortcut { sequence: "Ctrl+S"; enabled: root.opened && root.screen === "compose"; onActivated: root.submitCompose() }
        Shortcut { sequence: "Ctrl+G"; enabled: root.opened && root.screen === "compose"; onActivated: root.generateComposePassword() }
        Shortcut { sequence: "Ctrl+D"; enabled: root.opened && root.screen === "compose" && root.editing; onActivated: root.requestDelete() }
      }

      ColumnLayout {
        id: cardLayout
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Row {
          id: headerRow
          Layout.fillWidth: true
          Layout.preferredHeight: root.headerHeight
          width: parent.width
          height: root.headerHeight
          spacing: Style.space(10)

          AegisIcon {
            iconSize: Style.font.heading
            color: root.foreground
            opacity: root.unlocked ? 1.0 : 0.7
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - Style.space(200)
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.productName
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              elide: Text.ElideRight
            }
            Text {
              visible: root.headerSubtitle !== ""
              textFormat: Text.PlainText
              width: parent.width
              text: root.headerSubtitle
              color: root.foreground
              opacity: 0.65
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          Button {
            visible: root.screen === "search"
            text: "New"
            foreground: root.foreground
            accent: root.accent
            bordered: true
            focusable: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.startNewEntry()
          }

          Button {
            visible: root.screen === "search"
            text: "Backup"
            foreground: root.foreground
            accent: root.accent
            focusable: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { root.mode = "backup"; root.backupImport = false }
          }

          Button {
            visible: root.screen === "search"
            text: "Lock"
            foreground: root.foreground
            accent: root.accent
            focusable: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: if (vault) vault.lock()
          }
        }

        Text {
          Layout.fillWidth: true
          width: parent.width
          visible: root.errorMessage !== ""
          textFormat: Text.PlainText
          text: root.errorMessage
          color: Color.urgent
          wrapMode: Text.Wrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          Layout.fillWidth: true
          width: parent.width
          visible: root.busy && (root.busyKind === "unlock" || root.busyKind === "create" || root.busyKind === "import" || root.busyKind === "get")
          textFormat: Text.PlainText
          text: Vault.busyLabel(root.busyKind)
          color: root.foreground
          opacity: 0.8
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        Item {
          id: pages
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true

        // ---- missing CLI
        Column {
          anchors.fill: parent
          spacing: Style.space(10)
          visible: root.screen === "missing"

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.errorMessage || Vault.missingCliMessage()
            wrapMode: Text.Wrap
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        // ---- create / unlock
        Column {
          anchors.fill: parent
          spacing: Style.space(10)
          visible: root.screen === "create" || root.screen === "unlock"

          Text {
            width: parent.width
            visible: root.screen === "create"
            textFormat: Text.PlainText
            text: "First unlock uses Argon2id (64 MiB) and can take a few seconds. The agent then stays running."
            wrapMode: Text.Wrap
            color: root.foreground
            opacity: 0.75
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Field {
            id: passField
            width: parent.width
            password: true
            placeholderText: "Master passphrase"
            text: root.passphrase
            foreground: root.foreground
            accent: root.accent
            nextField: confirmField
            invalid: root.invalidField === "pass"
            errorText: invalid ? root.invalidMessage : ""
            onKeyPressed: function(event) { root.routeKeys(event) }
            onEdited: { root.passphrase = text; root.clearInvalid("pass") }
            onAccepted: {
              if (root.screen === "unlock") root.submitPassphrase()
              else confirmField.forceActiveFocus()
            }
          }

          Field {
            id: confirmField
            width: parent.width
            visible: root.screen === "create"
            password: true
            placeholderText: "Confirm passphrase"
            text: root.passphraseConfirm
            foreground: root.foreground
            accent: root.accent
            prevField: passField
            invalid: root.invalidField === "confirm"
            errorText: invalid ? root.invalidMessage : ""
            onKeyPressed: function(event) { root.routeKeys(event) }
            onEdited: { root.passphraseConfirm = text; root.clearInvalid("confirm") }
            onAccepted: root.submitPassphrase()
          }

          Button {
            text: root.screen === "create" ? "Create vault" : "Unlock"
            foreground: root.foreground
            accent: root.accent
            bordered: true
            focusable: true
            onClicked: root.submitPassphrase()
          }

          Button {
            visible: root.screen === "create" || root.screen === "unlock"
            text: "Import .aegis backup"
            foreground: root.foreground
            accent: root.accent
            onClicked: { root.mode = "backup"; root.backupImport = true }
          }
        }

        // ---- search
        Column {
          anchors.fill: parent
          spacing: root.contentSpacing
          visible: root.screen === "search"

          TextField {
            id: searchField
            width: parent.width
            placeholderText: "Search logins…"
            text: root.filterText
            foreground: root.foreground
            accent: root.accent
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { root.routeKeys(event) }
            onTextChanged: root.filterText = text
            onAccepted: root.copySelected("password")
          }

          Flow {
            id: folderChips
            width: parent.width
            spacing: Style.space(6)
            visible: root.folderList.length > 0

            Button {
              text: "All"
              foreground: root.foreground
              accent: root.accent
              bordered: true
              selected: root.folderFilter === ""
              focusable: true
              onClicked: root.folderFilter = ""
            }

            Repeater {
              model: root.folderList
              delegate: Button {
                required property var modelData
                text: modelData.name
                foreground: root.foreground
                accent: root.accent
                bordered: true
                selected: root.folderFilter === modelData.id
                focusable: true
                onClicked: root.folderFilter = modelData.id
              }
            }
          }

          ListView {
            id: resultList
            width: parent.width
            Layout.fillHeight: true
            height: parent.height - searchField.height - folderChips.height - parent.spacing * 2
            model: displayModel
            clip: true
            spacing: Style.space(4)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              id: row
              required property int index
              required property string name
              required property string username
              required property string url
              required property string folder_id
              required property bool has_totp
              required property bool has_password

              readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
              readonly property bool hoveredRow: rowHover.hovered
              readonly property bool showActions: hasCursor || hoveredRow
              readonly property string folderLabel: Vault.folderName(root.folderList, folder_id)

              width: ListView.view.width
              height: root.rowHeight
              radius: root.cornerRadius
              color: hasCursor ? root.selectedBackground : (hoveredRow ? Util.alpha(root.foreground, 0.06) : "transparent")

              HoverHandler {
                id: rowHover
                onHoveredChanged: {
                  if (hovered) root.hoverIndex = row.index
                  else if (root.hoverIndex === row.index) root.hoverIndex = -1
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.commitSelection(row.index)
                  root.copySelected("password")
                }
                onDoubleClicked: {
                  root.commitSelection(row.index)
                  root.startEditSelected()
                }
              }

              Column {
                anchors.left: parent.left
                anchors.right: rowActions.left
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Text {
                    textFormat: Text.PlainText
                    text: row.name
                    color: row.hasCursor ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - Style.space(50)
                  }
                  Text {
                    visible: row.has_totp
                    textFormat: Text.PlainText
                    text: "TOTP"
                    color: row.hasCursor ? root.selectedText : root.foreground
                    opacity: 0.7
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: {
                    var bits = []
                    if (row.folderLabel) bits.push(row.folderLabel)
                    if (row.username) bits.push(row.username)
                    if (row.url) bits.push(row.url)
                    return bits.join("  ·  ")
                  }
                  color: row.hasCursor ? root.selectedText : root.foreground
                  opacity: 0.7
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Row {
                id: rowActions
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)
                visible: row.showActions
                z: 2

                Button {
                  text: "Edit"
                  foreground: row.hasCursor ? root.selectedText : root.foreground
                  accent: root.accent
                  bordered: true
                  onClicked: {
                    root.commitSelection(row.index)
                    root.startEditSelected()
                  }
                }
              }
            }
          }

          Text {
            visible: displayModel.count === 0 && !root.busy
            width: parent.width
            textFormat: Text.PlainText
            text: root.filterText ? "No matches" : "No entries yet. Ctrl+N to add one, Ctrl+E to edit."
            color: root.foreground
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }
        }

        // ---- compose
        Column {
          id: composePage
          anchors.fill: parent
          spacing: Style.space(8)
          clip: true
          visible: root.screen === "compose"

          Field {
            id: composeNameField
            width: parent.width
            placeholderText: "Name"
            text: root.composeName
            foreground: root.foreground
            accent: root.accent
            nextField: composeFolderField
            prevField: composeSaveButton
            invalid: root.invalidField === "name"
            errorText: invalid ? root.invalidMessage : ""
            onKeyPressed: function(event) { root.routeKeys(event) }
            onEdited: { root.composeName = text; root.clearInvalid("name") }
            onAccepted: composeFolderField.forceActiveFocus()
          }
          Field {
            id: composeFolderField
            width: parent.width
            placeholderText: "Category (optional — type a name to create one)"
            text: root.composeFolderName
            foreground: root.foreground
            accent: root.accent
            nextField: composeUserField
            prevField: composeNameField
            onKeyPressed: function(event) { root.routeKeys(event) }
            onEdited: root.composeFolderName = text
            onAccepted: composeUserField.forceActiveFocus()
          }
          Field {
            id: composeUserField
            width: parent.width
            placeholderText: "Username"
            text: root.composeUsername
            foreground: root.foreground
            accent: root.accent
            nextField: composePasswordField
            prevField: composeFolderField
            onKeyPressed: function(event) { root.routeKeys(event) }
            onEdited: root.composeUsername = text
            onAccepted: composePasswordField.forceActiveFocus()
          }
          Row {
            width: parent.width
            spacing: Style.space(8)
            Field {
              id: composePasswordField
              width: parent.width - Style.space(90)
              password: true
              placeholderText: "Password"
              text: root.composePassword
              foreground: root.foreground
              accent: root.accent
              nextField: composeUrlField
              prevField: composeUserField
              onKeyPressed: function(event) { root.routeKeys(event) }
              onEdited: root.composePassword = text
              onAccepted: composeUrlField.forceActiveFocus()
            }
            Button {
              text: "Gen"
              foreground: root.foreground
              accent: root.accent
              bordered: true
              focusable: true
              onClicked: root.generateComposePassword()
            }
          }
          Field {
            id: composeUrlField
            width: parent.width
            placeholderText: "URL"
            text: root.composeUrl
            foreground: root.foreground
            accent: root.accent
            nextField: composeTotpField
            prevField: composePasswordField
            onKeyPressed: function(event) { root.routeKeys(event) }
            onEdited: root.composeUrl = text
            onAccepted: composeTotpField.forceActiveFocus()
          }
          Field {
            id: composeTotpField
            width: parent.width
            password: true
            placeholderText: "TOTP secret (optional)"
            text: root.composeTotp
            foreground: root.foreground
            accent: root.accent
            nextField: composeNotesField
            prevField: composeUrlField
            onKeyPressed: function(event) { root.routeKeys(event) }
            onEdited: root.composeTotp = text
            onAccepted: composeNotesField.forceActiveFocus()
          }
          Item {
            id: notesBox
            width: parent.width
            readonly property real minH: Style.space(72)
            readonly property real maxH: Style.space(180)
            readonly property var notesBorderSpec: Border.controlSpec(
              composeNotesField.activeFocus ? "focus" : (notesHover.hovered ? "hover-cursor" : "normal"),
              root.foreground, root.accent)
            height: {
              var leftover = composePage.height - y - composeSaveRow.implicitHeight - composePage.spacing
              if (!(leftover > 0)) leftover = 0
              if (leftover > maxH) leftover = maxH
              return leftover
            }

            HoverHandler { id: notesHover }

            BorderSurface {
              anchors.fill: parent
              color: Style.controlFill(composeNotesField.activeFocus, notesHover.hovered, root.foreground, root.accent)
              borderSpec: notesBox.notesBorderSpec
              radius: Style.cornerRadius
            }

            Flickable {
              id: notesFlick
              anchors.fill: parent
              anchors.margins: 1
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              flickableDirection: Flickable.VerticalFlick
              contentWidth: width
              contentHeight: composeNotesField.implicitHeight
              interactive: contentHeight > height
              Controls.ScrollBar.vertical: Controls.ScrollBar {
                id: notesScrollBar
                policy: notesFlick.contentHeight > notesFlick.height + 1
                  ? Controls.ScrollBar.AlwaysOn
                  : Controls.ScrollBar.AlwaysOff
                contentItem: Rectangle {
                  implicitWidth: Style.space(8)
                  radius: width / 2
                  color: root.foreground
                  opacity: notesScrollBar.pressed ? 0.75 : (notesScrollBar.hovered ? 0.55 : 0.4)
                }
              }

              TextEdit {
                id: composeNotesField
                width: notesFlick.width - (notesScrollBar.policy === Controls.ScrollBar.AlwaysOn ? Style.space(12) : 0)
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                selectByMouse: true
                text: root.composeNotes
                color: root.foreground
                selectedTextColor: root.foreground
                selectionColor: Style.selectionFillFor(root.foreground, root.accent)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                activeFocusOnTab: true
                KeyNavigation.tab: composeSaveButton
                KeyNavigation.backtab: composeTotpField
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { root.routeKeys(event) }
                onTextChanged: if (root.composeNotes !== text) root.composeNotes = text
                leftPadding: Style.spacing.controlPaddingX
                rightPadding: Style.spacing.controlPaddingX
                topPadding: Style.spacing.inputPaddingY
                bottomPadding: Style.spacing.inputPaddingY
                onCursorRectangleChanged: {
                  var top = cursorRectangle.y
                  var bot = cursorRectangle.y + cursorRectangle.height
                  if (bot > notesFlick.contentY + notesFlick.height)
                    notesFlick.contentY = bot - notesFlick.height
                  else if (top < notesFlick.contentY)
                    notesFlick.contentY = Math.max(0, top)
                }
              }
            }

            Text {
              visible: composeNotesField.text.length === 0
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.leftMargin: Style.spacing.controlPaddingX
              anchors.topMargin: Style.spacing.inputPaddingY
              text: "Notes (optional)"
              color: Qt.darker(root.foreground, 1.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
          }
          Row {
            id: composeSaveRow
            spacing: Style.space(8)
            Button {
              id: composeSaveButton
              text: root.editing ? "Save changes" : "Save entry"
              foreground: root.foreground
              accent: root.accent
              bordered: true
              focusable: true
              onClicked: root.submitCompose()
            }
            Button {
              visible: root.editing
              text: "Delete"
              foreground: root.foreground
              accent: root.accent
              focusable: true
              onClicked: root.requestDelete()
            }
          }
        }

        // ---- backup
        Column {
          anchors.fill: parent
          spacing: Style.space(8)
          visible: root.screen === "backup"

          Text {
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            text: "Standard Aegis .aegis backup. Export from the web app and import here, or export here and Import in Aegis on another PC. Import uses the backup passphrase, then a new live-vault passphrase (they must differ)."
            color: root.foreground
            opacity: 0.75
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Field {
            id: backupPathField
            width: parent.width
            placeholderText: "Path to .aegis file"
            text: root.backupPath
            foreground: root.foreground
            accent: root.accent
            nextField: backupPassField
            invalid: root.invalidField === "backupPath"
            errorText: invalid ? root.invalidMessage : ""
            onKeyPressed: function(event) { root.routeKeys(event) }
            onEdited: { root.backupPath = text; root.clearInvalid("backupPath") }
            onAccepted: backupPassField.forceActiveFocus()
          }
          Field {
            id: backupPassField
            width: parent.width
            password: true
            placeholderText: root.backupImport ? "Backup passphrase" : "Export passphrase"
            text: root.backupPass
            foreground: root.foreground
            accent: root.accent
            nextField: backupLiveField
            prevField: backupPathField
            invalid: root.invalidField === "backupPass"
            errorText: invalid ? root.invalidMessage : ""
            onKeyPressed: function(event) { root.routeKeys(event) }
            onEdited: { root.backupPass = text; root.clearInvalid("backupPass") }
            onAccepted: {
              if (root.backupImport) backupLiveField.forceActiveFocus()
              else root.submitBackup()
            }
          }
          Field {
            id: backupLiveField
            width: parent.width
            visible: root.backupImport
            password: true
            placeholderText: "New live-vault passphrase (must differ)"
            text: root.livePass
            foreground: root.foreground
            accent: root.accent
            prevField: backupPassField
            invalid: root.invalidField === "backupLive"
            errorText: invalid ? root.invalidMessage : ""
            onKeyPressed: function(event) { root.routeKeys(event) }
            onEdited: { root.livePass = text; root.clearInvalid("backupLive") }
            onAccepted: root.submitBackup()
          }
          Toggle {
            width: parent.width
            visible: root.backupImport && root.hasVault
            label: "Replace existing vault"
            description: "Needed to load a backup into a vault that already exists. Requires aegis import --replace."
            checked: root.backupReplace
            foreground: root.foreground
            accent: root.accent
            onClicked: root.backupReplace = !root.backupReplace
          }
          Row {
            spacing: Style.space(8)
            Button {
              text: root.backupImport ? "Import" : "Export"
              foreground: root.foreground
              accent: root.accent
              bordered: true
              focusable: true
              onClicked: root.submitBackup()
            }
            Button {
              text: root.backupImport ? "Switch to export" : "Switch to import"
              foreground: root.foreground
              accent: root.accent
              focusable: true
              onClicked: root.backupImport = !root.backupImport
            }
          }
        }

        }

        Column {
          id: footer
          Layout.fillWidth: true
          width: parent.width
          spacing: Style.space(2)
          Text {
            id: footerText
            width: parent.width
            textFormat: Text.PlainText
            text: root.toastMessage || (
              root.screen === "search"
                ? "Enter copy · Edit on row · Ctrl+E edit · Ctrl+N new · Backup · Esc"
                : root.screen === "compose"
                  ? (root.editing
                    ? "Tab fields · Ctrl+S save · Ctrl+G generate · Ctrl+D delete · Esc"
                    : "Tab fields · Enter next · notes wrap · Ctrl+S save · Ctrl+G generate · Esc")
                  : root.screen === "backup"
                    ? "Enter next · Ctrl+S confirm · Esc"
                    : "Enter submit · Esc dismiss"
            )
            color: root.foreground
            opacity: 0.55
            wrapMode: Text.Wrap
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            id: versionLink
            width: parent.width
            textFormat: Text.PlainText
            text: "v" + root.pluginVersion + (root.pluginCommit ? " · " + root.pluginCommit : "") + "  ·  report an issue"
            color: versionHover.hovered ? root.accent : root.foreground
            opacity: versionHover.hovered ? 0.9 : 0.4
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.underline: true

            HoverHandler { id: versionHover }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openIssues()
            }
          }
          Text {
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            text: root.vaultDataDir + "  ·  sealed local store — Backup → Export to copy"
            color: root.foreground
            opacity: 0.4
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      ConfirmDialog {
        id: deleteConfirm
        z: 30
        anchors.fill: parent
        message: "Delete this entry? This cannot be undone."
        confirmText: "Delete"
        cancelText: "Cancel"
        background: root.background
        foreground: root.foreground
        fontFamily: root.fontFamily
        onCanceled: deleteConfirm.opened = false
        onConfirmed: root.confirmDelete()
      }

      ConfirmDialog {
        id: discardConfirm
        z: 31
        anchors.fill: parent
        message: "Discard unsaved changes?"
        confirmText: "Discard"
        cancelText: "Keep editing"
        background: root.background
        foreground: root.foreground
        fontFamily: root.fontFamily
        onCanceled: { discardConfirm.opened = false; root.pendingLeave = "" }
        onConfirmed: root.confirmDiscard()
      }
    }
  }

  Process {
    id: commitProc
    command: ["git", "-C", root.pluginDir, "rev-parse", "--short", "HEAD"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var hash = String(text || "").trim()
        if (hash && hash.length <= 16) root.pluginCommit = hash
      }
    }
  }

  FileView {
    id: commitFile
    path: root.pluginDir + "/COMMIT"
    printErrors: false
    onLoaded: {
      if (root.pluginCommit) return
      var hash = String(text() || "").trim()
      if (hash && hash.length <= 16) root.pluginCommit = hash
    }
  }

  Component.onCompleted: commitProc.running = true
}
