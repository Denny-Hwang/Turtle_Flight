#!/usr/bin/env bash
# build_assets.sh — convert SVG sources under assets/characters/ to the formats
# the iOS target needs (vector PDFs for the Asset Catalog UI imagesets, raster
# PNGs for the SceneKit textures).
#
# Pipeline expectations match docs/CHARACTER_DESIGN_PROMPT.md:
#   • UI imagesets:  PDF (Single Scale, Preserve Vector Data) → SwiftUI
#                    Image("turbo_icon") renders crisply at any size.
#   • SceneKit:      PNG-32 with premultiplied alpha at 1024×1024 + 512×512
#                    LOD; sprite-sheet atlases (default/joy/scared/speed) at
#                    2048×2048 in 2×2 grid (atlas packing handled separately
#                    in scripts/pack_atlas.py — TODO).
#   • Color space:   sRGB. Embed an sRGB profile in PNG exports.
#   • Trim:          DO NOT auto-trim — viewBox padding is meaningful for the
#                    centered character/vehicle anchor in the layout math.
#
# Run from repo root:
#     bash scripts/build_assets.sh
#
# Required tools (install via brew on macOS / apt on Linux):
#     - rsvg-convert   (librsvg)        SVG → PNG / PDF
#     - magick         (ImageMagick 7)  optional, for sRGB profile embed
#
# This script is *idempotent and deterministic*: regenerated artefacts must be
# byte-stable so they can be checked into Assets.xcassets without churn. If you
# need to hand-tune the SVG, edit the source under assets/characters/ — never
# the generated PDF/PNG.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT/assets/characters"
OUT_DIR="$ROOT/TurtleFlight/Assets.xcassets/Characters"
APPICON_SVG="$ROOT/assets/ui/app-icon/app_icon.svg"
APPICON_OUT_DIR="$ROOT/TurtleFlight/Assets.xcassets/AppIcon.appiconset"

CHARS=(turbo pip nutty mochi bounce hoppy)

# Imageset variants that should be exported as VECTOR PDF for the Asset Catalog.
# These are used by SwiftUI Image() and don't need raster fallbacks.
PDF_VARIANTS=(icon silhouette vehicle_only default)

# Raster PNG variants that ship to SceneKit. The flying pose is the source for
# the per-character atlas; expression frames go into the 2×2 atlas grid.
PNG_VARIANTS=(flying)
ATLAS_FRAMES=(default joy scared speed)
ATLAS_SIZE_PX=2048      # 2×2 grid, each cell 1024×1024
ATLAS_CELL_PX=1024
TEXTURE_HI_PX=1024      # in-flight billboard, primary
TEXTURE_LO_PX=512       # LOD for older devices

# ---------------------------------------------------------------- helpers
require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "✗ missing tool: $1" >&2
    echo "  install via your package manager (brew install $1 / apt install $2)" >&2
    exit 1
  }
}

svg_to_pdf() {  # $1 src.svg  $2 dst.pdf
  rsvg-convert --format=pdf --keep-aspect-ratio --output "$2" "$1"
}

svg_to_png() {  # $1 src.svg  $2 dst.png  $3 px
  rsvg-convert --format=png --keep-aspect-ratio \
               --width="$3" --height="$3" \
               --output "$2" "$1"
}

emit_imageset_contents() {  # $1 imageset_dir  $2 file_basename  $3 ext
  cat > "$1/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$2.$3",
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true, "template-rendering-intent" : "original" }
}
JSON
}

# ---------------------------------------------------------------- preflight
require rsvg-convert librsvg2-bin

mkdir -p "$OUT_DIR" "$APPICON_OUT_DIR"

