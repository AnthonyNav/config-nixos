#!/usr/bin/env bash
set -euo pipefail

export FLEET_UI_BIN="$0"
exec fleet-ui-backend "$@"
