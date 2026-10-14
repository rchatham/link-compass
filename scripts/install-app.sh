#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LinkCompass"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
LAUNCH_APP="${LAUNCH_APP:-0}"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"
BUILT_APP="$BUILD_DIR/$APP_NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# Xcode may register its derived product while building; this script explicitly
# installs and registers the complete packaged app.
BUILD_DIR="$BUILD_DIR" "$ROOT_DIR/scripts/make-app.sh"
if [[ "$TARGET_APP" == "$BUILT_APP" ]]; then
  echo "INSTALL_DIR must be different from BUILD_DIR." >&2
  exit 1
fi
if pgrep -x "$APP_NAME" >/dev/null; then
  pkill -x "$APP_NAME"
fi
mkdir -p "$INSTALL_DIR"
rm -rf "$TARGET_APP"
ditto "$BUILT_APP" "$TARGET_APP"
codesign --verify --deep --strict --verbose=2 "$TARGET_APP"
"$LSREGISTER" -f -R "$TARGET_APP"
if [[ "$LAUNCH_APP" == "1" ]]; then
  open "$TARGET_APP"
fi

echo "Installed and registered $TARGET_APP (including its Share extension)."
echo "Open LinkCompass, then enable it in macOS Share extensions settings if it is not in the Share menu."
echo "Use LAUNCH_APP=1 to launch after installation. Ad-hoc builds are for local development only."
