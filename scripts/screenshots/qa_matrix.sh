#!/usr/bin/env bash
# Layout QA: every screen x every bundled language x several screen sizes,
# captured from the Simulator into build/qa-matrix/ and tiled into contact
# sheets (one per device + screen) so truncation and overlap are easy to spot.
#
#   scripts/screenshots/qa_matrix.sh
#   DEVICES="iPhone 17e" LOCALES="en de" SCENES="home settings" scripts/screenshots/qa_matrix.sh
#
# Uses the Debug-only screenshot mode (ScreenshotDirector). Not part of CI.
set -euo pipefail
cd "$(dirname "$0")/../.."

IFS=',' read -r -a DEVICE_LIST <<<"${DEVICES:-iPhone 17e,iPhone 17 Pro Max,iPad mini (A17 Pro)}"
LOCALES=${LOCALES:-"en ko ja zh-Hans es fr de"}
# scene:seconds-to-wait
SCENES=${SCENES:-"home:6 characters:6 stages:6 settings:6 onboarding:6 freeflight:7 pause:13 stage:24 daily:26"}
OUT_ROOT=build/qa-matrix
DERIVED=build/screenshots-dd
BUNDLE_ID=com.turtleflight.app

xcodegen generate --quiet
# Build once for every simulator, so sources can keep changing while the
# (long) capture loop runs.
xcodebuild build-for-testing -project TurtleFlight.xcodeproj -scheme TurtleFlightScreenshots \
  -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO -quiet 2>&1 | grep -E "error|FAILED" || true
APP="$DERIVED/Build/Products/Debug-iphonesimulator/TurtleFlight.app"
[ -d "$APP" ] || { echo "build failed" >&2; exit 1; }
for name in "${DEVICE_LIST[@]}"; do
  UDID=$(xcrun simctl list devices available | grep -F "$name (" | head -1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  [ -n "$UDID" ] || { echo "simulator '$name' not installed" >&2; exit 2; }
  slug=$(echo "$name" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-')
  echo "== $name"
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  xcrun simctl erase "$UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl install "$UDID" "$APP"
  xcodebuild test-without-building -project TurtleFlight.xcodeproj -scheme TurtleFlightScreenshots \
    -destination "id=$UDID" -derivedDataPath "$DERIVED" \
    -only-testing:TurtleFlightScreenshotTests/RotateToLandscape \
    CODE_SIGNING_ALLOWED=NO -quiet >/dev/null
  # A freshly erased simulator is slow for its first minute (launches
  # took >4s and shots caught the launch screen): warm it up first.
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -TFScreenshot home >/dev/null; sleep 45
  OUT="$OUT_ROOT/$slug"; mkdir -p "$OUT"
  for loc in $LOCALES; do
    for s in $SCENES; do
      scene=${s%%:*}; wait=${s##*:}
      file="$OUT/${scene}__${loc}.png"
      xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
      xcrun simctl launch "$UDID" "$BUNDLE_ID" -TFScreenshot "$scene" \
        -AppleLanguages "($loc)" >/dev/null
      sleep "$wait"
      xcrun simctl io "$UDID" screenshot "$file" >/dev/null 2>&1
      w=$(sips -g pixelWidth "$file" | awk '/pixelWidth/{print $2}')
      h=$(sips -g pixelHeight "$file" | awk '/pixelHeight/{print $2}')
      [ "$h" -gt "$w" ] && sips -r 270 "$file" >/dev/null
    done
    echo "   $loc done"
  done
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl shutdown "$UDID"
done

python3 - "$OUT_ROOT" <<'PY'
import glob, os, sys
from PIL import Image, ImageDraw
root = sys.argv[1]
for dev in sorted(os.listdir(root)):
    d = os.path.join(root, dev)
    if not os.path.isdir(d) or dev == "sheets":
        continue
    scenes = sorted({os.path.basename(f).split("__")[0] for f in glob.glob(d + "/*__*.png")})
    for scene in scenes:
        files = sorted(glob.glob(f"{d}/{scene}__*.png"))
        tw = 900
        ims = []
        for f in files:
            im = Image.open(f).convert("RGB")
            im = im.resize((tw, round(im.height * tw / im.width)))
            ImageDraw.Draw(im).text((8, im.height - 18), os.path.basename(f)[:-4], fill=(255, 0, 255))
            ims.append(im)
        th = ims[0].height
        rows = (len(ims) + 1) // 2
        sheet = Image.new("RGB", (tw * 2, th * rows), (30, 30, 30))
        for i, im in enumerate(ims):
            sheet.paste(im, ((i % 2) * tw, (i // 2) * th))
        os.makedirs(os.path.join(root, "sheets"), exist_ok=True)
        sheet.save(os.path.join(root, "sheets", f"{dev}__{scene}.png"))
print("sheets in", os.path.join(root, "sheets"))
PY
