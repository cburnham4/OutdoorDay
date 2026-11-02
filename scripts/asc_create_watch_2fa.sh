#!/bin/bash
# Single Spaceship login: Apple texts a 2FA code → paste into
# ~/Desktop/apple-2fa.txt → create Outdoor Day → ship-all.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="/usr/local/opt/ruby/bin:$PATH"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export FASTLANE_USER="${FASTLANE_USER:-cburnhamiv@gmail.com}"
export SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER="${SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER:-+1 (503) 929-7690}"
CODE_FILE="${ASC_2FA_FILE:-$HOME/Desktop/apple-2fa.txt}"
INTERVAL="${ASC_2FA_POLL_SECONDS:-3}"
MAX_WAIT="${ASC_2FA_MAX_WAIT:-600}"

PASS=$(security find-internet-password -s "deliver.${FASTLANE_USER}" -w 2>/dev/null || true)
[[ -z "$PASS" ]] && PASS=$(security find-generic-password -s "deliver.${FASTLANE_USER}" -w 2>/dev/null || true)
[[ -n "$PASS" ]] || { echo "No keychain password for deliver.${FASTLANE_USER}"; exit 1; }
export FASTLANE_PASSWORD="$PASS"

cat >"$CODE_FILE" <<'EOF'
# Paste the 6-digit Apple SMS code below, then Save.
# Use the code from the text that arrives AFTER this watcher starts.

EOF
osascript -e 'display notification "Apple will text a code — paste it into Desktop/apple-2fa.txt" with title "Outdoor Day ASC"' >/dev/null 2>&1 || true
open -a TextEdit "$CODE_FILE" >/dev/null 2>&1 || open "$CODE_FILE" >/dev/null 2>&1 || true

FIFO=$(mktemp -u /tmp/od-2fa.XXXXXX)
mkfifo "$FIFO"
LOG=build/asc_create_watch.log
: >"$LOG"
cleanup() { rm -f "$FIFO"; }
trap cleanup EXIT

# Open FIFO read/write so neither side blocks on open().
exec 3<>"$FIFO"

bundle exec ruby -e '
require "spaceship"
user = ENV.fetch("FASTLANE_USER")
pass = ENV.fetch("FASTLANE_PASSWORD")
puts "LOGIN_START #{user}"
$stdout.flush
Spaceship::ConnectAPI.login(user, pass)
puts "LOGIN_OK"
$stdout.flush
apps = Spaceship::ConnectAPI::App.all
hit = apps.find { |a| a.bundle_id == "us.letshang.outdoor-day" }
if hit
  puts "ALREADY_EXISTS #{hit.id}"
else
  app = Spaceship::ConnectAPI::App.create(
    name: "Outdoor Day",
    primary_locale: "en-US",
    version_string: "1.0",
    sku: "outdoor-day-001",
    bundle_id_identifier: "us.letshang.outdoor-day",
    platforms: ["IOS"]
  )
  puts "CREATED #{app.id}"
end
' <"$FIFO" >"$LOG" 2>&1 &
RUBY_PID=$!
echo "RUBY_PID=$RUBY_PID"

echo "Waiting for Spaceship to request SMS…"
for i in $(seq 1 60); do
  if rg -q "Successfully requested text message|Please enter the 6 digit code" "$LOG" 2>/dev/null; then
    echo "SMS_REQUESTED"
    break
  fi
  if ! kill -0 "$RUBY_PID" 2>/dev/null; then
    echo "Ruby exited early:"; cat "$LOG"; exit 1
  fi
  sleep 1
done

echo "Waiting up to ${MAX_WAIT}s for code in $CODE_FILE …"
started=$(date +%s)
code=""
while true; do
  now=$(date +%s)
  if (( now - started > MAX_WAIT )); then
    echo "Timed out"; kill "$RUBY_PID" 2>/dev/null || true; exit 2
  fi
  if ! kill -0 "$RUBY_PID" 2>/dev/null; then
    echo "Ruby exited while waiting:"; cat "$LOG"; exit 1
  fi
  if [[ -f "$CODE_FILE" ]]; then
    code=$(grep -oE '[0-9]{6}' "$CODE_FILE" 2>/dev/null | head -1 || true)
  fi
  if [[ -n "$code" ]]; then
    echo "CODE_FOUND len=${#code}"
    printf '%s\n' "$code" >&3
    break
  fi
  sleep "$INTERVAL"
done

exec 3>&-
wait "$RUBY_PID"
status=$?
echo "---- create log ----"
cat "$LOG"
if rg -q "CREATED|ALREADY_EXISTS" "$LOG"; then
  echo "Running ship-all…"
  bash scripts/asc_ship_all.sh
  exit $?
fi
echo "Create failed status=$status"
exit 1
