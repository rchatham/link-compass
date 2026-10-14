#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LinkCompass"
CONFIGURATION="${CONFIGURATION:-Release}"
# Retain compatibility with the former SwiftPM configuration spelling.
case "$CONFIGURATION" in
  release) CONFIGURATION=Release ;;
  debug) CONFIGURATION=Debug ;;
esac
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
DERIVED_DATA="${DERIVED_DATA:-$BUILD_DIR/XcodeDerivedData}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
BUILT_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
SHARE_ENTITLEMENTS="$ROOT_DIR/Sources/LinkCompassShare/LinkCompassShare.entitlements"

cd "$ROOT_DIR"
command -v xcodegen >/dev/null 2>&1 || { echo "Install XcodeGen first: brew install xcodegen" >&2; exit 1; }
xcodegen generate
xcodebuild \
  -project "$ROOT_DIR/LinkCompass.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$BUILT_APP/Contents/PlugIns/LinkCompassShare.appex" || ! -d "$BUILT_APP/Contents/Frameworks/LinkCompassCore.framework" ]]; then
  echo "Xcode did not produce a complete app with the Share extension and Core framework." >&2
  exit 1
fi
if [[ "$APP_DIR" == "$BUILT_APP" ]]; then
  echo "BUILD_DIR must not be the Xcode products directory." >&2
  exit 1
fi
mkdir -p "$BUILD_DIR"
rm -rf "$APP_DIR"
ditto "$BUILT_APP" "$APP_DIR"

SIGN_OPTIONS=(--force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  SIGN_OPTIONS+=(--timestamp=none)
else
  SIGN_OPTIONS+=(--options runtime --timestamp)
fi
# Sign inside-out, never use --deep to sign (it can lose extension entitlements).
# Debug Xcode builds may also include executable companion dylibs.
while IFS= read -r -d '' library; do
  codesign "${SIGN_OPTIONS[@]}" "$library"
done < <(find "$APP_DIR/Contents" -type f -name '*.dylib' -print0)
while IFS= read -r -d '' framework; do
  codesign "${SIGN_OPTIONS[@]}" "$framework"
done < <(find "$APP_DIR/Contents" -depth -type d -name '*.framework' -print0)
codesign "${SIGN_OPTIONS[@]}" --entitlements "$SHARE_ENTITLEMENTS" \
  "$APP_DIR/Contents/PlugIns/LinkCompassShare.appex"
codesign "${SIGN_OPTIONS[@]}" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "Built and signed $APP_DIR (not installed or launched)."
echo "Xcode may register its derived build with Launch Services during compilation."
echo "To install/register explicitly: scripts/install-app.sh"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Ad-hoc signing is for local development. Public distribution requires Developer ID signing and notarization."
fi
