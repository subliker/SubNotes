#!/usr/bin/env bash
# Regenerates the README screenshots from deterministic sample data (never the
# user's real calendars). Builds the app, launches it in demo mode
# (`SUBNOTES_DEMO=1`), reads each surface's window id from stdout, and grabs it
# with `screencapture`. Requires Screen Recording permission for the terminal.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="docs/screenshots"
mkdir -p "$OUT"

echo "→ Building…"
xcodegen generate >/dev/null
xcodebuild -project SubNotes.xcodeproj -scheme SubNotes -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build >/dev/null

APP=$(xcodebuild -project SubNotes.xcodeproj -scheme SubNotes -configuration Debug \
  -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR /{print $3}')/SubNotes.app/Contents/MacOS/SubNotes

LOG=$(mktemp)
echo "→ Launching demo…"
pkill -x SubNotes 2>/dev/null || true
SUBNOTES_DEMO=1 "$APP" >"$LOG" 2>&1 &
APP_PID=$!

for _ in $(seq 1 30); do
  grep -q SCREENSHOT_READY "$LOG" && break
  sleep 0.5
done

grab() { # name -> docs/screenshots/<name>.png
  local id
  id=$(awk -v n="$1" '$1=="SCREENSHOT_WINDOW" && $2==n {print $3}' "$LOG")
  screencapture -l"$id" -o "$OUT/$1.png"
  echo "  ✓ $OUT/$1.png"
}
grab popover
grab settings
grab overlay
sips -Z 1140 "$OUT/overlay.png" >/dev/null

kill "$APP_PID" 2>/dev/null || true
rm -f "$LOG"
echo "→ Done."
