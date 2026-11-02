#!/bin/bash
# Keep ASC 2FA watcher + wait-and-ship alive until Outdoor Day exists.
set -uo pipefail
cd "$(dirname "$0")/.."
LOG=build/od_2fa_keepalive.log
mkdir -p build
echo "$(date) keepalive start" >>"$LOG"
while true; do
  if ! ruby scripts/asc_ship.rb status 2>/dev/null | grep -q NO_APP; then
    echo "$(date) ASC app exists — exit" >>"$LOG"
    exit 0
  fi
  if ! pgrep -f asc_create_watch_2fa.sh >/dev/null; then
    echo "$(date) restarting watcher NO_RESEND=1" >>"$LOG"
    env \
      SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER='+1 (503) 929-7690' \
      ASC_2FA_MAX_WAIT=3600 \
      ASC_2FA_POLL_SECONDS=2 \
      ASC_2FA_NO_RESEND=1 \
      FASTLANE_USER=cburnhamiv@gmail.com \
      bash scripts/asc_create_watch_2fa.sh >> build/asc_create_watch_runner.log 2>&1 &
    sleep 20
  fi
  if ! pgrep -f asc_wait_and_ship.sh >/dev/null; then
    echo "$(date) restarting wait_and_ship" >>"$LOG"
    bash scripts/asc_wait_and_ship.sh >> build/wait_and_ship.log 2>&1 &
  fi
  if ! pgrep -f od_2fa_desktop_bridge.sh >/dev/null; then
    echo "$(date) restarting desktop bridge" >>"$LOG"
    bash scripts/od_2fa_desktop_bridge.sh >> build/od_2fa_bridge.log 2>&1 &
  fi
  sleep 60
done
