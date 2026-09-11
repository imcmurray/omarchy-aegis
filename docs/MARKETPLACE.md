# Marketplace listing (not submitted yet)

When we are ready, submit via the [Omarchy plugin marketplace](https://plugins.omarchy.org/publish.html) using [SUBMISSION.md](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md).

Do **not** open the issue until the owner says to submit.

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

Beta v0.5.1 overlay client of the native aegis CLI (password manager). Plugin id `ianm.aegis`. Requires `aegis` on PATH; README pins https://github.com/imcmurray/Aegis to commit fd6feb82f7bef0b7350bc1fc74515c8f5c8da145. No sudo or pkexec. Optional Hyprland bind is documented only — not installed.

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
