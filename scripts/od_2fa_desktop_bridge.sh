#!/bin/bash
# When ~/Desktop/apple-2fa.txt gets a 6-digit code, inject it into Chrome Apple 2FA.
set -uo pipefail
CODE_FILE="${ASC_2FA_FILE:-$HOME/Desktop/apple-2fa.txt}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLAG="$ROOT/build/od_2fa_code_ready.txt"
LOG="$ROOT/build/od_2fa_bridge.log"
mkdir -p "$ROOT/build"
echo "$(date) bridge start" >>"$LOG"
last=""
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
    set found to false
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
  fi
  sleep 2
done
