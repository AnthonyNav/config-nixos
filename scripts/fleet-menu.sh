#!/usr/bin/env bash
set -euo pipefail
exec "${FLEET_UI_BIN:-fleet-ui}" menu "$@"
