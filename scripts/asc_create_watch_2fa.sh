#!/bin/bash
# Single Spaceship login: Apple texts a 2FA code → paste into
# ~/Desktop/apple-2fa.txt → create Outdoor Day → ship-all.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="/usr/local/opt/ruby/bin:$PATH"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export FASTLANE_USER="${FASTLANE_USER:-cburnhamiv@gmail.com}"
# Must stay quoted — unquoted "+1 (503) ..." truncates to "+1" and blocks SMS.
DEFAULT_2FA_PHONE='+1 (503) 929-7690'
if [[ -z "${SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER:-}" || "${SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER}" == "+1" ]]; then
  export SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER="$DEFAULT_2FA_PHONE"
fi
echo "2FA_PHONE=${SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER}"
CODE_FILE="${ASC_2FA_FILE:-$HOME/Desktop/apple-2fa.txt}"
INTERVAL="${ASC_2FA_POLL_SECONDS:-3}"
MAX_WAIT="${ASC_2FA_MAX_WAIT:-600}"

PASS=$(security find-internet-password -s "deliver.${FASTLANE_USER}" -w 2>/dev/null || true)
[[ -z "$PASS" ]] && PASS=$(security find-generic-password -s "deliver.${FASTLANE_USER}" -w 2>/dev/null || true)
[[ -n "$PASS" ]] || { echo "No keychain password for deliver.${FASTLANE_USER}"; exit 1; }
export FASTLANE_PASSWORD="$PASS"

# ASC_2FA_NO_RESEND=1 (default): do not request a new SMS — Apple rate-limits
# after several attempts. Paste the last code already received.
export ASC_2FA_NO_RESEND="${ASC_2FA_NO_RESEND:-1}"

# Do not clobber an existing 6-digit code the user already pasted.
existing_code=""
if [[ -f "$CODE_FILE" ]]; then
  existing_code=$(grep -oE '[0-9]{6}' "$CODE_FILE" 2>/dev/null | head -1 || true)
fi
if [[ -z "$existing_code" ]]; then
  if [[ "$ASC_2FA_NO_RESEND" == "1" ]]; then
    cat >"$CODE_FILE" <<'EOF'
# Paste/copy Apple 6-digit code (device or SMS), then Save.
# Clipboard is also watched.

EOF
    osascript -e 'display notification "Paste or copy Apple 2FA code — Desktop/apple-2fa.txt" with title "Outdoor Day ASC"' >/dev/null 2>&1 || true
  else
    cat >"$CODE_FILE" <<'EOF'
# Paste the 6-digit Apple SMS code below, then Save.
# Use the code from the text that arrives AFTER this watcher starts.

EOF
    osascript -e 'display notification "Apple will text a code — paste it into Desktop/apple-2fa.txt" with title "Outdoor Day ASC"' >/dev/null 2>&1 || true
  fi
  open -a TextEdit "$CODE_FILE" >/dev/null 2>&1 || open "$CODE_FILE" >/dev/null 2>&1 || true
else
  echo "Reusing existing code already in $CODE_FILE"
fi

FIFO=$(mktemp -u /tmp/od-2fa.XXXXXX)
mkfifo "$FIFO"
LOG=build/asc_create_watch.log
: >"$LOG"
cleanup() { rm -f "$FIFO"; }
trap cleanup EXIT

# Open FIFO read/write so neither side blocks on open().
exec 3<>"$FIFO"

# Prefer bundle exec; fall back to system ruby+spaceship if vendor bundle is broken.
RUBY_CMD=(bundle exec ruby)
if ! bundle check >/dev/null 2>&1; then
  echo "WARN: bundle check failed — using system ruby/spaceship"
  RUBY_CMD=(ruby)
fi
"${RUBY_CMD[@]}" -e '
require "spaceship"
# When rate-limited, skip the SMS PUT and accept the last code via stdin.
if ENV["ASC_2FA_NO_RESEND"] == "1"
  Spaceship::Client.class_eval do
    alias_method :__od_request_2fa_phone, :request_two_factor_code_from_phone
    def request_two_factor_code_from_phone(phone_id, phone_number, code_length, push_mode = "sms", should_request_code = true)
      puts "NO_RESEND — enter last code for #{phone_number}"
      $stdout.flush
      __od_request_2fa_phone(phone_id, phone_number, code_length, push_mode, false)
    end
  end
end
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

echo "Waiting for Spaceship 2FA prompt…"
for i in $(seq 1 90); do
  if rg -q "Successfully requested text message|Please enter the .*digit code|NO_RESEND" "$LOG" 2>/dev/null; then
    echo "2FA_PROMPT_READY"
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