# ---------------------------------------------------------------- characters
for char in "${CHARS[@]}"; do
  src_char_dir="$SRC_DIR/$char"

  # 1) PDF (vector) imagesets for UI
  for variant in "${PDF_VARIANTS[@]}"; do
    src="$src_char_dir/${char}_${variant}.svg"
    [ -f "$src" ] || { echo "  · skip ${char}_${variant} (no source)"; continue; }
    imageset="$OUT_DIR/${char}_${variant}.imageset"
    mkdir -p "$imageset"
    svg_to_pdf "$src" "$imageset/${char}_${variant}.pdf"
    emit_imageset_contents "$imageset" "${char}_${variant}" pdf
    echo "  ✓ ${char}_${variant}.pdf"
  done

  # 2) PNG (raster) for SceneKit billboard
  for variant in "${PNG_VARIANTS[@]}"; do
    src="$src_char_dir/${char}_${variant}.svg"
    [ -f "$src" ] || continue
    imageset="$OUT_DIR/${char}_${variant}.imageset"
    mkdir -p "$imageset"
    svg_to_png "$src" "$imageset/${char}_${variant}@2x.png" "$TEXTURE_HI_PX"
    svg_to_png "$src" "$imageset/${char}_${variant}.png"   "$TEXTURE_LO_PX"
    cat > "$imageset/Contents.json" <<JSON
{
  "images" : [
    { "filename" : "${char}_${variant}.png",    "idiom" : "universal", "scale" : "1x" },
    { "filename" : "${char}_${variant}@2x.png", "idiom" : "universal", "scale" : "2x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
    echo "  ✓ ${char}_${variant}.png (${TEXTURE_LO_PX}/${TEXTURE_HI_PX})"
  done

  # 3) Expression atlas (2×2 grid: default/joy/scared/speed)
  #    We render each cell separately into a temp dir, then composite.
  atlas="$OUT_DIR/${char}_atlas.imageset/${char}_atlas.png"
  mkdir -p "$(dirname "$atlas")"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  for frame in "${ATLAS_FRAMES[@]}"; do
    src="$src_char_dir/${char}_${frame}.svg"
    [ -f "$src" ] || { echo "  ! atlas: missing $src — atlas will be skipped"; continue 2; }
    svg_to_png "$src" "$tmp/${frame}.png" "$ATLAS_CELL_PX"
  done
  if command -v magick >/dev/null 2>&1; then
    magick montage \
      "$tmp/default.png" "$tmp/joy.png" \
      "$tmp/scared.png"  "$tmp/speed.png" \
      -tile 2x2 -geometry "${ATLAS_CELL_PX}x${ATLAS_CELL_PX}+0+0" \
      -background none "$atlas"
    cat > "$(dirname "$atlas")/Contents.json" <<JSON
{
  "images" : [ { "filename" : "${char}_atlas.png", "idiom" : "universal", "scale" : "2x" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
    echo "  ✓ ${char}_atlas.png (${ATLAS_SIZE_PX}²)"
  else
    echo "  · skip ${char}_atlas (install ImageMagick to enable)"
  fi
  rm -rf "$tmp"
  trap - EXIT
done

# ---------------------------------------------------------------- app icon
if [ -f "$APPICON_SVG" ]; then
  # App Store requires 1024×1024 sRGB, NO alpha (opaque). Render onto white,
  # then strip alpha so the export is store-compliant.
  tmp_alpha="$(mktemp -t appicon.XXXX.png)"
  trap 'rm -f "$tmp_alpha"' EXIT
  svg_to_png "$APPICON_SVG" "$tmp_alpha" 1024
  if command -v magick >/dev/null 2>&1; then
    magick "$tmp_alpha" -background "#85B7EB" -alpha remove -alpha off \
           -colorspace sRGB \
           "$APPICON_OUT_DIR/AppIcon-1024.png"
  else
    # Fallback: rsvg renders against transparent; copy as-is and warn.
    cp "$tmp_alpha" "$APPICON_OUT_DIR/AppIcon-1024.png"
    echo "  ! AppIcon has alpha; install ImageMagick to flatten before submission"
  fi
  cat > "$APPICON_OUT_DIR/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
  echo "  ✓ AppIcon-1024.png"
  rm -f "$tmp_alpha"
  trap - EXIT
fi

echo "done. assets exported under TurtleFlight/Assets.xcassets/"
