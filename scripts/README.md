# scripts/

Reproducible build helpers for non-Swift artefacts.

## `build_assets.sh`

Converts SVG sources under `assets/characters/` and `assets/ui/app-icon/` into
the formats Xcode actually consumes:

- **Vector PDF** for UI imagesets (`Image("turbo_icon")`, etc.)
- **Raster PNG** for SceneKit billboarded textures (in-flight pose) at 1024 + 512 LOD
- **2×2 expression atlas PNG** at 2048×2048 (default / joy / scared / speed) for the
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
