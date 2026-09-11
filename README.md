# omarchy-aegis

Beta **v0.5.0**. Not submitted to the Omarchy plugin marketplace yet.

Search the Aegis vault and copy logins from an Omarchy overlay.

This plugin is a **client of the native `aegis` CLI**. It does not implement Argon2, PQ crypto, or vault storage. It does not talk to `aegis-dev-vault-server` or `localhost:8787`.

```
Omarchy overlay  →  aegis  →  aegis agent  →  ~/.local/share/aegis/secrets/
```

Unlock once. Search and copy hit the running agent. Argon2id (≥ 64 MiB) is not paid per keystroke.

## Requirements

- Omarchy Quattro (`omarchy-shell` plugin support)
- The native CLI from [Aegis](https://github.com/imcmurray/Aegis) (`aegis --protocol-version` must print `1`)

```bash
git clone https://github.com/imcmurray/Aegis.git
cd Aegis
cargo install --path tools/cli
aegis --protocol-version   # 1
```

The plugin looks for `aegis` on `PATH`, then `~/.cargo/bin/aegis`, then `~/.local/bin/aegis`. It runs every command as `env -u AEGIS_KDF …` so a leftover test KDF cannot weaken create/unlock.

## Install

```bash
omarchy plugin add https://github.com/imcmurray/omarchy-aegis.git --enable
```

Issues and feature requests: [github.com/imcmurray/omarchy-aegis/issues](https://github.com/imcmurray/omarchy-aegis/issues). The version line in the overlay opens a new issue. An AI agent can file one there too.

Or from this checkout:

```bash
omarchy plugin add "$PWD" --enable
omarchy plugin validate "$PWD"
```

A padlock appears on the right of the bar. The overlay title is **omarchy-aegis**. Click the padlock, or:

```bash
omarchy-shell shell summon ianm.aegis '{}'
```

Optional keybind — add to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + P", "omarchy-aegis", "omarchy-shell shell summon ianm.aegis '{}'")
```

## Usage

| | |
|---|---|
| Left click padlock | Open / close overlay |
| Right click padlock | Lock the vault |
| Enter | Copy password |
| Ctrl+Enter / Ctrl+E / row **Edit** / double-click | Edit that entry |
| Ctrl+N / **New** | New entry |
| Category chips | Filter by Aegis folder |
| **Backup** | Export or import a `.aegis` file |
| Tab / Shift+Tab | Move between form fields |
| Enter (in a form) | Next field, or save on the last field |
| Ctrl+S | Save entry / confirm backup |
| Ctrl+G | Generate password (edit form) |
| Ctrl+D | Delete entry (edit form, with confirm) |
| Ctrl+U / Ctrl+T | Copy username / TOTP |
| Ctrl+L / **Lock** | Lock the vault |
| Ctrl+Shift+E / Ctrl+Shift+I | Export / import `.aegis` |
| ↑ ↓ PgUp PgDn Home End | Move in the list |
| Escape | Back / dismiss |

Create and unlock take a few seconds (production Argon2id). A status line shows while that runs. After unlock, the agent stays up and auto-locks after 300s idle.

The plugin also locks the vault when Omarchy **locks the session**, **suspends**, or **logs out** (and if `omarchy-shell` itself exits). The agent stays running; unlock again from the overlay.

Categories are Aegis folders. Filter with the chips under search; type a category name when adding or editing an entry to assign or create one.

`.aegis` backups are the same files as the Aegis web app. Export here, Import in the browser on another PC, or the other way around. Import asks for the backup passphrase plus a new live-vault passphrase (they must differ). Importing over an existing vault needs `aegis import --replace` from the Aegis CLI.

The sealed native store lives at `~/.local/share/aegis` (or `$AEGIS_DATA`). That is what this machine uses while unlocked; it is not a portable Aegis backup. To move a vault to another PC or the web app, use **Backup → Export**.

Import requires **two** passphrases: the backup’s, and a new live-vault passphrase that must differ (Aegis D18). A normal `.aegis` restore mints a new vault identity.

## Security

- Passphrases go to `aegis --passphrase-file` via a mode `0600` file under `$XDG_RUNTIME_DIR`, then the file is deleted. Never argv, env, or process title.
- Search lists `EntrySummary` only (name, username, URL, flags). Passwords are not in the QML model.
- Clipboard copy is `aegis copy`, not `printf secret | wl-copy`.
- Session lock, suspend, and logout run `aegis lock` (Hyprland session-lock poll + logind `PrepareForSleep` / shutdown).
- No `AEGIS_KDF=test`. No `AEGIS_DEV_*`. No `~/.local/share/aegis-dev`.

If `aegis` is missing, the overlay tells you to `cargo install --path tools/cli` from the Aegis checkout.

## Remove

```bash
omarchy plugin remove ianm.aegis
```

That does not delete `~/.local/share/aegis/` or stop a running `aegis agent`. Lock or stop the agent separately if you want:

```bash
aegis lock
aegis agent stop
```

## Layout

```
manifest.json     plugin contract
Overlay.qml       summon UI
BarWidget.qml     padlock
Service.qml       process queue → aegis
Vault.js          JSON parse (no secrets in the list model)
bin/aegis-passfile        0600 passphrase files
bin/aegis-session-watch   lock vault on lock / suspend / logout
```
