#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$root/bin/aegis-session-watch"
chmod +x "$bin"
bash -n "$bin"

rg -q 'omarchy-hyprland-session-locked' "$bin"
rg -q 'PrepareForSleep' "$bin"
rg -q 'PrepareForShutdown' "$bin"
rg -q "trap 'lock_vault" "$bin"
rg -q 'AEGIS_KDF' "$bin"
rg -q 'printf .LOCK' "$bin"

echo "session-watch-test.sh ok"
