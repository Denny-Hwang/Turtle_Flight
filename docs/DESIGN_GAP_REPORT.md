# Turtle Flight — Design Implementation Gap Report

**Audit date:** 2026-05-09
**Auditor:** Claude (review pass on `claude/review-design-implementation-DFroM`)
**Scope:** Verify whether the design system in `docs/CHARACTER_DESIGN_PROMPT.md` and the UX in `docs/SDD.md §4` is actually wired into the shipping iOS app under `TurtleFlight/`, and enumerate every UX/UI surface still missing for a Google-quality 4+ release.

> **TL;DR.** The character art that the design team produced (36 SVGs across 6 characters) is **never referenced anywhere in the Swift code**. The in-game characters are still raw `SCNSphere` / `SCNCapsule` primitives with hex colors that do **not** match the published palette. The Asset Catalog (`Assets.xcassets`) does not exist at all, so even the launch screen and App Store icon paths in `Info.plist` resolve to nothing. There is no Pause / Settings / Onboarding / Stage-Select / Free-Flight-Result / About screen. Out of an honest design pipeline, only the HUD + the home gradient are visually shipped.
>
> Status: **D-grade.** The app is functionally validated (see `VALIDATION_REPORT.md`, 109 tests) but visually the design system is essentially dead code on disk.

---

## 1. Severity legend

| Sev | Meaning |
|-----|---------|
| 🔴 P0 | Blocks store submission or makes the design pipeline non-functional. Fix before any further visual work. |
| 🟠 P1 | Visible quality regression vs. design spec; ships a worse product than what was authored. |
| 🟡 P2 | Polish / consistency / accessibility. Not blocking but expected at "Google senior" bar. |
| 🟢 P3 | Future / v1.x scope. |

---

## 2. Asset pipeline audit

### 2.1 SVG inventory vs `CHARACTER_DESIGN_PROMPT.md §Required Asset List`

Per spec, each of the 6 characters must ship 8 SVGs (default, joy, scared, speed, flying, icon, **silhouette**, **vehicle_only**) → **48 files**.

| Character | default | joy | scared | speed | flying | icon | silhouette | vehicle_only |
|-----------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| turbo  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| pip    | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| nutty  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| mochi  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| bounce | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| hoppy  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |

- Delivered: 36 / 48 SVGs (75%).
- Missing: 12 SVGs (`{name}_silhouette.svg`, `{name}_vehicle_only.svg` × 6). 🟠 **P1**
- App icon SVG exists (`assets/ui/app-icon/app_icon.svg`) but no PNG export at the App-Store-required 1024×1024 sRGB-no-alpha. 🔴 **P0**
- App Store screenshot poses (3 layouts × 2868×1320 landscape) → not produced. 🟠 **P1**

### 2.2 `Assets.xcassets` — does not exist

`find TurtleFlight -name "Assets.xcassets"` → 0 results.

Consequence:
- `TurtleFlight/Info.plist` declares `UILaunchScreen.UIColorName = "LaunchScreenBackground"` and `UIImageName = ""` → both are unresolvable, so the app launches on a **black flash** instead of a branded splash. 🔴 **P0**
- `AppIcon.appiconset/` is absent → home-screen icon will fall back to the Xcode template icon. 🔴 **P0**
- Spec calls for `Assets.xcassets/Characters/{name}_icon.imageset/` (PDF, vector) and `{name}_atlas.imageset/` (PNG @1x/@2x at 1024 / 2048). None exist. 🔴 **P0**
- No `Resources/Particles/*.scnp` for trail effects (rocket flame, propeller sparkles, water droplets, heart puffs). 🟠 **P1** — currently the trails are produced by per-frame node-position math in `CharacterAnimator.swift`, not `SCNParticleSystem`, so they'll never look like the design.

### 2.3 SceneKit expression atlas — does not exist

The design spec is explicit (`CHARACTER_DESIGN_PROMPT.md §Technical Notes / 2`):

> **Sprite sheet (expression atlas)**: pack the 4 expression states into a single 2048×2048 atlas in a 2×2 grid, drive the active expression by animating `diffuse.contentsTransform` (UV offset). Filename: `{name}_atlas.png`.

