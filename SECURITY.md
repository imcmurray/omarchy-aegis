# Security

omarchy-aegis is an unsandboxed Omarchy shell plugin. It runs inside `omarchy-shell` with your user account.

**No sudo or pkexec is required.** The plugin does not install packages, write sudoers rules, or change Hyprland/Omarchy config unless you paste the optional keybind yourself.

## Report a problem

- Plugin UI / overlay: https://github.com/imcmurray/omarchy-aegis/security/advisories/new
- Vault crypto / `aegis` CLI: https://github.com/imcmurray/Aegis

Do not put passphrases or vault exports in public issues.

## What this plugin does

- Talks only to an attested local `aegis` binary whose SHA-256 matches `cli.sha256` (descriptor-bound `O_NOFOLLOW` open, not PATH). The pin is the Aegis v2.0.2 linux-x86_64 release. Its workflow pins every action to a commit SHA. The CLI crate did not change, so the digest matches the v2.0.1 artifact. Protocol stays `1`
- Does not open a Freenet peer, load delegate or contract WASM, or handle link codes. Link, sync, and delegate upgrade stay in the Aegis web app. Additive fields such as `remote_change` are dropped before they reach the panel model
- Passes passphrases through mode-0600 files created in a held `$XDG_RUNTIME_DIR/aegis-omarchy` directory fd and consumed as `/proc/self/fd/N` (never argv or env)
- Runs the CLI in a closed environment with absolute helpers, a deadline, an output cap, and process-group TERM/KILL/reap
- Copies secrets with `aegis copy`, not `wl-copy` from QML (the overlay install snippet is the exception, via `/usr/bin/wl-copy`)
- Locks the vault on session lock, suspend, and logout

It does not reimplement Argon2, ML-KEM, ML-DSA, or vault storage. It does not `cargo install` or otherwise fetch crates.
