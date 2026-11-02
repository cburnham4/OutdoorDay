#!/bin/bash
# Poll ASC until Outdoor Day exists, then ship. Safe to leave running.
set -uo pipefail
cd "$(dirname "$0")/.."
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
INTERVAL="${ASC_POLL_SECONDS:-120}"
echo "Waiting for ASC app us.letshang.outdoor-day (every ${INTERVAL}s)…"
echo "Create it: scripts/human_asc_create.md"
while true; do
  set +e
  out="$(ruby scripts/asc_ship.rb 2>&1)"
  status=$?
  set -e
  echo "$out"
  if [[ "$status" -eq 0 ]]; then
    ruby scripts/asc_finish.rb
    echo "SHIPPED. Complete App Privacy in ASC UI if prompted (scripts/human_asc_create.md)."
    exit 0
  fi
  if echo "$out" | grep -q "NO_APP" || [[ "$status" -eq 2 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S %Z') still NO_APP — sleeping ${INTERVAL}s"
    sleep "$INTERVAL"
    continue
  fi
  if echo "$out" | grep -qiE "OpenTimeout|ReadTimeout|ECONNRESET|timed out|execution expired"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S %Z') network timeout — retry in ${INTERVAL}s"
    sleep "$INTERVAL"
    continue
  fi
  echo "asc_ship failed with status $status"
  exit "$status"
done
