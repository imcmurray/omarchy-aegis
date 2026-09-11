var REQUIRED_PROTOCOL = 1
var CLIPBOARD_CLEAR_SECONDS = 30

function parseJson(raw) {
  try {
    return JSON.parse(String(raw || "").trim() || "null")
  } catch (e) {
    return null
  }
}

function lastJsonLine(raw) {
  var text = String(raw || "").trim()
  if (!text) return null
  var lines = text.split("\n")
  for (var i = lines.length - 1; i >= 0; i--) {
    var line = String(lines[i] || "").trim()
    if (!line) continue
    var obj = parseJson(line)
    if (obj && typeof obj === "object") return obj
  }
  return parseJson(text)
}

function protocolVersion(raw) {
  var n = parseInt(String(raw || "").trim(), 10)
  return isFinite(n) ? n : -1
}

function protocolOk(version) {
  return version === REQUIRED_PROTOCOL
}

function missingCliMessage() {
  return "aegis is not on PATH. Install the native CLI from the Aegis repo:\ncargo install --path tools/cli"
}

function protocolMismatchMessage(version) {
  return "aegis --protocol-version is " + String(version) + "; this plugin requires " + String(REQUIRED_PROTOCOL) + "."
}

function asStatus(obj) {
  if (!obj || typeof obj !== "object") return null
  if (obj.type !== "status") return null
  return {
    type: "status",
    has_vault: obj.has_vault === true,
    unlocked: obj.unlocked === true,
    vault_id: obj.vault_id ? String(obj.vault_id) : "",
    has_recovery: obj.has_recovery === true,
    vault_format: obj.vault_format ? String(obj.vault_format) : "",
    needs_migration: obj.needs_migration === true
  }
}

function asError(obj) {
  if (!obj || typeof obj !== "object") return null
  if (obj.type !== "error") return null
  return {
    type: "error",
    code: String(obj.code || ""),
    message: String(obj.message || "error")
  }
}

function entriesFingerprint(entries) {
  return JSON.stringify(Array.isArray(entries) ? entries : [])
}

function flattenEntry(entry) {
  if (!entry || typeof entry !== "object") return null
  var urls = Array.isArray(entry.urls) ? entry.urls : []
  var tags = Array.isArray(entry.tags) ? entry.tags : []
  var url = ""
  for (var i = 0; i < urls.length; i++) {
    if (String(urls[i] || "").trim()) {
      url = String(urls[i])
      break
    }
  }
  return {
    id: String(entry.id || ""),
    folder_id: entry.folder_id ? String(entry.folder_id) : "",
    name: String(entry.name || ""),
    username: String(entry.username || ""),
    url: url,
    tags: tags.map(function(t) { return String(t) }).join(", "),
    has_password: entry.has_password === true,
    has_username: entry.has_username === true,
    has_totp: entry.has_totp === true,
    has_url: entry.has_url === true || url !== "",
    has_notes: entry.has_notes === true
  }
}

function asSummaries(obj) {
  if (!obj || typeof obj !== "object") return null
  if (obj.type !== "summaries") return null
  var src = Array.isArray(obj.entries) ? obj.entries : []
  var out = []
  for (var i = 0; i < src.length; i++) {
    var row = flattenEntry(src[i])
    if (row && row.id) out.push(row)
  }
  return { type: "summaries", entries: out }
}

function asPassword(obj) {
  if (!obj || typeof obj !== "object") return null
  if (obj.type !== "password") return null
  return { type: "password", password: String(obj.password || "") }
}

function asTotp(obj) {
  if (!obj || typeof obj !== "object") return null
  if (obj.type !== "totp") return null
  return {
    type: "totp",
    code: String(obj.code || ""),
    seconds_remaining: Number(obj.seconds_remaining || 0),
    period: Number(obj.period || 30)
  }
}

function asUnlocked(obj) {
  if (!obj || typeof obj !== "object") return null
  if (obj.type !== "unlocked") return null
  return { type: "unlocked", vault_id: String(obj.vault_id || "") }
}

function asOk(obj) {
  if (!obj || typeof obj !== "object") return null
  if (obj.type !== "ok") return null
  return obj
}

function asEntry(obj) {
  if (!obj || typeof obj !== "object") return null
  if (obj.type !== "entry" || !obj.entry || typeof obj.entry !== "object") return null
  var e = obj.entry
  var urls = Array.isArray(e.urls) ? e.urls : []
  var url = ""
  for (var i = 0; i < urls.length; i++) {
    if (String(urls[i] || "").trim()) {
      url = String(urls[i])
      break
    }
  }
  return {
    id: String(e.id || ""),
    folder_id: e.folder_id == null ? null : String(e.folder_id),
    name: String(e.name || ""),
    username: String(e.username || ""),
    password: String(e.password || ""),
    notes: String(e.notes || ""),
    url: url,
    urls: urls,
    tags: Array.isArray(e.tags) ? e.tags : [],
    custom_fields: Array.isArray(e.custom_fields) ? e.custom_fields : [],
    totp_secret: e.totp_secret ? String(e.totp_secret) : "",
    created_at: Number(e.created_at || 0),
    updated_at: Number(e.updated_at || 0)
  }
}

function deleteRequest(id) {
  return { op: "delete_entry", id: String(id || "") }
}

