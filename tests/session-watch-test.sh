#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$root/bin/aegis-run"
/usr/bin/python3 -m py_compile "$bin"

rg -q 'omarchy-hyprland-session-locked' "$bin"
rg -q 'PrepareForSleep' "$bin"
rg -q 'PrepareForShutdown' "$bin"
rg -q 'PR_SET_PDEATHSIG' "$bin"
rg -q 'printf|LOCK' "$bin"
rg -q 'LINE_CAP' "$bin"
rg -q '/usr/bin/gdbus' "$bin"
rg -q '/usr/bin/dbus-monitor' "$bin"
if rg -q 'HOME}/.cargo/bin:|PATH=.*cargo' "$bin"; then
  echo "session watcher still prepends user-writable PATH" >&2
  exit 1
fi
if rg -q 'command -v' "$bin"; then
  echo "session watcher still PATH-resolves helpers" >&2
  exit 1
fi

echo "session-watch-test.sh ok"
