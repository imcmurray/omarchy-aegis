#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$root/bin/aegis-passfile"
chmod +x "$bin"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/aegis-omarchy-test-runtime}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
secret=$'hunter2-not-a-real-passphrase'

path="$("$bin" <<<"$secret")"
test -n "$path"
test -f "$path"

mode="$(stat -c '%a' "$path")"
test "$mode" = "600"

got="$(cat "$path")"
# helper stores stdin as-is; CLI strips a trailing newline
test "${got%$'\n'}" = "$secret"

# path must not be under the plugin dir
case "$path" in
  "$root"*) echo "passfile wrote inside plugin dir: $path" >&2; exit 1 ;;
esac

rm -f -- "$path"
echo "passfile-test.sh ok"
