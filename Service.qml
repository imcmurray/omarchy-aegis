import QtQuick
import Quickshell
import Quickshell.Io
import "Vault.js" as Vault

// Talks only to the native `aegis` CLI. No HTTP, no crypto, no AEGIS_KDF.
Item {
  id: root

  property var shell: null
  property var manifest: null

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

  readonly property string pluginId: "ianm.aegis"
  readonly property int maxOutputBytes: 1048576
  readonly property int timeoutDefaultMs: 15000
  readonly property int timeoutKdfMs: 120000

  function pluginFile(name) {
    var url = String(Qt.resolvedUrl(name) || "")
    if (url.indexOf("file://") === 0) {
      var path = url.substring(7)
      if (path.charAt(0) !== "/") path = "/" + path
      return decodeURIComponent(path)
    }
    return url
  }

  function pluginDir() {
    if (root.manifest && root.manifest.__sourceDir)
      return String(root.manifest.__sourceDir).replace(/\/$/, "")
    return pluginFile(".").replace(/\/$/, "")
  }

  function trustedEnv(argv) {
    var xdg = Quickshell.env("XDG_RUNTIME_DIR") || ""
    var home = Quickshell.env("HOME") || ""
    var wayland = Quickshell.env("WAYLAND_DISPLAY") || ""
    var cmd = [
      "/usr/bin/setpriv", "--pdeathsig", "TERM", "--nnp", "--",
      "/usr/bin/env", "-i",
      "PATH=/usr/bin:/bin",
      "LC_ALL=C",
      "HOME=" + home,
      "XDG_RUNTIME_DIR=" + xdg,
      "XDG_SESSION_TYPE=wayland"
    ]
    if (/^[A-Za-z0-9._-]+$/.test(wayland))
      cmd.push("WAYLAND_DISPLAY=" + wayland)
    for (var i = 0; i < argv.length; i++) cmd.push(argv[i])
    return cmd
  }

  function runner(args) {
    var cmd = trustedEnv(["/usr/bin/python3", pluginDir() + "/bin/aegis-run"])
    for (var i = 0; i < args.length; i++) cmd.push(args[i])
    return cmd
  }

  function jobTimeoutMs(kind) {
    if (kind === "unlock" || kind === "create" || kind === "import" || kind === "export")
      return root.timeoutKdfMs
    return root.timeoutDefaultMs
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
    if (proc.running) return
    if (root.jobQueue.length === 0) return
    var rest = root.jobQueue.slice()
    var job = rest.shift()
    root.jobQueue = rest
    root.activeJob = job
    root.busy = true
    root.busyKind = job.kind || ""
    if (job.clearError !== false) root.errorMessage = ""
    startRun()
  }

  function finishJob(ok, stdout, stderr, code) {
    var job = root.activeJob
    root.activeJob = null
    root.busy = root.jobQueue.length > 0
    if (root.jobQueue.length === 0) root.busyKind = ""
    jobWatchdog.stop()
    jobKill.stop()
    if (job && typeof job.onDone === "function")
      job.onDone(ok, stdout, stderr, code)
    Qt.callLater(pump)
  }

  function jobStdin(job) {
    var obj = {}
    var roles = job.passphrases || []
    for (var i = 0; i < roles.length; i++) {
      obj[String(roles[i].role || "pass")] = String(roles[i].value || "")
      roles[i].value = ""
    }
    if (job.stdinText) obj.rpc = String(job.stdinText)
    return JSON.stringify(obj) + "\n"
  }

  function abortJob() {
    if (!proc.running) return
    proc.signal(15)
    jobKill.restart()
  }

  function startRun() {
    var job = root.activeJob
    if (!job) return
    if (job.kind === "resolve") {
      proc.command = runner(["resolve"])
      proc.stdinEnabled = false
      proc.stdinText = ""
      jobWatchdog.interval = 8000
      jobWatchdog.restart()
      proc.running = true
      return
    }
    var rest = jobAegisArgs(job)
    if (!rest) {
      finishJob(false, "", "internal job error", 1)
      return
    }
    var timeout = jobTimeoutMs(job.kind)
    var args = [
      "run",
      "--timeout-ms", String(timeout),
      "--max-bytes", String(root.maxOutputBytes)
    ]
    var roles = job.passphrases || []
    for (var i = 0; i < roles.length; i++) {
      args.push("--role")
      args.push(String(roles[i].role || "pass"))
    }
    args.push("--")
    for (var j = 0; j < rest.length; j++) args.push(rest[j])
    proc.command = runner(args)
    proc.stdinText = jobStdin(job)
    proc.stdinEnabled = true
    jobWatchdog.interval = timeout + 2000
    jobWatchdog.restart()
    proc.running = true
  }

  function jobAegisArgs(job) {
    var kind = job.kind
    if (kind === "protocol") return ["--protocol-version"]
    if (kind === "status") return ["--json", "status"]
    if (kind === "search") {
      var q = String(job.query || "")
      return q ? ["--json", "search", q] : ["--json", "search"]
    }
    if (kind === "lock") return ["--json", "lock"]
    if (kind === "unlock") return ["--json", "unlock"]
    if (kind === "create") return ["--json", "create"]
    if (kind === "copy")
      return ["--json", "copy", String(job.id || ""), "--field", String(job.field || "password")]
    if (kind === "totp") return ["--json", "totp", String(job.id || "")]
    if (kind === "generate") return ["--json", "generate"]
    if (kind === "get") return ["--json", "get", String(job.id || "")]
    if (kind === "folders") return ["--json", "folders"]
    if (kind === "export") return ["--json", "export", String(job.path || "")]
    if (kind === "import") {
      var imp = ["--json", "import"]
      if (job.replace) imp.push("--replace")
      imp.push(String(job.path || ""))
      return imp
    }
    if (kind === "rpc") return ["rpc"]
    return null
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
      onDone: function(ok, stdout, stderr) {
        var path = String(stdout || "").trim()
        if (!ok || !path) {
          root.cliPresent = false
          root.ready = true
          var detail = String(stderr || "").trim()
          setError(detail || Vault.missingCliMessage())
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
    watchProc.command = runner(["watch", "--lock-timeout-ms", "10000"])
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
    id: proc
    property string stdinText: ""
    stdinEnabled: false
    clearEnvironment: true
    stdout: StdioCollector {
      id: procOut
      waitForEnd: false
      onDataChanged: {
        if (data.length > root.maxOutputBytes) root.abortJob()
      }
    }
    stderr: StdioCollector {
      id: procErr
      waitForEnd: false
      onDataChanged: {
        if (data.length > root.maxOutputBytes) root.abortJob()
      }
    }
    onStarted: {
      if (stdinText) {
        write(stdinText)
        stdinText = ""
      }
      stdinEnabled = false
    }
    onExited: function(exitCode) {
      jobKill.stop()
      finishJob(exitCode === 0, String(procOut.text || ""), String(procErr.text || ""), exitCode)
    }
  }

  Process {
    id: watchProc
    property int liveLines: 0
    property bool overflow: false
    clearEnvironment: true
    stdout: SplitParser {
      onRead: function(line) {
        var text = String(line || "")
        watchProc.liveLines += 1
        if (text.length > 256 || watchProc.liveLines > 64) {
          watchProc.overflow = true
          watchProc.running = false
          return
        }
        if (text.trim() === "LOCK") root.onSessionLockSignal()
      }
    }
    onStarted: {
      liveLines = 0
      overflow = false
    }
    onExited: {
      if (watchProc.overflow) return
      if (root.cliPresent && root.protocolSupported) watchRestart.restart()
    }
  }

  Timer {
    id: jobWatchdog
    interval: 17000
    repeat: false
    onTriggered: root.abortJob()
  }

  Timer {
    id: jobKill
    interval: 500
    repeat: false
    onTriggered: {
      if (proc.running) proc.signal(9)
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
