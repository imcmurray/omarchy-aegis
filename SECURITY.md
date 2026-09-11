# Security

omarchy-aegis is an unsandboxed Omarchy shell plugin. It runs inside `omarchy-shell` with your user account.

**No sudo or pkexec is required.** The plugin does not install packages, write sudoers rules, or change Hyprland/Omarchy config unless you paste the optional keybind yourself.

## Report a problem

- Plugin UI / overlay: https://github.com/imcmurray/omarchy-aegis/security/advisories/new
- Vault crypto / `aegis` CLI: https://github.com/imcmurray/Aegis

Do not put passphrases or vault exports in public issues.

## What this plugin does

- Talks only to a local `aegis` binary on PATH
- Passes passphrases through mode-0600 files under `$XDG_RUNTIME_DIR` (never argv or env)
- Copies secrets with `aegis copy`, not `wl-copy` from QML
- Locks the vault on session lock, suspend, and logout

It does not reimplement Argon2, ML-KEM, ML-DSA, or vault storage.
