#!/usr/bin/env bash
# Spoken callouts (VoiceLine) -> TurtleFlight/Resources/Audio/voice_<key>.m4a
# via Google Cloud Text-to-Speech (Neural2, non-generative).
#
#   scripts/audio/generate_voice.sh --dry-run                 # no network, no credentials
#   scripts/audio/generate_voice.sh --project MY_GCP_PROJECT  # real run, owner's own terminal
#   scripts/audio/generate_voice.sh --project P --only bullseye,great --voice en-US-Neural2-H
#
# Text and voice come from scripts/audio/voice-lines.json. --voice overrides
# the voice for one run (to audition); commit the manifest change if you keep it.
#
# Credentials: Google Application Default Credentials only, for this one
# command (`gcloud auth application-default login`), revoked afterwards. No key
# file, no API key, nothing written to the repo or the shell profile. A real
# run is refused inside Claude Code or CI: agents and CI only run --dry-run.
#
# Cost: ~150 characters in total. Neural2 is $16 per million characters after
# the free tier, so a full regeneration is far below one cent.
set -euo pipefail
cd "$(dirname "$0")/../.."

MANIFEST=scripts/audio/voice-lines.json
OUT_DIR=TurtleFlight/Resources/Audio
ENDPOINT=https://texttospeech.googleapis.com/v1/text:synthesize

DRY_RUN=0; PROJECT=""; ONLY=""; VOICE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --project) PROJECT="${2:?--project needs a value}"; shift ;;
    --only)    ONLY="${2:?--only needs a value}"; shift ;;
    --voice)   VOICE="${2:?--voice needs a value}"; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

command -v jq >/dev/null || { echo "jq is required (brew install jq)" >&2; exit 2; }

LANG_CODE=$(jq -r '.voice.languageCode' "$MANIFEST")
[ -n "$VOICE" ] || VOICE=$(jq -r '.voice.name' "$MANIFEST")
RATE=$(jq -r '.audioConfig.speakingRate' "$MANIFEST")
PITCH=$(jq -r '.audioConfig.pitch' "$MANIFEST")

# Voice guard: Neural2 / WaveNet in the manifest's language only.
if echo "$VOICE" | grep -qiE 'chirp|journey|studio|gemini|polyglot|casual'; then
  echo "refused: $VOICE is a generative voice; use ${LANG_CODE}-Neural2-* or ${LANG_CODE}-Wavenet-*" >&2; exit 2
fi
echo "$VOICE" | grep -qE "^${LANG_CODE}-(Neural2|Wavenet)-[A-Z]$" \
  || { echo "refused: $VOICE is not a ${LANG_CODE} Neural2/WaveNet voice" >&2; exit 2; }

KEYS=$(jq -r '.lines[].key' "$MANIFEST")
if [ -n "$ONLY" ]; then
  for k in ${ONLY//,/ }; do
    echo "$KEYS" | grep -qx "$k" || { echo "unknown line key: $k" >&2; exit 2; }
  done
  KEYS=$(echo "${ONLY//,/ }" | tr ' ' '\n')
fi

TOTAL=0; COUNT=0
for k in $KEYS; do
  TEXT=$(jq -r --arg k "$k" '.lines[] | select(.key==$k) | .text' "$MANIFEST")
  TOTAL=$((TOTAL + ${#TEXT})); COUNT=$((COUNT + 1))
  [ "$DRY_RUN" = 1 ] && printf '  %-12s %-24s -> %s/voice_%s.m4a\n' "$k" "\"$TEXT\"" "$OUT_DIR" "$k"
done
echo "$COUNT lines, $TOTAL billed characters, voice $VOICE (rate $RATE, pitch $PITCH)"
[ "$DRY_RUN" = 1 ] && exit 0

# ---- real run ----------------------------------------------------------------
if [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE_ENTRYPOINT:-}" ] || [ -n "${CI:-}" ]; then
  echo "refused: CLAUDECODE/CI is set. Run this in your own terminal; agents and CI use --dry-run." >&2
  exit 2
fi
[ -n "$PROJECT" ] || { echo "--project <gcp-project-id> is required for a real run (quota/billing project)" >&2; exit 2; }
command -v gcloud >/dev/null || { echo "gcloud is required (brew install --cask google-cloud-sdk)" >&2; exit 2; }
command -v afconvert >/dev/null || { echo "afconvert (macOS) is required" >&2; exit 2; }

TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null) \
  || { echo "no Application Default Credentials: run 'gcloud auth application-default login' first" >&2; exit 2; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT_DIR"
for k in $KEYS; do
  TEXT=$(jq -r --arg k "$k" '.lines[] | select(.key==$k) | .text' "$MANIFEST")
  BODY=$(jq -n --arg t "$TEXT" --arg lang "$LANG_CODE" --arg v "$VOICE" \
             --argjson rate "$RATE" --argjson pitch "$PITCH" \
    '{input:{text:$t}, voice:{languageCode:$lang, name:$v},
      audioConfig:{audioEncoding:"LINEAR16", sampleRateHertz:24000, speakingRate:$rate, pitch:$pitch}}')
  curl -sS --fail-with-body -X POST "$ENDPOINT" \
    -H "Authorization: Bearer $TOKEN" \
    -H "x-goog-user-project: $PROJECT" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "$BODY" -o "$WORK/$k.json" \
    || { echo; echo "request failed for $k (response above)" >&2; exit 1; }
  jq -r '.audioContent' "$WORK/$k.json" | base64 --decode > "$WORK/$k.wav"
  SRC="$WORK/$k.wav"
  # Trim the leading/trailing silence Google pads clips with, so a callout
  # lands on the frame it was triggered (optional: needs ffmpeg).
  if command -v ffmpeg >/dev/null; then
    ffmpeg -hide_banner -loglevel error -y -i "$SRC" \
      -af "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse" \
      "$WORK/$k.trim.wav"
    SRC="$WORK/$k.trim.wav"
  fi
  afconvert "$SRC" "$OUT_DIR/voice_$k.m4a" -f m4af -d aac -b 64000 -c 1
  echo "  wrote $OUT_DIR/voice_$k.m4a"
done
echo "Done. Next: gcloud auth application-default revoke, then listen in the app and commit $OUT_DIR."