function asFolders(obj) {
  if (!obj || typeof obj !== "object") return []
  var src = obj.type === "folders" && Array.isArray(obj.folders) ? obj.folders : []
  var out = []
  for (var i = 0; i < src.length; i++) {
    var f = src[i]
    if (!f || !f.id) continue
    out.push({
      id: String(f.id),
      name: String(f.name || ""),
      parent: f.parent ? String(f.parent) : ""
    })
  }
  return out
}

function folderName(folders, folderId) {
  var id = String(folderId || "")
  if (!id) return ""
  var list = Array.isArray(folders) ? folders : []
  for (var i = 0; i < list.length; i++) {
    if (String(list[i].id) === id) return String(list[i].name || "")
  }
  return ""
}

function findFolderByName(folders, name) {
  var needle = String(name || "").trim().toLowerCase()
  if (!needle) return null
  var list = Array.isArray(folders) ? folders : []
  for (var i = 0; i < list.length; i++) {
    if (String(list[i].name || "").trim().toLowerCase() === needle) return list[i]
  }
  return null
}

function folderUpsertRequest(name, id) {
  var now = unixNow()
  return {
    op: "upsert_folder",
    folder: {
      id: String(id || newEntryId()),
      name: String(name || "").trim(),
      parent: null,
      created_at: now,
      updated_at: now
    }
  }
}

function stderrMessage(stderr) {
  var text = String(stderr || "").trim()
  if (!text) return ""
  if (text.indexOf("error: ") === 0) return text.slice(7)
  return text
}

function resultFromOutput(stdout, stderr, exitCode) {
  var obj = lastJsonLine(stdout)
  var err = asError(obj)
  if (err) return err
  if (exitCode !== 0 && exitCode !== undefined && exitCode !== null) {
    var msg = stderrMessage(stderr)
    if (obj && obj.type) return obj
    return {
      type: "error",
      code: "internal",
      message: msg || ("aegis exited " + String(exitCode))
    }
  }
  return obj
}

function passwordStrength(pw) {
  var s = String(pw || "")
  if (!s) return { score: 0, label: "", role: "" }
  var classes = 0
  if (/[a-z]/.test(s)) classes++
  if (/[A-Z]/.test(s)) classes++
  if (/[0-9]/.test(s)) classes++
  if (/[^a-zA-Z0-9]/.test(s)) classes++
  var len = s.length
  var score = 0
  if (len >= 8) score++
  if (len >= 12) score++
  if (classes >= 2) score++
  if (classes >= 3 && len >= 10) score++
  if (classes >= 4 && len >= 12) score++
  if (score > 4) score = 4
  if (score < 1) score = 1
  if (len < 8) score = Math.min(score, 1)
  if (len < 6 || /^(.)\1+$/.test(s)) score = Math.min(score, 1)
  var labels = ["", "weak", "fair", "good", "strong"]
  var roles = ["", "urgent", "muted", "accent", "accent"]
  return { score: score, label: labels[score], role: roles[score] }
}

function newEntryId() {
  var chars = "0123456789abcdef"
  var out = ""
  for (var i = 0; i < 32; i++)
    out += chars.charAt(Math.floor(Math.random() * 16))
  return out
}

function unixNow() {
  return Math.floor(Date.now() / 1000)
}

function upsertRequest(fields) {
  var f = fields || {}
  var now = unixNow()
  var urls = []
  var url = String(f.url || "").trim()
  if (url) urls.push(url)
  var totp = String(f.totp_secret || "").trim()
  var tags = Array.isArray(f.tags) ? f.tags : []
  var custom = Array.isArray(f.custom_fields) ? f.custom_fields : []
  var entry = {
    id: String(f.id || newEntryId()),
    folder_id: f.folder_id == null || f.folder_id === "" ? null : f.folder_id,
    name: String(f.name || "").trim(),
    urls: urls,
    username: String(f.username || ""),
    password: String(f.password || ""),
    notes: String(f.notes || ""),
    custom_fields: custom,
    tags: tags,
    created_at: Number(f.created_at || now),
    updated_at: now
  }
  if (totp) entry.totp_secret = totp
  return { op: "upsert_entry", entry: entry }
}

function copyToast(field) {
  var name = String(field || "password").toLowerCase()
  if (name === "totp") return "Copied TOTP · wipes in " + CLIPBOARD_CLEAR_SECONDS + "s"
  if (name === "username") return "Copied username · wipes in " + CLIPBOARD_CLEAR_SECONDS + "s"
  if (name === "url") return "Copied URL · wipes in " + CLIPBOARD_CLEAR_SECONDS + "s"
  return "Copied password · wipes in " + CLIPBOARD_CLEAR_SECONDS + "s"
}

function busyLabel(kind) {
  if (kind === "unlock") return "Unlocking…"
  if (kind === "create") return "Creating vault…"
  if (kind === "import") return "Importing…"
  if (kind === "export") return "Exporting…"
  if (kind === "search") return "Searching…"
  if (kind === "copy") return "Copying…"
  if (kind === "generate") return "Generating…"
  if (kind === "get") return "Loading entry…"
  if (kind === "delete") return "Deleting…"
  return "Working…"
}

function defaultExportPath(home) {
  var h = String(home || "")
  if (!h) return "vault.aegis"
  return h + "/Documents/vault.aegis"
}

function jsonLine(obj) {
  return JSON.stringify(obj)
}
