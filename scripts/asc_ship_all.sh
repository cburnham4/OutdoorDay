#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ruby scripts/asc_ship.rb
ruby scripts/asc_finish.rb
echo "Ship scripts finished."
echo "If App Privacy nutrition label is unset, complete it in ASC UI (see scripts/human_asc_create.md)."
echo "Export compliance is already false in Info.plist (ITSAppUsesNonExemptEncryption)."
