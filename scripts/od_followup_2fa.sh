#!/bin/bash
# Poll FollowUpUI for Apple trusted-device 2FA code; write to apple-2fa.txt
set -uo pipefail
CODE_FILE="${ASC_2FA_FILE:-$HOME/Desktop/apple-2fa.txt}"
LOG="$(cd "$(dirname "$0")/.." && pwd)/build/od_followup_2fa.log"
mkdir -p "$(dirname "$LOG")"
echo "$(date) followup watch start" >>"$LOG"
while true; do
  code=$(osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "System Events"
  if not (exists process "FollowUpUI") then return ""
  tell process "FollowUpUI"
    try
      repeat with b in buttons of window 1
        try
          if (name of b as string) is "Allow" then
            perform action "AXPress" of b
            delay 1.2
          end if
        end try
      end repeat
    end try
    try
      set texts to value of every static text of window 1
      repeat with t in texts
        set ts to t as string
        if (length of ts) = 6 then
          try
            do shell script "echo " & quoted form of ts & " | grep -E '^[0-9]{6}$'"
            return ts
          end try
        end if
      end repeat
    end try
    -- deep scan
    try
      repeat with el in entire contents of window 1
        try
          set val to value of el as string
          if (length of val) = 6 then
            do shell script "echo " & quoted form of val & " | grep -E '^[0-9]{6}$'"
            return val
          end if
        end try
        try
          set nm to name of el as string
          if (length of nm) = 6 then
            do shell script "echo " & quoted form of nm & " | grep -E '^[0-9]{6}$'"
            return nm
          end if
        end try
      end repeat
    end try
  end tell
end tell
return ""
APPLESCRIPT
)
  if [[ -n "$code" ]]; then
    echo "$(date) CODE=$code" >>"$LOG"
    # Append without wiping comments if already has this code
    if ! grep -q "$code" "$CODE_FILE" 2>/dev/null; then
      printf '\n%s\n' "$code" >>"$CODE_FILE"
    fi
    echo "$code"
    # Don't exit — keep watching for next challenges; bridge/watcher will consume
  fi
  sleep 2
done
