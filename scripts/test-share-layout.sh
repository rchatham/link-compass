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

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/linkcompass-share-layout.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
# A same-file extension can exercise private presentation state without adding
# test hooks to the shipped extension or duplicating its production layout.
python3 - "$ROOT_DIR" "$TEMP_DIR/LayoutProbe.swift" <<'PY'
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
controller = root / 'Sources/LinkCompassShare/ShareViewController.swift'
probe = root / 'Tests/LinkCompassShareLayoutTests/LayoutProbe.swift'
pathlib.Path(sys.argv[2]).write_text(controller.read_text() + '\n' + probe.read_text())
PY
xcrun swiftc -parse-as-library -swift-version 5 \
  -F "$CORE_FRAMEWORK_DIR" -framework LinkCompassCore \
  -Xlinker -rpath -Xlinker "$CORE_FRAMEWORK_DIR" \
  "$TEMP_DIR/LayoutProbe.swift" \
  "$ROOT_DIR/Sources/LinkCompassShare/ShareInputLoader.swift" \
  "$ROOT_DIR/Sources/LinkCompassShare/ContainingAppHandoff.swift" \
  -o "$TEMP_DIR/probe"
if ! "$TEMP_DIR/probe" > "$TEMP_DIR/results.log" 2>&1; then
  tail -80 "$TEMP_DIR/results.log" >&2
  exit 1
fi
if rg -q 'Unable to simultaneously satisfy|Precondition failed|Assertion failed' "$TEMP_DIR/results.log"; then
  printf 'Share layout checks failed:\n' >&2
  tail -80 "$TEMP_DIR/results.log" >&2
  exit 1
fi
rg '^PASS ' "$TEMP_DIR/results.log"
echo "Share layout checks passed (24 states plus overflow scrolling; no windows, browser launches or preference writes)."