There is no atlas, no `diffuse.contentsTransform` animation, and no expression switching anywhere in the code. The 4 expression SVGs per character (joy / scared / speed / default) are unused. 🔴 **P0**

---

## 3. Code-side application audit

### 3.1 Critical: SVG art never reaches the binary

```
$ grep -rn 'Image("' TurtleFlight/         # → 0 matches
$ grep -rn 'imageNamed'   TurtleFlight/   # → 0 matches
```

Every character/vehicle visual in the app is reconstructed from primitives in `TurtleFlight/Core/Character/CharacterRegistry.swift`:

| Visual surface | Should use | Actually uses |
|----------------|------------|---------------|
| In-flight 3D character | `{name}_atlas.png` on `SCNPlane` + `SCNBillboardConstraint` | Hand-built `SCNSphere`/`SCNCapsule`/`SCNCone`/`SCNTorus` (200+ lines of geometric primitives) |
| `CharacterPreviewView` (selection screen) | `Image("turbo_default")` or rotating billboarded SVG | Same primitive `buildCharacterNode` rotated on Y |
| `CharacterTile` icons (selection grid) | `Image("turbo_icon")` (PDF, vector) | `Text(character.config.emoji)` — a 🐢/🐧/🐹/🐱/🐸/🐰 emoji |
| `VehicleTile` icons | `Image("turbo_vehicle_only")` | `Text(vehicle.icon)` — a 🔥/🐧/🔄/🧹/🎈/🚁/☁️ emoji |
| `MapThemeCard` thumbnails | Theme illustration | `Text(theme.emoji)` — ☁️/🚀/🐠 |
| `ModeButton` glyphs | Custom mode artwork | `Image(systemName: "cloud.sun.fill" / "target")` |

Severity: 🔴 **P0**. The entire art pipeline is bypassed. Players never see the design team's work.

### 3.2 Critical: color palette mismatch between code and design system

`CHARACTER_DESIGN_PROMPT.md` defines a 5-stop palette per character. `CharacterRegistry.swift` ignores it.

| Character | Spec primary | Code primary (`colorFromHex(...)`) | Match |
|-----------|:------------:|:----------------------------------:|:-----:|
| Turbo  | `#5DCAA5` (mint) | `0x2ECC71` | ❌ |
| Pip    | `#378ADD` (sky-blue tuxedo) | `0x2C3E50` (slate, almost black) | ❌ |
| Nutty  | `#EF9F27` (orange fur) | `0xF0C27F` (peach) | ❌ |
| Mochi  | `#CECBF6` (lavender) | `0x95A5A6` (gray) | ❌ |
| Bounce | `#97C459` (lime) | `0x2ECC71` (**identical to Turbo**) | ❌ + **collision** |
| Hoppy  | `#F0997B` (peach) | `0xECF0F1` (off-white) | ❌ |

Two characters (Turbo and Bounce) currently render in the same green; they are visually indistinguishable in flight. 🔴 **P0**

### 3.3 Critical: brand inconsistency across spec documents

