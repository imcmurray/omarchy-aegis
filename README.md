# omarchy-aegis

Your Aegis vault, summoned from the Omarchy bar. Search, copy, edit, lock with the session.

![omarchy-aegis welcome overlay](preview.png)

This is a **client of the native [`aegis`](https://github.com/imcmurray/Aegis) CLI**. Crypto stays in `aegis`. The overlay never reimplements Argon2, PQ KEM/signatures, or vault storage. It does not talk to `aegis-dev-vault-server`.

```
Omarchy overlay  →  aegis  →  aegis agent  →  ~/.local/share/aegis/secrets/
```

Unlock once. Search and copy hit the running agent. Argon2id (≥ 64 MiB) is not paid per keystroke.

**Beta v0.5.1.** Built for Omarchy Quattro. Feedback welcome — **About** (or F1) in the overlay, or [open an issue](https://github.com/imcmurray/omarchy-aegis/issues/new/choose).

## Install

Requires [`aegis`](https://github.com/imcmurray/Aegis) on `PATH` (`aegis --protocol-version` must print `1`).

**No sudo or pkexec is required.** This plugin does not install packages or edit Hyprland/Omarchy config unless you add the optional keybind below.

Pin the CLI to [v2.0.0-rc.1.1](https://github.com/imcmurray/Aegis/releases/tag/v2.0.0-rc.1.1) (`cd99293…`, includes `import --replace`). Detached checkout and build are one `&&` chain so a failed pin cannot fall through to `cargo install`:

```bash
git clone https://github.com/imcmurray/Aegis.git && cd Aegis && git checkout --detach cd99293f90312a53d6f45366db05fb1b79e341c6 && cargo install --path tools/cli && aegis --protocol-version
```

Then:

```bash
omarchy plugin add https://github.com/imcmurray/omarchy-aegis.git --enable
```

The padlock lands on the right of the bar. Click it, or:

```bash
omarchy-shell shell summon ianm.aegis '{}'
```

Optional keybind — you add this yourself; the plugin never writes `bindings.lua`:

```lua
o.bind("SUPER + SHIFT + P", "omarchy-aegis", "omarchy-shell shell summon ianm.aegis '{}'")
```

The plugin looks for `aegis` on `PATH`, then `~/.cargo/bin/aegis`, then `~/.local/bin/aegis`. Every command runs as `env -u AEGIS_KDF …`. If the CLI is missing, the overlay shows the install commands, a copy button, and **Recheck**.

## What you get

- Overlay search: Enter copies the password (`aegis copy`, 30s wipe)
- Row **Edit** on hover or keyboard selection; Ctrl+N for a new entry
- Categories (Aegis folders), TOTP, notes, generated passwords
- Session lock, suspend, and logout lock the vault
- **Backup** exports/imports the same `.aegis` files as the [web app](https://imcmurray.github.io/Aegis/). Import into a **new** vault is the default. Import **over** an existing vault needs **Replace existing vault** (`aegis import --replace`, CLI `v2.0.0-rc.1.1` / `cd99293`). That is ordinary backup restore: **new `vault_id`**, new live passphrase (must differ from the backup passphrase). It is not Recovery Kit identity preservation.
- **About** explains Aegis, post-quantum hybrid crypto, and where to send feedback

![About](docs/screenshots/about.png)

The listing preview is the first-run create vault screen (`preview.png`). Extra shots live in `docs/screenshots/`.

## Keyboard

| | |
|---|---|
| Enter | Copy password |
| Ctrl+E / Ctrl+Enter | Edit selected |
| Ctrl+N | New entry |
| Ctrl+U / Ctrl+T | Copy username / TOTP |
| Ctrl+L | Lock |
| F1 | About |
| Esc | Back / dismiss |

## Remove

```bash
omarchy plugin remove ianm.aegis
```

That does not delete `~/.local/share/aegis/` or stop `aegis agent`:

```bash
aegis lock
aegis agent stop
```

## Security

- Passphrases go through `--passphrase-file` (mode `0600` under `$XDG_RUNTIME_DIR`), never argv or env
- Search lists metadata only — no passwords in the QML model
- Clipboard copy is `aegis copy`, not `printf secret \| wl-copy`
- Plugins run unsandboxed inside `omarchy-shell`. Read the repo before `--enable`

Portable copy of a vault is **Backup → Export** (a `.aegis` file). `~/.local/share/aegis` is the sealed local store, not a file you copy to another PC.

CLI equivalent of the overlay’s Replace toggle (`aegis` `v2.0.0-rc.1.1`):

```bash
aegis import --replace \
  --backup-passphrase-file backup.pw \
  --new-passphrase-file live.pw \
  vault.aegis
```

The result is a **new live vault** (new `vault_id`). Recovery Kit + secret is what preserves identity.

## License

MIT. See `LICENSE` and `NOTICE`. The `encrypted_add` mark is Material Symbols (Apache-2.0, Google). No sudo or pkexec is required.
