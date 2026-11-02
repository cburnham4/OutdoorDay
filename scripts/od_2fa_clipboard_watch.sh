#!/bin/bash
# If a 6-digit code appears on the pasteboard, write it to apple-2fa.txt
set -uo pipefail
CODE_FILE="${ASC_2FA_FILE:-$HOME/Desktop/apple-2fa.txt}"
LOG="$(cd "$(dirname "$0")/.." && pwd)/build/od_2fa_clipboard.log"
mkdir -p "$(dirname "$LOG")"
echo "$(date) clipboard watch start" >>"$LOG"
last=""
while true; do
  clip=$(pbpaste 2>/dev/null | tr -d '\n\r ' || true)
  code=$(printf '%s' "$clip" | grep -oE '[0-9]{6}' | head -1 || true)
  # Also accept "Apple ID code is 123456" style
  if [[ -z "$code" ]]; then
    code=$(pbpaste 2>/dev/null | grep -oE '[0-9]{6}' | head -1 || true)
  fi
  if [[ -n "$code" && "$code" != "$last" ]]; then
    # Ignore codes already in file
    existing=$(grep -oE '[0-9]{6}' "$CODE_FILE" 2>/dev/null | head -1 || true)
    if [[ "$code" != "$existing" ]]; then
      echo "$(date) clipboard code -> $CODE_FILE" >>"$LOG"
      printf '%s\n' "$code" >"$CODE_FILE"
      last="$code"
      osascript -e 'display notification "Captured 6-digit code from clipboard — signing in" with title "Outdoor Day 2FA"' >/dev/null 2>&1 || true
    fi
  fi
  sleep 1
done
