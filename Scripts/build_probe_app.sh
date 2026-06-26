#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DockHoverPreviewProbe"
CONFIGURATION="${CONFIGURATION:-debug}"
APP_DIR="$ROOT_DIR/build/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

EXECUTABLE_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Sources/DockHoverPreviewProbe/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/$APP_NAME"

plutil -lint "$CONTENTS_DIR/Info.plist"
codesign --force --sign - "$APP_DIR"

echo "$APP_DIR"
