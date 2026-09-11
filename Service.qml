import QtQuick
import Quickshell
import Quickshell.Io
import "Vault.js" as Vault

// Talks only to the native `aegis` CLI. No HTTP, no crypto, no AEGIS_KDF.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || ""

  property string cliPath: ""
  property int protocolVersion: -1
  property bool cliPresent: false
  property bool protocolSupported: false
  property bool ready: false

  property bool busy: false
  property string busyKind: ""
  property string errorMessage: ""
  property string toastMessage: ""

  property bool hasVault: false
  property bool unlocked: false
  property string vaultId: ""
  property string vaultFormat: ""
  property bool needsMigration: false

  property var entries: []
  property string lastQuery: ""
  property int entriesRevision: 0
  property var folders: []
  property int foldersRevision: 0

  property var jobQueue: []
  property var activeJob: null
  property var passRoles: []
  property int passIndex: 0
  property var passPaths: ({})

  readonly property string pluginId: "ianm.aegis"
  readonly property string home: Quickshell.env("HOME") || ""

  function pluginFile(name) {
    var url = String(Qt.resolvedUrl(name) || "")
    if (url.indexOf("file://") === 0) {
      var path = url.substring(7)
      if (path.charAt(0) !== "/") path = "/" + path
      return decodeURIComponent(path)
    }
    return url
  }

  function passfileBin() {
    return pluginFile("bin/aegis-passfile")
  }

  function envCmd(args) {
    var cmd = ["env", "-u", "AEGIS_KDF"]
    for (var i = 0; i < args.length; i++) cmd.push(args[i])
    return cmd
  }

  function setError(message) {
    root.errorMessage = String(message || "")
  }

  function toast(message) {
    root.toastMessage = String(message || "")
    if (root.toastMessage) toastClear.restart()
  }

  function enqueue(job) {
    var next = []
    for (var i = 0; i < root.jobQueue.length; i++) next.push(root.jobQueue[i])
    next.push(job)
    root.jobQueue = next
    pump()
  }

  function pump() {
    if (root.activeJob) return
    if (proc.running || passProc.running || rmProc.running) return
    if (root.jobQueue.length === 0) return
    var rest = root.jobQueue.slice()
    var job = rest.shift()
    root.jobQueue = rest
    root.activeJob = job
    root.busy = true
    root.busyKind = job.kind || ""
    if (job.clearError !== false) root.errorMessage = ""
    root.passRoles = job.passphrases || []
    root.passIndex = 0
    root.passPaths = ({})
    if (root.passRoles.length > 0) startPassfile()
    else startAegis()
  }

  function finishJob(ok, stdout, stderr, code) {
    var job = root.activeJob
    var paths = root.passPaths
    root.activeJob = null
    root.passRoles = []
    root.passIndex = 0
    root.passPaths = ({})
    root.busy = root.jobQueue.length > 0
    if (root.jobQueue.length === 0) root.busyKind = ""
    unlinkPaths(paths)
    if (job && typeof job.onDone === "function")
      job.onDone(ok, stdout, stderr, code)
    Qt.callLater(pump)
  }

  function startPassfile() {
    var roles = root.passRoles
    if (root.passIndex >= roles.length) {
      startAegis()
      return
    }
    var item = roles[root.passIndex]
    passProc.secret = String(item.value || "")
    passProc.role = String(item.role || "pass")
    item.value = ""
    passProc.command = [passfileBin()]
    passProc.stdinEnabled = true
    passProc.running = true
  }

  function startAegis() {
    var job = root.activeJob
    if (!job) return
    var args = jobArgs(job, root.passPaths)
    if (!args) {
      finishJob(false, "", "internal job error", 1)
      return
    }
    proc.command = envCmd(args)
    proc.stdinEnabled = !!job.stdinText
    proc.stdinText = job.stdinText || ""
    proc.running = true
  }

  function jobArgs(job, paths) {
    var kind = job.kind
    if (kind === "resolve") {
      return ["bash", "-c",
        'if command -v aegis >/dev/null 2>&1; then command -v aegis; ' +
        'elif [ -x "$HOME/.cargo/bin/aegis" ]; then printf %s "$HOME/.cargo/bin/aegis"; ' +
        'elif [ -x "$HOME/.local/bin/aegis" ]; then printf %s "$HOME/.local/bin/aegis"; ' +
        'else exit 1; fi']
    }
    var bin = root.cliPath || "aegis"
    if (kind === "protocol") return [bin, "--protocol-version"]
    if (kind === "status") return [bin, "--json", "status"]
    if (kind === "search") {
      var q = String(job.query || "")
      return q ? [bin, "--json", "search", q] : [bin, "--json", "search"]
    }
    if (kind === "lock") return [bin, "--json", "lock"]
    if (kind === "unlock")
      return [bin, "--json", "--passphrase-file", paths.pass, "unlock"]
    if (kind === "create")
      return [bin, "--json", "--passphrase-file", paths.pass, "create"]
    if (kind === "copy")
      return [bin, "--json", "copy", String(job.id || ""), "--field", String(job.field || "password")]
    if (kind === "totp")
      return [bin, "--json", "totp", String(job.id || "")]
    if (kind === "generate") return [bin, "--json", "generate"]
    if (kind === "get") return [bin, "--json", "get", String(job.id || "")]
    if (kind === "folders") return [bin, "--json", "folders"]
    if (kind === "export")
      return [bin, "--json", "export", "--backup-passphrase-file", paths.pass, String(job.path || "")]
    if (kind === "import") {
      var imp = [bin, "--json", "import"]
      if (job.replace) imp.push("--replace")
      imp.push(
        "--backup-passphrase-file", paths.backup,
        "--new-passphrase-file", paths.live,
        String(job.path || "")
      )
      return imp
    }
    if (kind === "rpc") return [bin, "rpc"]
    return null
  }

  function unlinkPaths(paths) {
    var list = []
    if (paths) {
      for (var key in paths) {
        if (paths[key]) list.push(paths[key])
      }
    }
    if (list.length === 0) return
    var cmd = ["rm", "-f", "--"]
    for (var i = 0; i < list.length; i++) cmd.push(list[i])
    rmProc.command = cmd
    rmProc.running = true
  }

  function applyStatus(obj) {
    var st = Vault.asStatus(obj)
    if (!st) return false
    var wasUnlocked = root.unlocked
    root.hasVault = st.has_vault
    root.unlocked = st.unlocked
    root.vaultId = st.vault_id
    root.vaultFormat = st.vault_format
    root.needsMigration = st.needs_migration
    if (wasUnlocked && !st.unlocked) {
      root.entries = []
      root.folders = []
      root.entriesRevision++
      root.foldersRevision++
    }
    return true
  }

  function handleCliResult(kind, stdout, stderr, code, extra) {
    if (kind === "protocol") {
      root.protocolVersion = Vault.protocolVersion(stdout)
      root.protocolSupported = Vault.protocolOk(root.protocolVersion)
      if (!root.protocolSupported) {
        root.cliPresent = true
        root.ready = true
        setError(Vault.protocolMismatchMessage(root.protocolVersion))
      }
      return
    }

    var obj = Vault.resultFromOutput(stdout, stderr, code)
    var err = Vault.asError(obj)
    if (err) {
      if (err.code === "locked") {
        root.unlocked = false
        root.entries = []
        root.entriesRevision++
      }
      setError(err.message)
      return
    }

    if (kind === "status") {
      if (!applyStatus(obj)) setError("unexpected status response")
      return
    }
    if (kind === "search") {
      var sum = Vault.asSummaries(obj)
      if (!sum) {
        setError("unexpected search response")
        return
      }
      if (Vault.entriesFingerprint(sum.entries) === Vault.entriesFingerprint(root.entries))
        return
      root.entries = sum.entries
      root.entriesRevision++
      return
    }
    if (kind === "unlock") {
      var unlocked = Vault.asUnlocked(obj)
      if (unlocked) {
        root.hasVault = true
        root.unlocked = true
        root.vaultId = unlocked.vault_id
        root.errorMessage = ""
        search("")
        refreshFolders()
        return
      }
      if (obj && obj.type === "ok") {
        root.hasVault = true
        root.unlocked = true
        search("")
        refreshFolders()
        return
      }
      applyStatus(obj)
      return
    }
    if (kind === "create") {
      if (obj && (obj.type === "unlocked" || obj.type === "ok")) {
        root.hasVault = true
        return
      }
      applyStatus(obj)
      return
    }
    if (kind === "lock") {
      root.unlocked = false
      root.entries = []
      root.folders = []
      root.entriesRevision++
      root.foldersRevision++
      refreshStatus()
      return
    }
    if (kind === "copy") {
      toast(Vault.copyToast(extra && extra.field ? extra.field : "password"))
      return
    }
    if (kind === "totp") {
      var totp = Vault.asTotp(obj)
      if (totp) toast("TOTP " + totp.code + " · " + totp.seconds_remaining + "s left")
      else toast(Vault.copyToast("totp"))
      return
    }
    if (kind === "export") {
      toast("Exported vault")
      return
    }
    if (kind === "import") {
      root.entries = []
      root.folders = []
      root.vaultId = ""
      root.unlocked = false
      root.entriesRevision++
      root.foldersRevision++
      toast("Imported as a new live vault")
      refreshStatus()
      refreshFolders()
      return
    }
    if (kind === "folders") {
      root.folders = Vault.asFolders(obj)
      root.foldersRevision++
      return
    }
    if (kind === "rpc") {
      if (obj && obj.type === "ok") {
        toast(extra && extra.deleted ? "Deleted" : "Saved")
        search(root.lastQuery)
        return
      }
      var un = Vault.asUnlocked(obj)
      if (un || (obj && obj.type === "entry")) {
        toast("Saved")
        search(root.lastQuery)
        return
      }
      if (obj && obj.type === "error") setError(obj.message)
      else search(root.lastQuery)
    }
  }

  function recheckCli() {
    root.cliPath = ""
    root.cliPresent = false
    root.protocolSupported = false
    root.protocolVersion = -1
    root.ready = false
    root.errorMessage = ""
    bootstrap()
  }

  function bootstrap() {
    enqueue({
      kind: "resolve",
      onDone: function(ok, stdout) {
        var path = String(stdout || "").trim()
        if (!ok || !path) {
          root.cliPresent = false
          root.ready = true
          setError(Vault.missingCliMessage())
          return
        }
        root.cliPath = path
        root.cliPresent = true
        enqueue({
          kind: "protocol",
          onDone: function(pok, pstdout, pstderr, pcode) {
            handleCliResult("protocol", pstdout, pstderr, pcode)
            if (!root.protocolSupported) return
            root.ready = true
            refreshStatus()
            startSessionWatch()
          }
        })
      }
    })
  }

  function refreshStatus() {
    if (!root.cliPresent) return
    enqueue({
      kind: "status",
      clearError: false,
      onDone: function(ok, stdout, stderr, code) {
        var wasUnlocked = root.unlocked
        handleCliResult("status", stdout, stderr, code)
        if (root.unlocked && !wasUnlocked) search("")
      }
    })
  }

  function refreshFolders() {
    if (!root.cliPresent || !root.unlocked) {
      root.folders = []
      root.foldersRevision++
      return
    }
    enqueue({
      kind: "folders",
      clearError: false,
      onDone: function(ok, stdout, stderr, code) {
        handleCliResult("folders", stdout, stderr, code)
      }
    })
  }

  function search(query) {
    if (!root.cliPresent || !root.unlocked) return
    root.lastQuery = String(query || "")
    enqueue({
      kind: "search",
      query: root.lastQuery,
      onDone: function(ok, stdout, stderr, code) {
        handleCliResult("search", stdout, stderr, code)
      }
    })
  }

  function lock() {
    enqueue({
      kind: "lock",
      onDone: function(ok, stdout, stderr, code) {
        handleCliResult("lock", stdout, stderr, code)
      }
    })
  }

  function unlock(passphrase) {
    enqueue({
      kind: "unlock",
      passphrases: [{ role: "pass", value: String(passphrase || "") }],
      onDone: function(ok, stdout, stderr, code) {
        handleCliResult("unlock", stdout, stderr, code)
      }
    })
  }

  function createVault(passphrase) {
    var pw = String(passphrase || "")
    enqueue({
      kind: "create",
      passphrases: [{ role: "pass", value: pw }],
      onDone: function(ok, stdout, stderr, code) {
        var obj = Vault.resultFromOutput(stdout, stderr, code)
        if (Vault.asError(obj)) {
          handleCliResult("create", stdout, stderr, code)
          return
        }
        handleCliResult("create", stdout, stderr, code)
        // Create is a one-shot process; the session dies with it.
        // Unlock starts the agent and keeps the vault open.
        unlock(pw)
      }
    })
  }

  function copyField(id, field) {
    var f = String(field || "password")
    enqueue({
      kind: "copy",
      id: String(id || ""),
      field: f,
      onDone: function(ok, stdout, stderr, code) {
        handleCliResult("copy", stdout, stderr, code, { field: f })
      }
    })
  }

  function totp(id) {
    enqueue({
      kind: "totp",
      id: String(id || ""),
      onDone: function(ok, stdout, stderr, code) {
        handleCliResult("totp", stdout, stderr, code)
      }
    })
  }

  function getEntry(id, onEntry) {
    enqueue({
      kind: "get",
      id: String(id || ""),
      onDone: function(ok, stdout, stderr, code) {
        var obj = Vault.resultFromOutput(stdout, stderr, code)
        var entry = Vault.asEntry(obj)
        if (entry && typeof onEntry === "function") onEntry(entry)
        else if (Vault.asError(obj)) setError(Vault.asError(obj).message)
        else setError("could not load entry")
      }
    })
  }

  function deleteEntry(id, onDone) {
    enqueue({
      kind: "rpc",
      stdinText: Vault.jsonLine(Vault.deleteRequest(id)) + "\n",
      onDone: function(ok, stdout, stderr, code) {
        handleCliResult("rpc", stdout, stderr, code, { deleted: true })
        if (typeof onDone === "function") onDone(ok, stdout, stderr, code)
      }
    })
  }

  function generatePassword(onPassword) {
    enqueue({
      kind: "generate",
      onDone: function(ok, stdout, stderr, code) {
        var obj = Vault.resultFromOutput(stdout, stderr, code)
        var pw = Vault.asPassword(obj)
        if (pw && typeof onPassword === "function") onPassword(pw.password)
        else if (Vault.asError(obj)) setError(Vault.asError(obj).message)
      }
    })
  }

  function exportVault(path, passphrase) {
    enqueue({
      kind: "export",
      path: String(path || ""),
      passphrases: [{ role: "pass", value: String(passphrase || "") }],
      onDone: function(ok, stdout, stderr, code) {
        handleCliResult("export", stdout, stderr, code)
      }
    })
  }

  function importVault(path, backupPass, livePass, replace) {
    var live = String(livePass || "")
    enqueue({
      kind: "import",
      replace: replace === true,
      path: String(path || ""),
      passphrases: [
        { role: "backup", value: String(backupPass || "") },
        { role: "live", value: live }
      ],
      onDone: function(ok, stdout, stderr, code) {
        var obj = Vault.resultFromOutput(stdout, stderr, code)
        if (Vault.asError(obj)) {
          handleCliResult("import", stdout, stderr, code)
          return
        }
        handleCliResult("import", stdout, stderr, code)
        if (live) unlock(live)
      }
    })
  }

  function upsertFolder(name, onFolder) {
    var req = Vault.folderUpsertRequest(name)
    enqueue({
      kind: "rpc",
      stdinText: Vault.jsonLine(req) + "\n",
      onDone: function(ok, stdout, stderr, code) {
        var obj = Vault.resultFromOutput(stdout, stderr, code)
        if (Vault.asError(obj)) {
          setError(Vault.asError(obj).message)
          return
        }
        refreshFolders()
        if (typeof onFolder === "function") onFolder(req.folder)
      }
    })
  }

  function startSessionWatch() {
    if (!root.cliPresent || watchProc.running) return
    watchProc.command = [
      "setpriv", "--pdeathsig", "TERM",
      pluginFile("bin/aegis-session-watch"),
      root.cliPath || "aegis",
      root.omarchyPath || "/usr/share/omarchy"
    ]
    watchProc.running = true
  }

  function onSessionLockSignal() {
    if (root.unlocked) lock()
    else refreshStatus()
  }

  function upsertEntry(fields) {
    enqueue({
      kind: "rpc",
      stdinText: Vault.jsonLine(Vault.upsertRequest(fields)) + "\n",
      onDone: function(ok, stdout, stderr, code) {
        handleCliResult("rpc", stdout, stderr, code)
      }
    })
  }

  Process {
    id: passProc
    property string secret: ""
    property string role: "pass"
    stdinEnabled: true
    stdout: StdioCollector { id: passOut; waitForEnd: true }
    stderr: StdioCollector { id: passErr; waitForEnd: true }
    onStarted: {
      write(secret)
      secret = ""
      stdinEnabled = false
    }
    onExited: function(exitCode) {
      var path = String(passOut.text || "").trim()
      if (exitCode !== 0 || !path) {
        finishJob(false, "", String(passErr.text || "passfile failed"), exitCode)
        return
      }
      var next = {}
      for (var key in root.passPaths) next[key] = root.passPaths[key]
      next[role] = path
      root.passPaths = next
      root.passIndex = root.passIndex + 1
      startPassfile()
    }
  }

  Process {
    id: proc
    property string stdinText: ""
    stdinEnabled: false
    stdout: StdioCollector { id: procOut; waitForEnd: true }
    stderr: StdioCollector { id: procErr; waitForEnd: true }
    onStarted: {
      if (stdinText) {
        write(stdinText)
        stdinText = ""
      }
      stdinEnabled = false
    }
    onExited: function(exitCode) {
      finishJob(exitCode === 0, String(procOut.text || ""), String(procErr.text || ""), exitCode)
    }
  }

  Process {
    id: rmProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: Qt.callLater(pump)
  }

  Process {
    id: watchProc
    stdout: SplitParser {
      onRead: function(line) {
        if (String(line || "").trim() === "LOCK") root.onSessionLockSignal()
      }
    }
    onExited: {
      if (root.cliPresent && root.protocolSupported) watchRestart.restart()
    }
  }

  Timer {
    id: watchRestart
    interval: 2000
    repeat: false
    onTriggered: startSessionWatch()
  }

  Timer {
    id: toastClear
    interval: 3500
    repeat: false
    onTriggered: root.toastMessage = ""
  }

  Timer {
    id: poll
    interval: 15000
    repeat: true
    running: root.cliPresent && root.protocolSupported
    onTriggered: {
      if (!root.busy) refreshStatus()
    }
  }

  Component.onCompleted: bootstrap()
}
