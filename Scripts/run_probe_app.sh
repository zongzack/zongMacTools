#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$("$ROOT_DIR/Scripts/build_probe_app.sh")"
open "$APP_PATH"
echo "Opened $APP_PATH"
