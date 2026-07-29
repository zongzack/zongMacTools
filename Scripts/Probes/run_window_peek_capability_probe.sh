#!/bin/zsh
set -euo pipefail

probe_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="$(mktemp -d "${TMPDIR:-/tmp}/window-peek-probe.XXXXXX")"
trap 'rm -rf "$output_dir"' EXIT

xcrun swiftc \
  -parse-as-library \
  -framework AppKit \
  -framework SwiftUI \
  -framework ScreenCaptureKit \
  -framework CoreGraphics \
  -framework ApplicationServices \
  "$probe_dir/window_peek_capability_probe.swift" \
  -o "$output_dir/window-peek-capability-probe"

"$output_dir/window-peek-capability-probe"