| Surface | Mochi (cat) vehicle | Hoppy (bunny) personality |
|---------|---------------------|----------------------------|
| `docs/SDD.md §3.1.1` | Magic Broom | Lively & brave, red goggles + scarf |
| `Models/CharacterType.swift` (config) | `.magicBroom` + 마녀 모자 | 활발하고 용감한, red goggles + scarf |
| `Localizable.strings` | "Magic Broom" / "마법 빗자루" | — |
| `docs/CHARACTER_DESIGN_PROMPT.md` | **Cushion Hot Air Balloon** | **Shy / quietly brave**, flower + droopy ear, **Carrot Jet** |
| Delivered SVG art (`mochi_*.svg`) | half-lidded tsundere cat with bell collar (matches design prompt, NOT broom) | shy bunny with flower (matches design prompt, NOT brave-with-goggles) |
| `CharacterRegistry.swift` 3D model | witch hat + broomstick + cone-ears | bunny with **red goggles** (Turbo's signature accessory) |

Three different artistic directions per character are scattered across three sources of truth. The shipped art (SVG) and the shipped 3D model disagree about what character this is. 🔴 **P0** — pick one canonical brand and align all three before any further work.

> Recommendation: keep `CHARACTER_DESIGN_PROMPT.md` as the single source of truth (it's the most detailed and was used to draw the SVGs that already exist). Update `SDD.md`, `CharacterType.swift`, `VehicleType.swift`, both `Localizable.strings`, and `CharacterRegistry.swift` to match.

### 3.4 Major: design-system primitives are not centralized

There is no `Theme.swift` / `DesignSystem.swift`. Visual tokens are scattered:

- Colors live in three places: `Constants.Colors`, `Constants.ThemeColors`, **and** ad-hoc literals in `CharacterSelectView.swift` (`Color(hex: 0x29B6F6)`, `0x7B2FBE`, `0x0077B6`, `0x87CEEB`, `0xFFFDE7`, `0x0D0025`, `0x2A0A4A`, `0x006994`, `0x40E0D0`).
- Corner radius values: 4, 6, 8, 10, 12, 14, 16, 20 — no scale.
- Shadow values: radius 1/4/5/6/8, y 2/3/4 — no elevation tokens.
- Typography: every view inlines `.font(.system(size: NN, weight: ..., design: ...))`. No type ramp; Dynamic Type is disabled.
- Spacing: literals 4, 6, 8, 10, 12, 16, 20, 24, 30, 32, 40, 50, 80 freely mixed.
- Buttons reimplemented 7× (`ModeButton`, `MissionButtonStyle`, `ThumbButton`, `SmallButton`, `MapThemeCard`, `CharacterTile`, `VehicleTile`, `SensitivityButton`) with no shared base.

🟠 **P1.** Without a token layer, every future design tweak is an O(N) shotgun edit.

### 3.5 Major: hardcoded English strings leak into views

| File | Line | String | Notes |
|------|------|--------|-------|
| `Views/Home/CharacterSelectView.swift` | 28 | `"Choose Your Adventure"` | Header — visible in Korean locale |
| `Views/Home/CharacterSelectView.swift` | 33 | `"FLY!"` | Primary CTA |
| `Views/Home/CharacterSelectView.swift` | 50 | `"Select Map"` | Section header |
| `Views/Home/CharacterSelectView.swift` | 101 | `"Vehicle"` | Section header |
| `Views/Home/CharacterSelectView.swift` | 307 | `"Shared"` / `"Unique"` | Vehicle tag |
| `Models/MapTheme.swift` | 11–31 | `"Sky Kingdom"`, `"Cosmic Voyage"`, `"Ocean Dream"`, `"Clouds & Rainbows"`, `"Stars & Planets"`, `"Coral & Bubbles"` | All locale-bleed |
| `Models/MapTheme.swift` | 91–122 | All 24 region names | Drift across both locales |
| `Models/SensitivityLevel.swift` | 9–13 | `"Easy"` / `"Normal"` / `"Expert"` | Should reuse `a11y.sensitivity.*.label` |
| `Models/CharacterType.swift` | 23, 33, … | `personality:` strings hard-coded in Korean inside the model layer | Even if unused for display, encodes locale into source |

🟠 **P1.** Korean App Store reviewers will notice. The CLAUDE.md follow-up already calls out the i18n debt.

### 3.6 Minor: trails are faked, not particles

Per `CHARACTER_DESIGN_PROMPT.md`, every character has a unique trail: rocket-flame gradient (Turbo), blue exhaust sparkles (Pip), golden seeds (Nutty), star sparkles (Mochi), water droplets (Bounce), heart puffs (Hoppy). The spec instructs `SCNParticleSystem` per trail. The current code:

- `animateShellJet` scales an empty marker node named `flameEmitter` — there is no actual particle emitter attached.
- `animateCloudSurf` rescales the cloud puff geometry — no actual trail.
- The other 5 vehicles emit nothing visible.

🟠 **P1.** Every character flies in a featureless silence visually. This is one of the highest impact-per-effort fixes in the report.

---

## 4. UX/UI screen-flow audit

Existing screens (5):
1. `HomeView` — title + 2-mode picker + 3 sensitivity tiles + best-stars / total flight time strip.
2. `CharacterSelectView` — back / FLY! header + map theme + character preview (rotating primitive) + character grid + vehicle row + description.
3. `FlightView` — SceneKit world + HUD + (mission HUD) + control buttons.
4. `HUDOverlay` — top: speed / sensitivity / compass-time / altitude. bottom-left: stars. bottom-center: region-name fade.
5. `MissionHUD` — top: stage title + timer. right: ring progress + collisions. center overlay: result/fail card.

Below is every UX surface missing or under-baked vs the SDD plus general AAA-polish bar.

### 4.1 🔴 P0 — must-fix before TestFlight

| # | Surface | Gap | Why P0 |
|---|---------|-----|--------|
| S1 | **Launch Screen** | `Info.plist` references a `UIColorName`/`UIImageName` that do not exist in any asset catalog | App launches on a black flash; reviewer-visible |
| S2 | **App Icon** | No `AppIcon.appiconset` in any catalog | App Store submission rejection; home-screen template icon |
| S3 | **First-run Onboarding** | None. Player drops straight into a gyro-controlled 3D world with no calibration tutorial, no "hold device flat", no "tilt to steer" demo | 4+ rating depends on parents' first-30-second impression; gyro is unexplained |
| S4 | **Pause modal** | Pressing Exit ends the flight outright. App lifecycle pauses gyro silently with no resume cue. | Apple HIG mandates a resumable pause for active gameplay; players will rage-quit on phone calls |
| S5 | **Stage-Select screen for Step Goal** | Step Goal mode silently jumps into `currentStage`. No 5-stage map, no star scores, no lock progression. | The mode advertised in the SDD is fundamentally not navigable. |
| S6 | **Stage-result polish** | Result is a small overlay inside `MissionHUD`. The Next button calls `returnToSelect()` instead of advancing — Stage 5 is unreachable through normal flow. | Core Step-Goal loop is broken. |
| S7 | **Free-Flight result screen** | Pressing Exit in free flight just dismisses the view; the run's stats vanish | Players have no "I just did X" payoff |

### 4.2 🟠 P1 — visible quality at v1.0

| # | Surface | Gap |
|---|---------|-----|
| S8 | **Settings screen** | No Mute toggle, no Reset Progress, no Language switch, no Privacy Policy / Support link. App Store metadata requires the latter two. |
| S9 | **About / Credits screen** | None. Required for store-quality polish and design-team credit. |
| S10 | **Sensitivity preview** | Tapping Easy/Normal/Expert shows only an emoji; no live preview (e.g., a small horizon or dot that mirrors the chosen profile so players can feel before they commit). |
| S11 | **Map-theme preview** | `MapThemeCard` shows only emoji + label; users select blind. Embed a 64×40 thumbnail of each theme's sky. |
| S12 | **Character description bilingual quirk** | `character.{type}.description` is fine; but `personality:` field on `CharacterConfig` is hardcoded Korean and never localized. Either remove or move to the `.strings` files. |
| S13 | **In-flight resume cue** | Returning from background recalibrates and re-starts gyro silently. Show a 1-second "Resuming…" overlay. |
| S14 | **Boost cooldown UI** | Boost button can be hammered; no cooldown ring or "ready" indicator on the button. |
| S15 | **Item ammo / cooldown UI** | Star button never indicates how many shots are left or projectile cooldown. |
| S16 | **Star pickup feedback** | `AudioManager.playStarCollect()` plays but the HUD `⭐ × N` counter does not pulse / flash; missing the visceral feedback loop. |
| S17 | **Compass-to-objective arrow** | In Step Goal stages, no on-screen arrow toward the next ring; on Stage 3+ players get lost behind mountains. |
| S18 | **Mission-timer audio** | `isTimeCritical` already changes the timer color. Add 5s / 3s / 1s beeps. |
| S19 | **Particle trails** | See §3.6 — author 7 `.scnp` files (Shell flame, Pip exhaust, Nutty seeds, Mochi sparkles, Bounce droplets, Hoppy heart puffs, Cloud Surf trail). |
| S20 | **Expression switching during flight** | The 4 expression states (default / joy / scared / speed) are SVG-only. Wire them to FlightEngine signals (boost = `speed`, mission clear = `joy`, near-collision = `scared`). |
| S21 | **App Store screenshots** | 0 / 3 produced. The SDD lists three required compositions. |
| S22 | **Asset Catalog tooling** | No script (`rsvg-convert`/`cairosvg` Makefile) to regenerate PDFs/PNGs. Build pipeline manual today. |
| S23 | **Vehicle preview in selector** | `VehicleTile` shows only an emoji + label; should preview `vehicle_only.svg` rendering. |
| S24 | **Tutorial step on first ring** | Step Goal Stage 1 should highlight the first ring with a tap-to-continue hint. None. |
| S25 | **End-of-stage star animation** | Stars in result overlay are static `Image(systemName: "star.fill")`. Spec implies a count-up sparkle sequence for emotional payoff. |
| S26 | **MissionHUD dialog reachability** | The result/fail dialog blocks the exit button from `ControlButtons` (because `MissionHUD` and `ControlButtons` are sibling overlays). Verify hit-testing order. |

### 4.3 🟡 P2 — accessibility & polish

| # | Surface | Gap |
|---|---------|-----|
| A1 | **Dynamic Type** | All text is `.font(.system(size: NN))`; ignores user's preferred text size. Switch to `.font(.headline.weight(.bold))` style or `@ScaledMetric`. |
| A2 | **Reduced Motion** | App is 100% gyro-driven motion. Honor `UIAccessibility.isReduceMotionEnabled` by softening camera lerp and disabling banking exaggeration. |
| A3 | **High-contrast HUD** | The `panelDark.opacity(0.6)` HUD chips fail contrast in bright outdoor lighting. Provide a non-translucent variant. |
| A4 | **Color-blind safe collision indicator** | Red/green pairing for collision count and sensitivity color is not deuteranopia-safe. Pair with iconography. |
| A5 | **VoiceOver coverage** | Mission HUD, result overlay, character preview, map cards have no `accessibilityLabel`. Only `ControlButtons` and `HomeView` are wired. |
| A6 | **Localization** | `ko` + `en` only. CLAUDE.md notes 10 RN locales were lost; ja / zh-Hans / es / fr / de minimum for the v1 markets we already paid translation budget for. |
| A7 | **iPad layout** | Landscape-only is enforced, but layout uses fixed widths (140×120 mode buttons, 64×72 tiles). On iPad these are tiny in the canvas. Use relative sizing. |
| A8 | **Notch / Dynamic Island safe areas** | HUD overlay assumes safe area insets; needs verification on iPhone 14 Pro / 16 Pro Dynamic Island in landscape. |
| A9 | **Empty state when gyro unavailable** | Currently shows an alert and dismisses. For Simulator/iPad demo, fall back to touch-drag steering so the app is exhibitable. |

### 4.4 🟢 P3 — v1.x scope

| # | Surface | Gap |
|---|---------|-----|
| F1 | Mid-flight vehicle switch (Cloud Surf swap) UI |
| F2 | Daily challenge / leaderboard screen |
| F3 | Minimap for Stage 4 |
| F4 | Photo mode / share button |
| F5 | Replay highlight reel |
| F6 | Game Center achievements list screen |
| F7 | Shop / unlockable cosmetic screen (skins exist conceptually in PROMPT but no entry point) |

---

## 5. Spec inconsistencies that must be resolved before any further design work

| ID | Source A | Source B | Conflict |
|----|----------|----------|----------|
| C1 | `SDD.md §3.1.1` "Magic Broom" | `CHARACTER_DESIGN_PROMPT.md §4` "Cushion Hot Air Balloon" | Mochi's vehicle is two different objects |
| C2 | `CharacterType.swift` Hoppy: 활발하고 용감한, red goggles + scarf | `CHARACTER_DESIGN_PROMPT.md §6` Hoppy: shy / flower / droopy ear / Carrot Jet | Different personalities, accessories, and vehicle |
| C3 | `VehicleType.swift` `.earCopter` | `CHARACTER_DESIGN_PROMPT.md` "Carrot Jet" for Hoppy | Vehicle key vs. visual asset disagree |
| C4 | `Constants.Colors.turtleGreen = 0x2ECC71` | `CHARACTER_DESIGN_PROMPT.md` Turbo primary `#5DCAA5` | Brand color isn't actually the brand color |
| C5 | `MapTheme.swift` `displayName` returns English literals | `Localizable.strings` has no `theme.*` keys | Theme labels never localize |
| C6 | `Info.plist` `UILaunchScreen.UIColorName = LaunchScreenBackground` | No catalog defines `LaunchScreenBackground` color | Reference dangles |

---

## 6. Recommended remediation roadmap

### Phase 0 — unblock the design pipeline (1 sprint)
1. **Resolve C1–C6** — pick canonical brand for Mochi & Hoppy; align SDD, code, strings, SVG.
2. Create `TurtleFlight/Assets.xcassets/` with:
   - `AppIcon.appiconset/` (export PNG from `assets/ui/app-icon/app_icon.svg` at all required sizes; sRGB no-alpha).
   - `Colors/LaunchScreenBackground.colorset/` matching brand sky `#85B7EB`.
   - `Characters/{name}_icon.imageset/` (PDF, vector, 6 entries).
   - `Characters/{name}_default.imageset/` (PDF, vector, 6 entries).
3. Add 12 missing SVGs (`{name}_silhouette.svg`, `{name}_vehicle_only.svg`).
4. Add an export script (`scripts/build_assets.sh`) using `rsvg-convert` so SVGs → PDFs/PNGs are reproducible.

### Phase 1 — wire the design into the binary (1–2 sprints)
5. Replace emoji-as-icon usages in `CharacterTile`, `VehicleTile`, `MapThemeCard` with `Image("turbo_icon")` etc.
6. Replace `CharacterPreviewView`'s primitive `buildCharacterNode` with a billboarded `SCNPlane` textured by `{name}_default.png` (rotates around Y as today).
7. Author `{name}_atlas.png` (2×2 expression atlas, 2048×2048) for all 6 characters; in-flight render path uses atlas via `diffuse.contentsTransform`.
8. Hook expression switches to FlightEngine: `joy` on stage clear, `scared` on collision proximity, `speed` while boosting, `default` otherwise.
9. Author 7 `.scnp` particle files; emit from `flameEmitter` / equivalent named markers.
10. Either retire `CharacterRegistry`'s primitive geometry or repurpose it as a **fallback** when atlas is missing.

### Phase 2 — design system (1 sprint)
11. Add `Utils/Theme.swift` exporting:
    - `Theme.Color` (semantic: primary, accent, hudBackground, …)
    - `Theme.Font` (display / headline / body / caption / hudGauge)
    - `Theme.Spacing` (xxs / xs / s / m / l / xl)
    - `Theme.Radius` (s / m / l)
    - `Theme.Elevation` (cardLow / cardHigh / button)
12. Migrate every view to tokens; delete `Constants.Colors` literal references from views.
13. Consolidate the 7 button variants behind `PrimaryButton` / `SecondaryButton` / `IconButton`.

### Phase 3 — missing screens (2 sprints)
14. `OnboardingView` (3 cards: hold device, calibrate, tilt to fly).
15. `PauseView` (modal: Resume / Settings / Quit).
16. `SettingsView` (Mute, Reset, Language, Privacy, Support, About).
17. `StageSelectView` (5-stage horizontal map with star totals + lock states).
18. `StageResultView` (full-screen, animated star count-up, Best-time delta, Next/Retry/Home).
19. `FreeFlightResultView` (run summary, "Best-time"/"Most-stars"/"Longest-run" badges).

### Phase 4 — accessibility & i18n (1 sprint)
20. Apply `@ScaledMetric` for all typography; verify with `.accessibility5` Dynamic Type.
21. Add `UIAccessibility.isReduceMotionEnabled` branch in `FlightView`.
22. Localize all hardcoded English (S12, S5 entries above) and add ja / zh-Hans / es / fr / de bundles.
23. Audit VoiceOver coverage for Mission / Result / Stage / Settings flows.

### Phase 5 — polish & store (1 sprint)
24. App Store screenshots (3 layouts × 2868×1320, plus iPad 13″ if shipping universal).
25. Add boost / item cooldown ring overlay on `ThumbButton`.
26. Add objective compass arrow on Step Goal stages.
27. 5s/3s/1s mission-timer beeps.
28. Star-pickup HUD pulse.

---

## 7. Concrete file-level "shopping list" to file as issues

If this report is converted into GitHub issues, suggested titles:

- `[P0] Create Assets.xcassets with AppIcon, LaunchScreenBackground color, and Characters imageset`
- `[P0] Resolve Mochi vehicle conflict: Magic Broom vs Cushion Hot Air Balloon`
- `[P0] Resolve Hoppy personality + vehicle conflict (Ear Copter vs Carrot Jet, brave vs shy)`
- `[P0] Replace primitive 3D characters with billboarded atlas-textured SCNPlane`
- `[P0] Align CharacterRegistry colors with CHARACTER_DESIGN_PROMPT palettes`
- `[P0] Add OnboardingView (3-step gyro tutorial)`
- `[P0] Add PauseView modal and wire AppDelegate scene-phase to it`
- `[P0] Add StageSelectView and fix Stage→Next progression in MissionHUD`
- `[P0] Add StageResultView (full screen)`
- `[P1] Author 12 missing SVGs (silhouette + vehicle_only × 6)`
- `[P1] Author 6 character expression atlases (2×2 grid, 2048²)`
- `[P1] Author 7 SCNParticleSystem trail files`
- `[P1] Add Theme.swift design tokens and migrate views`
- `[P1] Localize CharacterSelectView hardcoded strings ("Choose Your Adventure", "FLY!", "Select Map", "Vehicle", "Shared", "Unique")`
- `[P1] Localize MapTheme displayName / subtitle / regionNames`
- `[P1] Add SettingsView (mute, reset, language, privacy, support, about)`
- `[P1] Add SensitivityPreview live tilt indicator`
- `[P1] Add map-theme thumbnails in MapThemeCard`
- `[P1] Add boost / item cooldown rings on ThumbButton`
- `[P1] Add objective-compass arrow in MissionHUD`
- `[P1] Wire expression atlas to FlightEngine signals (boost/clear/collision)`
- `[P1] Replace emoji icons in CharacterTile/VehicleTile/MapThemeCard with Image() assets`
- `[P1] Add App Store screenshot scenes (3 layouts, 2868×1320)`
- `[P1] Free Flight result screen`
- `[P2] Apply @ScaledMetric to all typography`
- `[P2] Honor UIAccessibility.isReduceMotionEnabled in flight camera`
- `[P2] VoiceOver coverage on Mission / Result / Settings`
- `[P2] Add ja / zh-Hans / es / fr / de localizations`
- `[P2] Add touch-fallback steering when gyro is unavailable (simulator/iPad demo)`

---

## 8. Verification snippets used in this audit

```bash
# 1. Confirm zero asset references
grep -rn 'Image("'        TurtleFlight/   # 0
grep -rn 'imageNamed'      TurtleFlight/   # 0

# 2. Confirm no Asset Catalog
find TurtleFlight -name 'Assets.xcassets'  # 0 results

# 3. Confirm SVG count (36 character + 2 ui = 38)
find assets -type f | wc -l                # 38

# 4. Confirm emoji-as-icon
grep -n 'Text(character.config.emoji)'     TurtleFlight/Views/Home/CharacterSelectView.swift
grep -n 'Text(vehicle.icon)'                TurtleFlight/Views/Home/CharacterSelectView.swift
grep -n 'Text(theme.emoji)'                 TurtleFlight/Views/Home/CharacterSelectView.swift

# 5. Color mismatch sample
grep -n '0x2ECC71\|0xF0C27F\|0x95A5A6\|0x2C3E50\|0xECF0F1' \
    TurtleFlight/Core/Character/CharacterRegistry.swift
```

---

## 9. Bottom line

The **engineering** layer of Turtle Flight is in good shape (109 passing tests, 6 critical bugs already fixed per `VALIDATION_REPORT.md`). The **design** layer has been authored as 36 high-quality SVGs and a thorough style guide — and then **never integrated**. The visual experience the user actually receives in this binary is roughly:

- Brand-mismatched primitive 3D shapes,
- Emoji where the SVG icons should be,
- A black launch flash,
- A template app icon,
- Untranslated "Choose Your Adventure" / "FLY!" headers,
- No pause, no settings, no onboarding, no real result screen.

The work needed to close this gap is well-defined, sequenced in §6 above, and parallelizable across one designer + one engineer for ~6 sprints. None of it requires re-authoring the SVG art that already exists.
