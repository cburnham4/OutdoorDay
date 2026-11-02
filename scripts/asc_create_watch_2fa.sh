#!/bin/bash
# Trigger Apple login + wait for a 6-digit code in ~/Desktop/apple-2fa.txt
# Then create Outdoor Day in ASC and run ship-all.
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
if [[ -z "$PASS" ]]; then
  PASS=$(security find-generic-password -s "deliver.${FASTLANE_USER}" -w 2>/dev/null || true)
fi
if [[ -z "$PASS" ]]; then
  echo "No keychain password for deliver.${FASTLANE_USER}"
  exit 1
fi
export FASTLANE_PASSWORD="$PASS"

cat >"$HOME/Desktop/apple-2fa.txt" <<EOF
# Paste ONLY the 6-digit Apple verification code on the next line, then save.
# (Delete these comment lines or leave them — the watcher picks the first 6-digit token.)

EOF
osascript -e 'display notification "Paste Apple 2FA into Desktop/apple-2fa.txt" with title "Outdoor Day ASC"' >/dev/null 2>&1 || true
open -a TextEdit "$CODE_FILE" >/dev/null 2>&1 || open "$CODE_FILE" >/dev/null 2>&1 || true

echo "Waiting up to ${MAX_WAIT}s for 6-digit code in $CODE_FILE …"
echo "(SMS should arrive after login starts — keep this terminal/agent running.)"
started=$(date +%s)

# Start login in background via expect-like ruby that blocks on stdin from a fifo
FIFO=$(mktemp -u /tmp/od-2fa-fifo.XXXXXX)
mkfifo "$FIFO"
cleanup() { rm -f "$FIFO"; }
trap cleanup EXIT

(
  # Feed ruby stdin from fifo
  export SPACESHIP_SKIP_2FA_UPGRADE=1
  bundle exec ruby -e '
require "spaceship"
user=ENV.fetch("FASTLANE_USER")
pass=ENV.fetch("FASTLANE_PASSWORD")
puts "LOGIN_START #{user}"
Spaceship::ConnectAPI.login(user, pass)
puts "LOGIN_OK"
apps=Spaceship::ConnectAPI::App.all
hit=apps.find{|a| a.bundle_id=="us.letshang.outdoor-day"}
if hit
  puts "ALREADY_EXISTS #{hit.id}"
else
  app=Spaceship::ConnectAPI::App.create(
    name:"Outdoor Day", primary_locale:"en-US", version_string:"1.0",
    sku:"outdoor-day-001", bundle_id_identifier:"us.letshang.outdoor-day",
    platforms:["IOS"]
  )
  puts "CREATED #{app.id}"
end
' <"$FIFO" >build/asc_create_watch.log 2>&1 &
  echo $! >build/asc_create_watch.pid
) &

# Keep fifo open for writing
exec 3>"$FIFO"

# Give Spaceship a moment to request SMS / prompt
sleep 8

code=""
while true; do
  now=$(date +%s)
  if (( now - started > MAX_WAIT )); then
    echo "Timed out waiting for 2FA code"
    exec 3>&-
    exit 2
  fi
  if [[ -f "$CODE_FILE" ]]; then
    # First 6 consecutive digits in the file
    code=$(rg -oN --pcre2 '(?<![0-9])[0-9]{6}(?![0-9])' "$CODE_FILE" 2>/dev/null | head -1 || true)
    if [[ -z "$code" ]]; then
      code=$(grep -oE '[0-9]{6}' "$CODE_FILE" 2>/dev/null | head -1 || true)
    fi
  fi
  if [[ -n "$code" ]]; then
    echo "CODE_FOUND ****** (len=${#code})"
    printf '%s\n' "$code" >&3
    exec 3>&-
    break
  fi
  sleep "$INTERVAL"
done

# Wait for ruby create
pid=$(cat build/asc_create_watch.pid 2>/dev/null || true)
if [[ -n "$pid" ]]; then
  for i in $(seq 1 60); do
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 2
  done
  wait "$pid" 2>/dev/null || true
fi
echo "---- create log ----"
tail -40 build/asc_create_watch.log || true

if rg -q "CREATED|ALREADY_EXISTS" build/asc_create_watch.log 2>/dev/null; then
  echo "Running ship-all…"
  bash scripts/asc_ship_all.sh
  exit $?
fi
echo "Create did not succeed — see build/asc_create_watch.log"
exit 1
