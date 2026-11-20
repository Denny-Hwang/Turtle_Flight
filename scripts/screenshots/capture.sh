#!/usr/bin/env bash
# App Store screenshots from the Simulator, fully automatic.
#
#   scripts/screenshots/capture.sh                 # iPhone 6.9" + iPad 13"
#   scripts/screenshots/capture.sh iphone          # one device family
#   LANG_CODE=ko scripts/screenshots/capture.sh    # another locale
#
# Builds the Debug app (screenshot mode exists only in Debug, see
# TurtleFlight/Core/Observability/ScreenshotDirector.swift), erases each
# simulator for a clean save, and runs the scenes in order. Flight scenes
# fly themselves through ring centres, so score / combo / result / quests /
# mastery on the later shots are what those runs really produced.
#
# Output: marketing/screenshots/<device>/<NN>_<scene>.png in landscape at
# the device's native resolution (iPhone 17 Pro Max 2868x1320,
# iPad Pro 13" 2752x2064) — the sizes App Store Connect asks for.
set -euo pipefail
cd "$(dirname "$0")/../.."

LANG_CODE=${LANG_CODE:-en}
LOCALE=${LOCALE:-en_US}
OUT_ROOT=marketing/screenshots
DERIVED=build/screenshots-dd
BUNDLE_ID=com.turtleflight.app
ONLY=${1:-all}

DEVICES=()
[ "$ONLY" = all ] || [ "$ONLY" = iphone ] && DEVICES+=("iphone-6.9|iPhone 17 Pro Max")
[ "$ONLY" = all ] || [ "$ONLY" = ipad ]   && DEVICES+=("ipad-13|iPad Pro 13-inch (M5)")

# scene | character | vehicle | theme | seconds to wait before capture
SCENES=(
  "daily|turtle|shellJet|sky|26"
  "skyrun|penguin|bellyGlider|ocean|32"
  "daily-result|bunny|carrotJet|sky|70"
  "home|turtle|shellJet|sky|4"
  "characters|turtle|shellJet|sky|4"
  "stages|turtle|shellJet|sky|4"
)

command -v xcodegen >/dev/null || { echo "brew install xcodegen" >&2; exit 2; }
xcodegen generate --quiet

udid_for() {
  xcrun simctl list devices available | grep -F "$1 (" | head -1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

for entry in "${DEVICES[@]}"; do
  slug=${entry%%|*}; name=${entry#*|}
  UDID=$(udid_for "$name")
  [ -n "$UDID" ] || { echo "simulator '$name' not installed (Xcode → Settings → Components)" >&2; exit 2; }
  echo "== $name ($UDID)"

  xcodebuild build -project TurtleFlight.xcodeproj -scheme TurtleFlight \
    -configuration Debug -destination "id=$UDID" -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO -quiet
  APP="$DERIVED/Build/Products/Debug-iphonesimulator/TurtleFlight.app"

  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  xcrun simctl erase "$UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  # System language too (the iPad status bar prints the date), then
  # reboot so SpringBoard picks it up.
  xcrun simctl spawn "$UDID" defaults write -g AppleLanguages -array "$LANG_CODE"
  xcrun simctl spawn "$UDID" defaults write -g AppleLocale -string "$LOCALE"
  xcrun simctl shutdown "$UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi \
    --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100
  xcrun simctl install "$UDID" "$APP"
  # Turn the device itself to landscape (iPadOS letterboxes a
  # landscape-only app on a portrait iPad; simctl can't rotate).
  xcodebuild test -project TurtleFlight.xcodeproj -scheme TurtleFlightScreenshots \
    -destination "id=$UDID" -derivedDataPath "$DERIVED" \
    -only-testing:TurtleFlightScreenshotTests/RotateToLandscape \
    CODE_SIGNING_ALLOWED=NO -quiet >/dev/null

  OUT="$OUT_ROOT/$slug"; mkdir -p "$OUT"
  i=0
  for s in "${SCENES[@]}"; do
    IFS='|' read -r scene char vehicle theme wait <<<"$s"
    i=$((i + 1)); file="$OUT/$(printf '%02d' $i)_$scene.png"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -TFScreenshot "$scene" \
      -selectedCharacter "$char" -selectedVehicle "$vehicle" -selectedMapTheme "$theme" \
      -AppleLanguages "($LANG_CODE)" -AppleLocale "$LOCALE" >/dev/null
    sleep "$wait"
    xcrun simctl io "$UDID" screenshot --mask=ignored "$file" >/dev/null 2>&1
    # The simulator captures in portrait; the game is landscape-only.
    w=$(sips -g pixelWidth "$file" | awk '/pixelWidth/{print $2}')
    h=$(sips -g pixelHeight "$file" | awk '/pixelHeight/{print $2}')
    [ "$h" -gt "$w" ] && sips -r 270 "$file" >/dev/null
    # Real-device screenshots never contain the Dynamic Island; the
    # Simulator's do. Paint it out (only that pill is touched).
    case "$slug" in iphone*) python3 scripts/screenshots/clean_island.py "$file" >/dev/null ;; esac
    echo "   $file"
  done
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl status_bar "$UDID" clear
  xcrun simctl shutdown "$UDID"
done
echo "Done. Raw screenshots in $OUT_ROOT/. Store versions: scripts/screenshots/compose.py"
