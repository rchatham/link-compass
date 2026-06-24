#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/LinkCompass.app"
TEST_URL="${1:-https://example.com}"

"$ROOT_DIR/scripts/make-app.sh" >/dev/null

pkill -x LinkCompass 2>/dev/null || true
open -a "$APP_DIR" --args >/dev/null 2>&1 || true
sleep 1

if ! pgrep -x LinkCompass >/dev/null; then
  echo "Smoke test failed: LinkCompass did not launch" >&2
  exit 1
fi

open -a "$APP_DIR" "$TEST_URL"
sleep 1

if ! pgrep -x LinkCompass >/dev/null; then
  echo "Smoke test failed: LinkCompass exited after receiving $TEST_URL" >&2
  exit 1
fi

pkill -x LinkCompass 2>/dev/null || true

echo "Smoke test passed: launched LinkCompass and delivered $TEST_URL"
echo "Note: this does not click the chooser or verify default-browser System Settings registration."
