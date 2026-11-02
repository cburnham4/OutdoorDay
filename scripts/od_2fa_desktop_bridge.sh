#!/bin/bash
# When ~/Desktop/apple-2fa.txt gets a 6-digit code, inject it into Chrome Apple 2FA,
# then try New App create on ASC /apps once login lands.
set -uo pipefail
CODE_FILE="${ASC_2FA_FILE:-$HOME/Desktop/apple-2fa.txt}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLAG="$ROOT/build/od_2fa_code_ready.txt"
LOG="$ROOT/build/od_2fa_bridge.log"
CREATE_JS="$ROOT/scripts/od_asc_create_app.js"
mkdir -p "$ROOT/build"
echo "$(date) bridge start" >>"$LOG"
last=""

run_chrome_js_file() {
  local jsfile="$1"
  # Wrap file contents as execute javascript source (async IIFE already).
  local js
  js=$(cat "$jsfile")
  osascript <<APPLESCRIPT >>"$LOG" 2>&1 || true
with timeout of 20 seconds
  tell application "Google Chrome"
    activate
    set js to $(printf '%s' "$js" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
    repeat with w in windows
      repeat with t in tabs of w
        set u to URL of t as text
        if u contains "appstoreconnect.apple.com" then
          set active tab index of w to index of t
          set index of w to 1
          try
            set r to execute javascript js in t
            return r
          end try
        end if
      end repeat
    end repeat
    return "NO_ASC_APPS_TAB"
  end tell
end timeout
APPLESCRIPT
}

try_create_after_login() {
  echo "$(date) waiting for ASC /apps after 2FA…" >>"$LOG"
  local i
  for i in $(seq 1 40); do
    local url
    url=$(osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "Google Chrome"
  repeat with w in windows
    repeat with t in tabs of w
      set u to URL of t as text
      if u contains "appstoreconnect.apple.com" then return u
    end repeat
  end repeat
  return ""
end tell
APPLESCRIPT
)
    if [[ "$url" == *"/apps"* && "$url" != *"signin"* && "$url" != *"login"* && "$url" != *"idmsa"* ]]; then
      echo "$(date) on ASC apps ($url) — running New App fill" >>"$LOG"
      # Navigate to /apps if needed
      osascript <<'APPLESCRIPT' >>"$LOG" 2>&1 || true
with timeout of 10 seconds
  tell application "Google Chrome"
    repeat with w in windows
      repeat with t in tabs of w
        set u to URL of t as text
        if u contains "appstoreconnect.apple.com" then
          set active tab index of w to index of t
          set URL of t to "https://appstoreconnect.apple.com/apps"
          return "NAV_APPS"
        end if
      end repeat
    end repeat
  end tell
end timeout
APPLESCRIPT
      sleep 3
      run_chrome_js_file "$CREATE_JS"
      echo "$(date) create JS finished" >>"$LOG"
      return 0
    fi
    sleep 3
  done
  echo "$(date) ASC /apps not reached after 2FA inject" >>"$LOG"
}

while true; do
  code=$(grep -oE '[0-9]{6}' "$CODE_FILE" 2>/dev/null | head -1 || true)
  if [[ -n "$code" && "$code" != "$last" ]]; then
    echo "$code" >"$FLAG"
    echo "$(date) injecting code into Chrome" >>"$LOG"
    # Prefer JS injection into idmsa iframe (short AppleEvent timeout)
    osascript <<APPLESCRIPT >>"$LOG" 2>&1 || true
with timeout of 8 seconds
  tell application "Google Chrome"
    activate
    set js to "(() => { try { const d=document.querySelector('iframe').contentDocument; const inputs=[...d.querySelectorAll('input.form-security-code-input')]; const code='$code'; if(inputs.length>=6){ for(let i=0;i<6;i++){ const el=inputs[i]; const setter=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set; el.focus(); setter.call(el, code[i]); el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); } return 'FILLED_'+inputs.length; } const one=d.querySelector('input[type=tel],input[type=text],input[type=password]'); if(one){ one.focus(); one.value=code; one.dispatchEvent(new Event('input',{bubbles:true})); return 'FILLED_SINGLE'; } return 'NO_INPUTS body='+(d.body.innerText||'').slice(0,120); } catch(e){ return 'ERR_'+e; } })()"
    repeat with w in windows
      repeat with t in tabs of w
        set u to URL of t as text
        if u contains "idmsa.apple.com" or u contains "appleid.apple.com" or u contains "appstoreconnect.apple.com" then
          set active tab index of w to index of t
          set index of w to 1
          set r to execute javascript js in t
          return r
        end if
      end repeat
    end repeat
    return "NO_ASC_TAB"
  end tell
end timeout
APPLESCRIPT
    # Fallback: keystroke into frontmost Chrome
    osascript <<APPLESCRIPT >>"$LOG" 2>&1 || true
with timeout of 5 seconds
  tell application "Google Chrome" to activate
  delay 0.3
  tell application "System Events"
    keystroke "$code"
  end tell
end timeout
APPLESCRIPT
    last="$code"
    echo "$(date) inject attempted" >>"$LOG"
    try_create_after_login &
  fi
  sleep 2
done
