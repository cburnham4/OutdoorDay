#!/bin/bash
# When ~/Desktop/apple-2fa.txt gets a 6-digit code, type it into Chrome Apple 2FA boxes.
set -uo pipefail
CODE_FILE="${ASC_2FA_FILE:-$HOME/Desktop/apple-2fa.txt}"
FLAG="$(cd "$(dirname "$0")/.." && pwd)/build/od_2fa_code_ready.txt"
LOG="$(cd "$(dirname "$0")/.." && pwd)/build/od_2fa_bridge.log"
mkdir -p "$(dirname "$FLAG")"
echo "$(date) bridge start" >>"$LOG"
last=""
while true; do
  code=$(grep -oE '[0-9]{6}' "$CODE_FILE" 2>/dev/null | head -1 || true)
  if [[ -n "$code" && "$code" != "$last" ]]; then
    echo "$code" >"$FLAG"
    echo "$(date) typing code into Chrome" >>"$LOG"
    osascript <<APPLESCRIPT >>"$LOG" 2>&1 || true
tell application "Google Chrome" to activate
delay 0.4
tell application "System Events"
  tell process "Google Chrome"
    set frontmost to true
  end tell
  delay 0.2
  keystroke "$code"
end tell
APPLESCRIPT
    last="$code"
    # one-shot after success attempt; keep watching for newer codes
  fi
  sleep 2
done
