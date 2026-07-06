#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/build/zongMacTools.app}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/DockHoverPreviewProbe"
ICON_PATH="$APP_PATH/Contents/Resources/zongMacTools.icns"

fail() {
  echo "verify_app_bundle: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST"
}

[[ -d "$APP_PATH" ]] || fail "missing app bundle: $APP_PATH"
[[ "$APP_PATH" == *.app ]] || fail "path is not an .app bundle: $APP_PATH"
[[ -f "$INFO_PLIST" ]] || fail "missing Info.plist"
[[ -x "$EXECUTABLE_PATH" ]] || fail "missing executable: $EXECUTABLE_PATH"
[[ -f "$ICON_PATH" ]] || fail "missing icon: $ICON_PATH"

[[ "$(plist_value CFBundleExecutable)" == "DockHoverPreviewProbe" ]] || fail "CFBundleExecutable mismatch"
[[ "$(plist_value CFBundleIdentifier)" == "com.zong.zongMacTools" ]] || fail "CFBundleIdentifier mismatch"
[[ "$(plist_value CFBundleName)" == "zongMacTools" ]] || fail "CFBundleName mismatch"
[[ "$(plist_value CFBundleDisplayName)" == "zongMacTools" ]] || fail "CFBundleDisplayName mismatch"
[[ "$(plist_value CFBundleIconFile)" == "zongMacTools" ]] || fail "CFBundleIconFile mismatch"

codesign --verify --deep --strict "$APP_PATH" >&2
SIGNING_SUMMARY="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
echo "$SIGNING_SUMMARY" >&2

if grep -qi "Signature=adhoc" <<<"$SIGNING_SUMMARY"; then
  echo "verify_app_bundle: ad-hoc signature detected." >&2
  echo "TCC caveat: ad-hoc re-signing can require re-adding Accessibility and Screen Recording permissions." >&2
fi

echo "verify_app_bundle: OK $APP_PATH" >&2
