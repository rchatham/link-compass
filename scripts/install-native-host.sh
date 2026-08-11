#!/usr/bin/env bash
set -euo pipefail

HOST_NAME="io.github.rchatham.linkcompass"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

swift build -c release --product linkcompass-native-host
HOST_PATH="$REPO_ROOT/.build/release/linkcompass-native-host"

if [[ ! -x "$HOST_PATH" ]]; then
  echo "Native host executable not found at $HOST_PATH" >&2
  exit 1
fi

write_manifest() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/$HOST_NAME.json" <<JSON
{
  "name": "$HOST_NAME",
  "description": "LinkCompass native messaging host",
  "path": "$HOST_PATH",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://REPLACE_WITH_UNPACKED_EXTENSION_ID/"
  ]
}
JSON
  echo "Wrote $dir/$HOST_NAME.json"
}

write_manifest "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
write_manifest "$HOME/Library/Application Support/Chromium/NativeMessagingHosts"
write_manifest "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
write_manifest "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"

cat <<EOF

Next steps:
1. Open chrome://extensions (or brave://extensions / edge://extensions).
2. Enable Developer mode.
3. Load unpacked extension from:
   $REPO_ROOT/Extensions/Chrome
4. Copy the extension ID.
5. Replace REPLACE_WITH_UNPACKED_EXTENSION_ID in each manifest above with that ID.
6. Reload the extension.

EOF
