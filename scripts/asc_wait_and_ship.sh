#!/bin/bash
# Poll ASC until Outdoor Day exists, then ship. Safe to leave running.
set -uo pipefail
cd "$(dirname "$0")/.."
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
INTERVAL="${ASC_POLL_SECONDS:-120}"
NOTIFY_EVERY="${ASC_NOTIFY_EVERY:-10}"
misses=0
notify() {
  local title="$1" body="$2"
  /usr/bin/osascript \
    -e "on run argv" \
    -e "display notification (item 2 of argv) with title (item 1 of argv)" \
    -e "end run" \
    -- "$title" "$body" >/dev/null 2>&1 || true
}
echo "Waiting for ASC app us.letshang.outdoor-day (every ${INTERVAL}s)…"
echo "Create it: scripts/human_asc_create.md (or bash scripts/open_asc_create.sh)"
while true; do
  set +e
  out="$(ruby scripts/asc_ship.rb 2>&1)"
  status=$?
  set -e
  echo "$out"
  # Prefer NO_APP detection before success — never treat a missing app as shipped.
  if echo "$out" | grep -q "NO_APP" || [[ "$status" -eq 2 ]]; then
    misses=$((misses + 1))
    echo "$(date '+%Y-%m-%d %H:%M:%S %Z') still NO_APP — sleeping ${INTERVAL}s"
    if (( misses == 1 || misses % NOTIFY_EVERY == 0 )); then
      notify "Outdoor Day blocked" "Create ASC app us.letshang.outdoor-day (SKU outdoor-day-001)."
      # Surface the create checklist without requiring a chat reply.
      bash scripts/open_asc_create.sh >/dev/null 2>&1 || true
    fi
    sleep "$INTERVAL"
    continue
  fi
  if [[ "$status" -eq 0 ]]; then
    ruby scripts/asc_finish.rb
    echo "SHIPPED. Complete App Privacy in ASC UI if prompted (scripts/human_asc_create.md)."
    notify "Outdoor Day shipped" "Finish App Privacy in App Store Connect, then wait for review."
    open "https://appstoreconnect.apple.com/apps" >/dev/null 2>&1 || true
    exit 0
  fi
  if echo "$out" | grep -qiE "OpenTimeout|ReadTimeout|ECONNRESET|timed out|execution expired|UNEXPECTED_ERROR|status.?500|ASC apps lookup failed"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S %Z') transient ASC/network error — retry in ${INTERVAL}s"
    sleep "$INTERVAL"
    continue
  fi
  echo "asc_ship failed with status $status"
  notify "Outdoor Day ship failed" "asc_ship exited with status $status — check build/wait_and_ship.log"
  exit "$status"
done
