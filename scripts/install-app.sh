#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LinkCompass"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
DERIVED_DATA="$ROOT_DIR/build/XcodeDerivedData"
CONFIGURATION="${CONFIGURATION:-Release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"
BUILT_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

cd "$ROOT_DIR"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi

xcodebuild \
  -project "$ROOT_DIR/LinkCompass.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$BUILT_APP" ]]; then
  echo "Expected built app at $BUILT_APP" >&2
  exit 1
fi

pkill -x "$APP_NAME" 2>/dev/null || true
mkdir -p "$INSTALL_DIR"
rm -rf "$TARGET_APP"
ditto "$BUILT_APP" "$TARGET_APP"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$TARGET_APP"
else
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$TARGET_APP"
fi
"$LSREGISTER" -f -R "$TARGET_APP"

open -R "$TARGET_APP"

echo "Installed and registered $TARGET_APP"
echo "Signing details:"
codesign -dv "$TARGET_APP" 2>&1 | sed 's/^/  /'
echo "Gatekeeper assessment:"
spctl --assess --type execute -vv "$TARGET_APP" 2>&1 | sed 's/^/  /' || true
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Installed with ad-hoc signing. For public distribution, set SIGN_IDENTITY to a Developer ID identity and notarize the app."
fi
echo "If System Settings still does not list LinkCompass, use the app's Set Automatically button or log out/in to refresh Launch Services UI caches."
