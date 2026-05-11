# Changelog

All notable changes to Turtle Flight per release.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely.
Versioning: [Semantic Versioning](https://semver.org/) for the iOS marketing
release; commits track sprint number for the current pre-1.0 development
window.

## [Unreleased]

### Added — Product Hunt launch pass

Post-Sprint-3, before the v1.0 cut, an Apple-senior-grade review of the
service surfaced a list of blockers and polish gaps for App Store and
Product Hunt readiness. This pass closes them.

- **Privacy manifest** — `PrivacyInfo.xcprivacy` declares CoreMotion
  (CA92.1) alongside the existing UserDefaults entry plus the three
  Required-Reason API categories Apple's 2024 manifest review checks
  for (SystemBootTime, DiskSpace, FileTimestamp).
- **VoiceOver across the HUD** — speed, altitude, sensitivity level,
  compass + flight time, star count, region label, mission remaining
  time, mission progress, and collision count all expose
  `accessibilityLabel`/`accessibilityValue`. Star pickups also fire a
  `UIAccessibility.post(.announcement)` so VoiceOver users hear what
  their non-blind peers see flash on the chip.
- **Onboarding Try Tilt page** — fourth onboarding card runs a live
  `CMMotionManager` preview so the gyro mechanic gets felt before the
  player has to commit to a real flight. Sensor lifecycle is scoped
  to the card's visibility.
- **Free Flight share** — `ShareLink` on the result screen sends a
  formatted "Flight time + stars" blurb to Messages / Photos / Mail.
- **Vehicle handling differentiation** — `VehicleHandling` (turn /
  pitch / bank multipliers in [0.85, 1.20]) per `VehicleType`, plumbed
  through `FlightEngine`. Carrot jet feels noticeably sharper than
  cushion balloon; sensitivity profile remains the dominant axis.
- **Mission curve smoothing** — Stage 3 gains an explicit
  `star3Time = 150s` next to the "collect every star" path; Stage 4
  tightened (140s/110s); Stage 5 star3 relaxed from 80s to 90s. The
  120 → 80 cliff between Stage 4 and 5 becomes a 110 → 90 ramp.
- **Camera + items tuning** — `Constants.Camera.lerpSpeed` 0.10→0.15
  (cuts ~100ms tracking lag on hard turns), `bankingAngle` 0.15→0.25
  (more readable visual bank), `Items.starRespawnCooldown` 4.0s→2.0s
  (no more "wait for stars" lulls).
- **Reduce Motion in the space theme** — star dome drops from 200 to
  60 nodes and the nebula sphere is skipped entirely when the system
  toggle is on; mitigates first-frame stutter and the busy field
  vestibular-sensitive players otherwise see.
- **Terrain action cleanup** — `TerrainGenerator.clearAllChunks()` and
  the per-frame chunk eviction path now call
  `stopAllActionsRecursively(in:)` before `removeFromParentNode()` so
  the `.repeatForever(...)` actions attached to every decoration stop
  accumulating on long sessions.
- **Landscape safe-area awareness** — HUDOverlay and MissionHUD wrap
  in `GeometryReader`, take `proxy.safeAreaInsets` for horizontal/top
  insets so HUD chrome no longer crowds the Dynamic Island on iPhone
  15 Pro+ landscape.
- **Launch screen branding** — `UILaunchScreen.UIImageName` set to
  `turbo_default` so the first frame after tap-to-launch reads as
  "Turtle Flight" rather than the brand sky on its own.
- **Settings → Sensitivity Guide** — a new form section explains the
  three sensitivity levels (dead zone, response curve, auto-level,
  max tilt) so the player can make an informed pick from Home.

### Sprints 0–3 (PR #43, PR #44)

Sprints 0–3 land in PR #43, branched off `main` after the visual-design
pipeline (PRs #25–#42) finished. This series focuses on the gameplay
loop, the missing `Settings` surface, and the accessibility / portability
pass needed for App Store submission.

### Added — Sprint 0 (P0 game-loop fixes)

- **Mission completion bridge** — `FlightViewModel.onMissionTerminalState`
  edge-detects `MissionEngine` state changes and bridges to
  `MissionViewModel.completeMission` / `failMission`. Without this,
  Step Goal mode silently never ended for the player.
- **Ground-clearance collision detection** —
  `FlightViewModel.checkGroundCollision` debounced 0.5s, fires heavy
  haptic + new `SynthAudio.generateCollisionSFX` thump.
- **MapTheme + StageDefinition localization** — 50 new L10n keys per
  locale (theme display names / subtitles / 24 region names; stage
  descriptions and 3-star conditions). `MapTheme` now resolves through
  `L10n.t`. `StageDefinition.displayDescription` /
  `displayStar3Condition` computed properties with fallback.

### Removed — Sprint 0

- **`CharacterAnimator.applyFlightPose` and 7 vehicle helpers** (~190
  LOC). Dead since the SCNPlane atlas-billboard migration in PR #36 —
  they assumed a separate vehicle node that no longer exists.

### Added — Sprint 1 (gameplay polish)

- **Star pickup HUD pulse** — counter chip springs `1.0 → 1.4 → 1.0` on
  each pickup.
- **Boost cooldown ring** — `ThumbButton` optional progress ring overlay,
  drains as the boost timer counts down.
- **Objective compass arrow** — chevron under stage title rotates to
  point at the next ring; tints green when within ±20° of on-course.
- **Timer countdown beeps** — new `playTimerTick` SFX fires at 5s/3s/1s,
  idempotent across frames.
- **Free Flight star respawn** — fresh cluster spawns when uncollected
  pool drops below 3, debounced 4s.
- **Stage 3 ring clearance** —
  `MissionEngine.startStage(_:terrainHeightAt:)` clamps each ring's y
  above `groundY + ringRadius + 20`.
- **Stage 4 mountain pillars** — Mountain Cross now spawns procedural
  mountain decorations (lower bulk + peak cone + snow cap) under each
  ring, anchored to the terrain mesh.

### Removed — Sprint 1

- **`CharacterConfig.personality`** field — 6 hard-coded Korean strings
  never displayed in any view (invisible localization debt).

### Added — Sprint 2 (settings + audio + Reduce Motion)

- **`SettingsView`** — Form-based modal with three sections:
  - Audio: Mute toggle, BGM volume slider, SFX volume slider.
  - Progress: Reset Progress (destructive, with confirmation),
    Replay Tutorial.
  - About: Version, Privacy Policy link, Support link, Credits sub-sheet.
- **HomeView gear button entry** — top-right `.ultraThinMaterial`
  background, VoiceOver labelled.
- **Reduce Motion camera dampening** — chase-camera lerp drops to
  0.45×, `SCNLookAtConstraint.influenceFactor` drops to 0.5 (was 0.9)
  when iOS Reduce Motion is on.
- **`AudioManager` public volume API** — `setBGMVolume(_:)` /
  `setSFXVolume(_:)` clamp + persist via UserDefaults.
  `defaultBGMVolume` / `defaultSFXVolume` static defaults.
- 30 new L10n keys per locale for settings + a11y labels.

### Added — Sprint 3 (accessibility + portability)

- **Simulator / iPad-without-gyro touch fallback** —
  `GyroController.injectFallback(rollNormalized:pitchNormalized:)` /
  `releaseFallback()`. `SceneKitView` adds a `UIPanGestureRecognizer`
  that pipes drag translation through the same dead-zone + curve +
  smoothing pipeline as a real gyro sample. Real-device sessions
  short-circuit. Gyro-unavailable alert no longer dismisses the flight.
- **Dynamic Type aware typography variants** — five new
  `Theme.Typography.*Dynamic` tokens routing through `.body / .title2 /
  .callout / .caption` text styles. Adopted on Onboarding card text,
  StageResultView failure body, FreeFlightResultView subtitle, PauseView
  subtitle.
- **iPad adaptive frame sizes** — `Theme.iPadScale` (1.4) +
  `.adaptiveFrame(compactWidth:compactHeight:)` modifier. Applied to
  HomeView ModeButton, CharacterTile, StageCard.
- **`docs/I18N.md`** — process doc for adding new locales (ja /
  zh-Hans / es / fr / de remain pending; this is the engineering
  contract that turns translator output into a working bundle).

### Tests

- `Tests/MissionTerminalBridgeTests.swift` (12 cases)
- `Tests/CollisionDetectionTests.swift` (10)
- `Tests/LocalizationCoverageTests.swift` (8)
- `Tests/Sprint1PolishTests.swift` (13)
- `Tests/SettingsAndAudioTests.swift` (9)
- `Tests/Sprint3AccessibilityTests.swift` (8)
- **Total new: 60 cases.** Pre-existing 109 continue to pass.

### Known follow-ups (post-1.0)

- **`P0-5`** — AppIcon multi-size export. The `scripts/build_assets.sh`
  pipeline is in place but needs to run on a host with `librsvg +
  imagemagick` to produce the 60/76/120/152/167/180 sizes. Current
  single-1024 universal idiom is valid for iOS 16+ App Store but the
  full set is preferred.
- **`P1-2`** — Item projectile impact behaviour. The button fires a
  star sphere that flies forward and expires; v1.1 decision: targets
  with scoring, or hide the button.
- **`P1-10`** — Stall feedback on Expert sensitivity. The existing
  `FlightEngine.isStalling` API stays dormant because in-flight speed
  is currently constant; activates if a future PR adds variable-speed
  mechanics.
- **`docs/I18N.md`** — actual ja/zh-Hans/es/fr/de translations.
- **`xcodeproj`** — repository ships sources only; the
  `TurtleFlight.xcodeproj` package must currently be created locally
  (see README "Getting Started"). XcodeGen / Tuist integration not yet
  introduced.
