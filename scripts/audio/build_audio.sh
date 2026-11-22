#!/usr/bin/env bash
# Render the bundled music / vehicle loops / sound effects and encode them
# into TurtleFlight/Audio/ (picked up by AudioManager.assetURL by name).
#
#   bash scripts/audio/build_audio.sh
#
# Everything is synthesised by scripts/audio/render_assets.swift — no
# samples or generated-by-model audio — so it is safe to regenerate
# anywhere (CI, agents). Music: AAC .m4a (seamless loop, encoder priming
# is recorded in the file). Loops and effects: 16-bit .caf, which
# AVAudioPlayer starts with no decode delay.
set -euo pipefail
cd "$(dirname "$0")/../.."

WORK=build/audio
OUT=TurtleFlight/Audio
mkdir -p "$WORK" "$OUT"
swiftc -O scripts/audio/render_assets.swift -o "$WORK/render"
rm -rf "$WORK/wav"
"$WORK/render" "$WORK/wav"

rm -f "$OUT"/*.m4a "$OUT"/*.caf
for f in "$WORK"/wav/*.wav; do
  name=$(basename "$f" .wav)
  case "$name" in
    bgm_*)     afconvert -f m4af -d aac -b 128000 "$f" "$OUT/$name.m4a" ;;
    vehicle_*) afconvert -f caff -d LEI16@22050 "$f" "$OUT/$name.caf" ;;
    *)         afconvert -f caff -d LEI16 "$f" "$OUT/$name.caf" ;;
  esac
done
du -sh "$OUT"
ls "$OUT"
