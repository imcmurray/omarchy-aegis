#!/usr/bin/env bash
# Compatibility wrapper: passphrase files are created inside aegis-run.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
/usr/bin/python3 "$root/tests/aegis-run-test.py"
echo "passfile-test.sh ok"
