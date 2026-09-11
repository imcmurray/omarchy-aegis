#!/usr/bin/env bash
# Same argv the plugin uses: create → export → import --replace → search.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${HOME}/.cargo/bin:${HOME}/.local/bin:${PATH}"

if ! command -v aegis >/dev/null 2>&1; then
  echo "skip: aegis not on PATH" >&2
  exit 0
fi
if ! aegis import --help 2>&1 | grep -q -- '--replace'; then
  echo "fail: this aegis has no --replace (plugin import-over-existing will error)" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'aegis --data-dir "$tmp/src" --runtime-dir "$tmp/src-run" agent stop >/dev/null 2>&1 || true
      aegis --data-dir "$tmp/dst" --runtime-dir "$tmp/dst-run" agent stop >/dev/null 2>&1 || true
      rm -rf "$tmp"' EXIT

umask 077
printf 'src-passphrase-ok\n' >"$tmp/src.pw"
printf 'backup-passphrase-ok\n' >"$tmp/backup.pw"
printf 'dst-live-passphrase\n' >"$tmp/dst.pw"
chmod 600 "$tmp"/*.pw

export AEGIS_KDF=test
src=(--data-dir "$tmp/src" --runtime-dir "$tmp/src-run")
dst=(--data-dir "$tmp/dst" --runtime-dir "$tmp/dst-run")

aegis "${src[@]}" --passphrase-file "$tmp/src.pw" create
aegis "${src[@]}" --passphrase-file "$tmp/src.pw" unlock
printf '%s\n' '{"op":"upsert_entry","entry":{"id":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","folder_id":null,"name":"PluginMail","urls":["https://mail.example"],"username":"ada","password":"inbox-secret","notes":"n","custom_fields":[],"tags":[],"created_at":1,"updated_at":1}}' \
  | aegis "${src[@]}" rpc >/dev/null
aegis "${src[@]}" export --backup-passphrase-file "$tmp/backup.pw" "$tmp/vault.aegis"

aegis "${dst[@]}" --passphrase-file "$tmp/dst.pw" create
# Plugin flag order when Replace existing vault is on:
aegis "${dst[@]}" --json import \
  --backup-passphrase-file "$tmp/backup.pw" \
  --new-passphrase-file "$tmp/dst.pw" \
  --replace \
  "$tmp/vault.aegis" >/dev/null

aegis "${dst[@]}" --passphrase-file "$tmp/dst.pw" unlock
out="$(aegis "${dst[@]}" --json search PluginMail)"
echo "$out" | grep -q PluginMail
echo "$out" | grep -qv inbox-secret
echo "import-roundtrip.sh ok"
