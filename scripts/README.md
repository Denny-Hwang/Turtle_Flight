# scripts/

Reproducible build helpers for non-Swift artefacts.

## `characters/generate.py`

The character art is generated, not hand-drawn: `scripts/characters/kit.py`
holds the shared parts (eye system, two-tone shading, outline, shadow) and
each character has its own module. Stdlib only, byte-stable output.

```bash
python3 scripts/characters/generate.py   # → assets/characters/<name>/*.svg + app icon SVG
python3 scripts/characters/preview.py    # → build/character-preview/*.png contact sheets
bash scripts/build_assets.sh             # → Assets.xcassets (PDF / PNG / atlases / icon)
```

Per character it writes 16 SVGs: the standing poses (`default`, `joy`,
`scared`, `speed`), `flying`, `icon`, `silhouette`, `vehicle_only`, and the
in-flight atlas frames `fly_*` (own vehicle) and `cloud_*` (Cloud Surf).
To change a character, edit its module and re-run all three commands —
never edit the SVG/PDF/PNG by hand.

## `screenshots/qa_matrix.sh`

Layout QA: every screen × every bundled language × several simulators,
tiled into contact sheets under `build/qa-matrix/sheets/`. Run it after any
UI or string change (≈45 min for the default 3 devices × 7 languages).

## `build_assets.sh`

Converts SVG sources under `assets/characters/` and `assets/ui/app-icon/` into
the formats Xcode actually consumes:

- **Vector PDF** for UI imagesets (`Image("turbo_icon")`, etc.)
- **Raster PNG** for SceneKit billboarded textures (in-flight pose) at 1024 + 512 LOD
- **2×2 expression atlas PNG** at 1024×1024 (default / joy / scared / speed), one
  riding the character's own vehicle and one on Cloud Surf, for the
  `diffuse.contentsTransform` UV-offset animation
- **App Store icon** at 1024×1024, sRGB, no alpha (opaque), flattened against the
  brand sky color `#85B7EB`

### Why generate, not hand-edit

The generated files live under `TurtleFlight/Assets.xcassets/` and are intended to
be reproducible from the SVG sources. Treat the SVGs as the source of truth; the
PDFs / PNGs are build artefacts. If you need a tweak, edit the SVG and re-run
the script — never hand-edit the PDF/PNG, otherwise the next regeneration will
silently drop your work.

### Requirements

```bash
# macOS
brew install librsvg imagemagick

# Linux (CI)
apt install -y librsvg2-bin imagemagick
```

### Running

```bash
# from repo root
bash scripts/build_assets.sh
```

The script is idempotent. Output paths:

```
TurtleFlight/Assets.xcassets/
├── AppIcon.appiconset/
│   ├── AppIcon-1024.png
│   └── Contents.json
└── Characters/
    ├── turbo_icon.imageset/         ← PDF, vector preserve
    ├── turbo_silhouette.imageset/   ← PDF, vector preserve
    ├── turbo_vehicle_only.imageset/ ← PDF, vector preserve
    ├── turbo_default.imageset/      ← PDF, vector preserve
    ├── turbo_flying.imageset/       ← PNG @1x (512) / @2x (1024)
    ├── turbo_atlas.imageset/        ← PNG, 2048², 2×2 expression grid
    └── … (repeat for pip/nutty/mochi/bounce/hoppy)
```

### Future work

- `scripts/pack_atlas.py` — replace ImageMagick `montage` with a Python+Pillow
  packer so the atlas pipeline has no external native dependency.
- Hook `build_assets.sh` into an Xcode "Run Script" build phase, gated on
  `xcconfig` flag so local dev builds skip it (CI generates on every push).
