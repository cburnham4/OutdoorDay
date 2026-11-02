#!/bin/bash
# Keep ASC 2FA watcher + wait-and-ship alive until Outdoor Day exists.
set -uo pipefail
cd "$(dirname "$0")/.."
LOG=build/od_2fa_keepalive.log
mkdir -p build
echo "$(date) keepalive start pid=$$" >>"$LOG"
while true; do
  status=$(ruby scripts/asc_ship.rb status 2>/dev/null || true)
  if echo "$status" | grep -q 'NO_APP'; then
    :
  elif echo "$status" | grep -Eq 'APP_ID=|app id|CREATED|Waiting for Review|READY_FOR_SALE|Prepare for Submission|Pending'; then
    echo "$(date) ASC app exists — exit" >>"$LOG"
    echo "$status" >>"$LOG"
    exit 0
  fi

  if ! pgrep -f 'scripts/asc_create_watch_2fa.sh' >/dev/null; then
    echo "$(date) restarting watcher NO_RESEND=1" >>"$LOG"
    env \
      SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER='+1 (503) 929-7690' \
      ASC_2FA_MAX_WAIT=7200 \
      ASC_2FA_POLL_SECONDS=2 \
      ASC_2FA_NO_RESEND=1 \
      FASTLANE_USER=cburnhamiv@gmail.com \
      bash scripts/asc_create_watch_2fa.sh >> build/asc_create_watch_runner.log 2>&1 &
    sleep 20
  fi
  if ! pgrep -f 'scripts/asc_wait_and_ship.sh' >/dev/null; then
    echo "$(date) restarting wait_and_ship" >>"$LOG"
    bash scripts/asc_wait_and_ship.sh >> build/wait_and_ship.log 2>&1 &
  fi
  if ! pgrep -f 'scripts/od_2fa_desktop_bridge.sh' >/dev/null; then
    echo "$(date) restarting desktop bridge" >>"$LOG"
    bash scripts/od_2fa_desktop_bridge.sh >> build/od_2fa_bridge.log 2>&1 &
  fi
  if ! pgrep -f 'scripts/od_2fa_clipboard_watch.sh' >/dev/null; then
    echo "$(date) restarting clipboard watch" >>"$LOG"
    bash scripts/od_2fa_clipboard_watch.sh >> build/od_2fa_clipboard.log 2>&1 &
  fi
  if ! pgrep -f 'scripts/od_followup_2fa.sh' >/dev/null; then
    echo "$(date) restarting followup 2fa watch" >>"$LOG"
    bash scripts/od_followup_2fa.sh >> build/od_followup_2fa.log 2>&1 &
  fi
  sleep 60
done
