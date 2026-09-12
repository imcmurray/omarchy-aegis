#!/usr/bin/env node

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(path.join(__dirname, "..", "Vault.js"), "utf8")
const vault = {}
vm.createContext(vault)
vm.runInContext(source, vault, { filename: "Vault.js" })

assert.equal(vault.passwordStrength("").score, 0)
assert.equal(vault.passwordStrength("abc").label, "weak")
assert.equal(vault.passwordStrength("abc").icon !== "", true)
assert.equal(vault.passwordStrength("aaaaaaaa").label, "weak")
assert.equal(vault.passwordStrength("correct-Horse-battery-staple-9").score >= 3, true)
assert.equal(vault.passwordStrength("Aa1!Aa1!Aa1!").label === "good" || vault.passwordStrength("Aa1!Aa1!Aa1!").label === "strong", true)

assert.equal(vault.REQUIRED_PROTOCOL, 1)
assert.equal(vault.protocolVersion("1\n"), 1)
assert.equal(vault.protocolOk(1), true)
assert.equal(vault.protocolOk(2), false)

const status = vault.asStatus({
  type: "status",
  has_vault: true,
  unlocked: false,
  vault_id: "abc",
  has_recovery: false,
  vault_format: "v2"
})
assert.equal(status.has_vault, true)
assert.equal(status.unlocked, false)
assert.equal(status.vault_id, "abc")

const summaries = vault.asSummaries({
  type: "summaries",
  entries: [{
    id: "deadbeef",
    name: "Mail",
    username: "ada",
    urls: ["https://mail.example"],
    tags: ["work"],
    has_password: true,
    has_totp: true,
    has_notes: true,
    updated_at: 1700000000,
    password: "SHOULD-NOT-APPEAR"
  }]
})
assert.equal(summaries.entries.length, 1)
assert.equal(summaries.entries[0].name, "Mail")
assert.equal(summaries.entries[0].url, "https://mail.example")
assert.equal(summaries.entries[0].has_password, true)
assert.equal(summaries.entries[0].has_totp, true)
assert.equal(summaries.entries[0].has_notes, true)
assert.equal(summaries.entries[0].entry_id, "deadbeef")
assert.equal(summaries.entries[0].updated_at, 1700000000)
assert.equal("password" in summaries.entries[0], false)
assert.equal(vault.formatEdited(0), "")
assert.match(vault.formatEdited(Math.floor(Date.now() / 1000)), /edited just now/)
assert.match(vault.formatEdited(Math.floor(Date.now() / 1000) - 3600), /edited 1h ago/)

const err = vault.resultFromOutput(
  '{"type":"error","code":"locked","message":"vault is locked"}\n',
  "error: Locked: vault is locked\n",
  1
)
assert.equal(err.type, "error")
assert.equal(err.code, "locked")

const upsert = vault.upsertRequest({
  name: "Mail",
  username: "ada",
  password: "x",
  url: "https://mail.example"
})
const loaded = vault.asEntry({
  type: "entry",
  entry: {
    id: "aabbccdd",
    name: "Mail",
    username: "ada",
    password: "secret",
    notes: "work",
    urls: ["https://mail.example"],
    tags: ["work"],
    custom_fields: [],
    totp_secret: "MFRGG",
    created_at: 1,
    updated_at: 2
  }
})
assert.equal(loaded.id, "aabbccdd")
assert.equal(loaded.password, "secret")
assert.equal(loaded.url, "https://mail.example")
assert.equal(loaded.totp_secret, "MFRGG")

const edited = vault.upsertRequest({
  id: loaded.id,
  name: "Mail",
  username: "ada",
  password: "new",
  url: "https://mail.example",
  notes: "work",
  created_at: 1
})
assert.equal(edited.entry.id, "aabbccdd")
assert.equal(edited.entry.password, "new")
assert.equal(vault.deleteRequest("aabbccdd").op, "delete_entry")

const folders = vault.asFolders({
  type: "folders",
  folders: [{ id: "f1", name: "Work", parent: null }]
})
assert.equal(folders[0].name, "Work")
assert.equal(vault.folderName(folders, "f1"), "Work")
assert.equal(vault.findFolderByName(folders, "work").id, "f1")
assert.equal(vault.folderUpsertRequest("Home").op, "upsert_folder")
assert.equal(vault.flattenEntry({
  id: "aa",
  name: "n",
  username: "u",
  urls: [],
  tags: [],
  folder_id: "f1",
  has_password: true
}).folder_id, "f1")

assert.equal(upsert.op, "upsert_entry")
assert.equal(upsert.entry.name, "Mail")
assert.equal(upsert.entry.urls[0], "https://mail.example")
assert.equal(upsert.entry.id.length, 32)
assert.equal(vault.primaryCopyField({ has_totp: true }), "totp")
assert.equal(vault.primaryCopyField({ has_password: true, has_totp: true }), "password")
assert.equal(vault.primaryCopyField({ has_username: true, username: "ada" }), "username")
assert.equal(vault.primaryCopyField({}), "")

assert.equal("password" in vault.flattenEntry({
  id: "aa",
  name: "n",
  username: "u",
  urls: [],
  tags: [],
  has_password: true
}), false)

assert.equal(
  vault.entriesFingerprint([{ id: "a", name: "Mail" }]),
  vault.entriesFingerprint([{ id: "a", name: "Mail" }])
)
assert.notEqual(
  vault.entriesFingerprint([{ id: "a" }]),
  vault.entriesFingerprint([{ id: "b" }])
)

assert.match(vault.copyToast("password"), /Copied password/)
assert.match(vault.missingCliMessage(), /attested aegis CLI/)

console.log("vault.test.js ok")
