#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ruby scripts/asc_ship.rb
ruby scripts/asc_finish.rb
echo "If review submit needs more (export compliance / content rights), complete in ASC UI."
