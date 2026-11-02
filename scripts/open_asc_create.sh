#!/bin/bash
# Opens App Store Connect Apps and prints the exact New App fields.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
display notification "Create Outdoor Day: iOS · us.letshang.outdoor-day · SKU outdoor-day-001" with title "Outdoor Day ASC" subtitle "New App required to ship"
APPLESCRIPT
open "https://appstoreconnect.apple.com/apps"
cat "$ROOT/scripts/human_asc_create.md"
echo
echo "After create, wait-and-ship (or: bash scripts/asc_ship_all.sh) uploads automatically."
