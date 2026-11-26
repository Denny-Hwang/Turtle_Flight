#!/usr/bin/env bash
# Real-device verification (docs/DEVICE_VERIFICATION.md).
#
#   TEAM=<team id> scripts/device/verify.sh            # build, install, 3-minute soak, then show the scenes
#   TEAM=<team id> SOAK=600 scripts/device/verify.sh   # 10-minute soak (heat check)
#   TEAM=<team id> scripts/device/verify.sh --no-scenes # build, install, soak only (no prompts; fine for agents)
#   scripts/device/verify.sh --scenes-only              # skip build + soak, just step through the scenes
#
# Needs: Xcode → Settings → Accounts signed in with the Apple ID of TEAM,
# an unlocked, connected iPhone with Developer Mode on. The team id is
# passed on the command line only — never commit it to project.yml.
#
# The build is Debug (the autopilot and scene switches exist only in
# Debug) but compiled with -O, so frame times are close to Release.
set -euo pipefail
cd "$(dirname "$0")/../.."

BUNDLE_ID=com.turtleflight.app
SOAK=${SOAK:-180}
OUT=build/device-verify/$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"

MODE=${1:-}

# First paired, reachable iPhone: CoreDevice id (devicectl) + hardware UDID (xcodebuild).
DEVJSON=$(mktemp)
xcrun devicectl list devices --json-output "$DEVJSON" >/dev/null 2>&1 || true
read -r DEVICE UDID < <(python3 -I - "$DEVJSON" <<'PY' || true
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
for d in devices:
    hw, conn = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if hw.get("deviceType") == "iPhone" and conn.get("pairingState") == "paired" \
            and conn.get("tunnelState") != "unavailable":
        print(d["identifier"], hw.get("udid", ""))
        break
PY
) || true
rm -f "$DEVJSON"
[ -n "${DEVICE:-}" ] || { echo "No paired, available iPhone. Connect and unlock it." >&2; exit 2; }
echo "device: $DEVICE (udid $UDID)"

launch() { # scene + extra args
  xcrun devicectl device process launch --terminate-existing --device "$DEVICE" "$BUNDLE_ID" -- -TFScreenshot "$@" >/dev/null
}

if [ "$MODE" != "--scenes-only" ]; then
  : "${TEAM:?set TEAM=<your Apple Developer team id>}"
  command -v xcodegen >/dev/null || { echo "brew install xcodegen" >&2; exit 2; }
  xcodegen generate --quiet
  xcodebuild build -project TurtleFlight.xcodeproj -scheme TurtleFlight -configuration Debug \
    -destination "id=$UDID" -derivedDataPath build/device-dd \
    DEVELOPMENT_TEAM="$TEAM" SWIFT_OPTIMIZATION_LEVEL=-O -allowProvisioningUpdates -quiet || {
    echo "Build failed. 'No Accounts' / 'No profiles' means Xcode → Settings → Accounts has no Apple ID for team $TEAM." >&2
    exit 1
  }
  xcrun devicectl device install app --device "$DEVICE" build/device-dd/Build/Products/Debug-iphoneos/TurtleFlight.app

  echo "== soak: Sky Run on autopilot for ${SOAK}s (keep the phone unlocked)"
  launch soak -TFPerfProbe YES -selectedCharacter turtle -selectedVehicle shellJet -selectedMapTheme sky
  sleep "$SOAK"
  xcrun devicectl device process launch --terminate-existing --device "$DEVICE" "$BUNDLE_ID" >/dev/null || true
  xcrun devicectl device copy from --device "$DEVICE" --domain-type appDataContainer \
    --domain-identifier "$BUNDLE_ID" --source Documents/perf.csv --destination "$OUT/perf.csv" >/dev/null
  python3 - "$OUT/perf.csv" <<'PY'
import sys
rows = [l.strip().split(",") for l in open(sys.argv[1]) if l[0].isdigit()]
rows = [r for r in rows if float(r[0]) >= 5]           # skip warm-up
fps = sorted(float(r[1]) for r in rows)
worst = max(float(r[2]) for r in rows)
mem = max(float(r[3]) for r in rows)
therm = max(int(r[4]) for r in rows)
p5 = fps[len(fps) // 20]
print(f"seconds {len(rows)}  fps median {fps[len(fps)//2]:.1f}  5th pct {p5:.1f}  worst frame {worst:.0f} ms  peak memory {mem:.0f} MB  thermal max {therm} (0 nominal … 3 critical)")
ok = p5 >= 55 and mem < 250 and therm < 2
print("PASS" if ok else "CHECK: target is 60 fps (5th pct ≥ 55), < 250 MB, thermal below 'serious'")
PY
  echo "   raw: $OUT/perf.csv"
fi

if [ "$MODE" = "--no-scenes" ]; then
  echo "Skipped scenes. Step through them later with: scripts/device/verify.sh --scenes-only"
  exit 0
fi

echo "== scenes: look at each on the phone, press Return for the next"
for s in "home" "characters" "stages" "daily|-flight.lookAtMe NO" "daily|-flight.lookAtMe YES" \
         "skyrun" "daily-result" "pause" "tour|-selectedMapTheme seoul" "freeflight|-TFWonder roundRainbow" \
         "freeflight|-TFFestival YES -selectedMapTheme city -TFMood sunset" "settings" "album" "shop"; do
  scene=${s%%|*}; extra=""; [ "$scene" != "$s" ] && extra=${s#*|}
  # shellcheck disable=SC2086
  launch "$scene" $extra
  read -r -p "   $scene $extra — ok? (Return) " _
done
xcrun devicectl device process launch --terminate-existing --device "$DEVICE" "$BUNDLE_ID" >/dev/null || true
echo "Done. Now play normally for the hands-on checklist in docs/DEVICE_VERIFICATION.md."
