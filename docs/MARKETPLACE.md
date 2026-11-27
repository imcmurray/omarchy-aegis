# Marketplace listing

Listed as `ianm.aegis` (marketplace issue [6281](https://github.com/omacom/omarchy-plugin-marketplace/issues/6281)).

Do **not** open a second `[Plugin]:` issue. A newer commit is published with the [verify form](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=verify-plugin.yml): action **Verify and publish a newer upstream commit**, plugin id `ianm.aegis`, repository `https://github.com/imcmurray/omarchy-aegis`, and the full 40-character HEAD SHA.

## Listing metadata

- **Title:** `[Plugin]: omarchy-aegis`
- **Repository URL:** `https://github.com/imcmurray/omarchy-aegis`
- **Category:** `Productivity`
- **Tags:** `security`, `bar`, `quickshell`
- **Preview:** root `preview.png` (marketplace generates card/detail sizes)

## Issue body

```markdown
### Repository URL

https://github.com/imcmurray/omarchy-aegis

### Category

Productivity

### Tags

security, bar, quickshell

### Suggest a missing tag

_No response_

### Maintainer notes

Beta v0.6.4 overlay client of the native aegis CLI (password manager). Plugin id `ianm.aegis`. Requires the attested linux-x86_64 `aegis` GitHub Release artifact for Aegis v2.0.2 (actions pinned to commit SHAs; digest matches v2.0.1 because the CLI crate did not change; protocol 1 unchanged). Runtime trust is the SHA-256 in `cli.sha256` of an O_NOFOLLOW fd (not PATH, not protocol version). Install checks the release SHA256SUMS and that pin. Freenet link, sync, and delegate upgrade stay in the web app; this plugin does not open a peer or load WASM. Helpers are absolute and run in `env -i`. Passphrase files are descriptor-created in a held 0700 runtime dir and passed as `/proc/self/fd/N`. CLI processes are process-grouped with a deadline and output cap. No sudo or pkexec. Optional Hyprland bind is documented only — not installed.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
```

## Command (only after explicit approval)

```bash
gh issue create \
  --repo omacom/omarchy-plugin-marketplace \
  --title "[Plugin]: omarchy-aegis" \
  --body-file docs/MARKETPLACE.md
```

(Use the issue body section only, not this whole file.)
