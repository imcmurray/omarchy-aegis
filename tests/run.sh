#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
node "$root/tests/vault.test.js"
/usr/bin/python3 "$root/tests/aegis-run-test.py"
bash "$root/tests/session-watch-test.sh"
bash "$root/tests/import-roundtrip.sh"

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$root"
fi

if [[ -n "${OMARCHY_PATH:-}" && -x "$(command -v qmllint || true)" ]]; then
  qmllint -I "$OMARCHY_PATH/shell" \
    "$root/Overlay.qml" "$root/BarWidget.qml" "$root/Service.qml"
fi

echo "all tests ok"
