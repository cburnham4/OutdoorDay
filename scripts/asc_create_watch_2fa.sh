#!/bin/bash
# Wait for a 6-digit Apple 2FA code in ~/Desktop/apple-2fa.txt, then create
# Outdoor Day in ASC and run ship-all.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="/usr/local/opt/ruby/bin:$PATH"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export FASTLANE_USER="${FASTLANE_USER:-cburnhamiv@gmail.com}"
export SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER="${SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER:-+1 (503) 929-7690}"
CODE_FILE="${ASC_2FA_FILE:-$HOME/Desktop/apple-2fa.txt}"
INTERVAL="${ASC_2FA_POLL_SECONDS:-5}"
MAX_WAIT="${ASC_2FA_MAX_WAIT:-600}"

PASS=$(security find-internet-password -s "deliver.${FASTLANE_USER}" -w 2>/dev/null || true)
[[ -z "$PASS" ]] && PASS=$(security find-generic-password -s "deliver.${FASTLANE_USER}" -w 2>/dev/null || true)
if [[ -z "$PASS" ]]; then
  echo "No keychain password for deliver.${FASTLANE_USER}"
  exit 1
fi
export FASTLANE_PASSWORD="$PASS"

cat >"$CODE_FILE" <<'EOF'
# Paste ONLY the 6-digit Apple verification code below, then Save.

EOF
osascript -e 'display notification "Paste Apple 2FA into Desktop/apple-2fa.txt then Save" with title "Outdoor Day ASC"' >/dev/null 2>&1 || true
open -a TextEdit "$CODE_FILE" >/dev/null 2>&1 || open "$CODE_FILE" >/dev/null 2>&1 || true

echo "Requesting Apple SMS 2FA to ${SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER}…"
# Kick Spaceship just far enough to send SMS; ignore EOF on the code prompt.
set +e
bundle exec ruby -e '
require "spaceship"
begin
  Spaceship::ConnectAPI.login(ENV.fetch("FASTLANE_USER"), ENV.fetch("FASTLANE_PASSWORD"))
  puts "UNEXPECTED_LOGIN_WITHOUT_2FA"
rescue EOFError
  puts "SMS_PROMPT_REACHED"
rescue => e
  puts "LOGIN_KICKOFF #{e.class}: #{e.message[0,200]}"
end
' >build/asc_create_sms_kick.log 2>&1
set -e
echo "---- sms kick ----"
cat build/asc_create_sms_kick.log || true

echo "Waiting up to ${MAX_WAIT}s for 6-digit code in $CODE_FILE …"
started=$(date +%s)
code=""
while true; do
  now=$(date +%s)
  if (( now - started > MAX_WAIT )); then
    echo "Timed out waiting for 2FA code"
    exit 2
  fi
  if [[ -f "$CODE_FILE" ]]; then
    code=$(grep -oE '[0-9]{6}' "$CODE_FILE" 2>/dev/null | head -1 || true)
  fi
  if [[ -n "$code" ]]; then
    echo "CODE_FOUND (len=${#code})"
    break
  fi
  sleep "$INTERVAL"
done

export SPACESHIP_2FA_CODE="$code"
echo "Creating ASC app with provided 2FA code…"
set +e
bundle exec ruby scripts/asc_create_interactive.rb >build/asc_create_watch.log 2>&1
create_status=$?
set -e
echo "---- create log ----"
cat build/asc_create_watch.log || true

if rg -q "CREATED|ALREADY_EXISTS" build/asc_create_watch.log 2>/dev/null; then
  echo "Running ship-all…"
  bash scripts/asc_ship_all.sh
  exit $?
fi
echo "Create failed (status=$create_status)"
exit 1
