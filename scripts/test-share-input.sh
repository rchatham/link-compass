#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT_DIR/build/XcodeDerivedData}"
CORE_FRAMEWORK_DIR="${CORE_FRAMEWORK_DIR:-$DERIVED_DATA/Build/Products/$CONFIGURATION}"
if [[ ! -d "$CORE_FRAMEWORK_DIR/LinkCompassCore.framework" ]]; then
  echo "Build the complete app first: CONFIGURATION=$CONFIGURATION scripts/make-app.sh" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/linkcompass-share-input.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
# Compile the shipped loader, not a copy of its validation/selection logic.
xcrun swiftc -parse-as-library -swift-version 5 \
  -F "$CORE_FRAMEWORK_DIR" -framework LinkCompassCore \
  -Xlinker -rpath -Xlinker "$CORE_FRAMEWORK_DIR" \
  "$ROOT_DIR/Sources/LinkCompassShare/ShareInputLoader.swift" \
  "$ROOT_DIR/Tests/LinkCompassShareInputTests/InputProbe.swift" \
  -o "$TEMP_DIR/probe"
# Each async case has a run-loop deadline. An outer watchdog also bounds a
# synchronous hang inside a provider/loader before that deadline can run.
if ! python3 - "$TEMP_DIR/probe" > "$TEMP_DIR/results.log" 2>&1 <<'PY'
import subprocess
import sys
try:
    result = subprocess.run([sys.argv[1]], timeout=60)
except subprocess.TimeoutExpired:
    print('FAIL Share input probe exceeded its 60-second process timeout', flush=True)
    sys.exit(1)
sys.exit(result.returncode)
PY
then
  tail -80 "$TEMP_DIR/results.log" >&2
  exit 1
fi
rg '^PASS ' "$TEMP_DIR/results.log"
echo "Share input checks passed (no windows, browser launches, real-file input or preference writes)."
