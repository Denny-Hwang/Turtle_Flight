# Changelog

All notable changes to Turtle Flight per release.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely.
Versioning: [Semantic Versioning](https://semver.org/) for the iOS marketing
release; commits track sprint number for the current pre-1.0 development
window.

## [Unreleased]

### Added — Localization expansion + full AppIcon set

Closes two long-standing follow-ups: the five backlog locales and the
multi-size app icon export.

**Localization — 5 new bundle locales (ja, zh-Hans, es, fr, de)**
- Each `<locale>.lproj/Localizable.strings` translated from the en
  source of truth at **full 213-key parity** — ko/en plus the five new
  locales, seven total.
- Style per `docs/I18N.md`: ja kanji/katakana stage names, zh-Hans
  short 2–3 char stage names, es/fr/de informal "you" form, German
  button labels kept short to avoid HUD/button overflow.
- All five registered in `Info.plist` `CFBundleLocalizations`.
- **`Tests/LocalizationParityTests.swift`** (4 cases) — enforces, across
  every declared locale: presence, exact key-set match with en, no
  empty values, and matching `%lld`/`%@` format specifiers (a mismatch
  crashes `String(format:)` at runtime).
- **Build fix:** `project.yml` Resources path no longer uses
  `type: folder`. A folder reference nested the `.lproj` dirs under
  `Resources/`, where `NSLocalizedString` can't find them; the plain
  group reference lets XcodeGen emit them as variant groups at the
  bundle root. (This had silently broken even ko/en in XcodeGen builds.)
- `docs/I18N.md` + `README.md` (both languages) + `CLAUDE.md` updated
  to reflect 7 shipping bundle locales. App Store Connect *marketing*
  copy for the five new locales remains a separate, pending hand-off.

**Full classic AppIcon set**
- `AppIcon.appiconset` now carries every native iOS size
  (20/29/40/58/60/76/80/87/120/152/167/180/1024) rendered from
  `assets/ui/app-icon/app_icon.svg` at native resolution, flattened to
  opaque sRGB (no alpha — App Store rejects the marketing icon with an
  alpha channel) on the icon's base blue. Replaces the single-1024
  universal-idiom entry.
- `Contents.json` rewritten with the full iPhone + iPad + ios-marketing
  slot mapping.
- `scripts/build_assets.sh` app-icon stage updated to emit all sizes +
  the full Contents.json, so a future `librsvg + imagemagick`
  regeneration stays consistent with what shipped.

### Added — Sprint 4 (release infra + felt-acceleration + in-flight a11y)

After the post-PH polish merged, a senior service review surfaced
three remaining v1.0 blockers and four felt-game-design gaps. This
sprint closes the infrastructure blockers and the highest-ROI
gameplay-feel items; the larger content-design items (Daily
Challenge mode, CharacterRegistry primitive removal, ring plane-
intersection collision) are sequenced as v1.1.

**Release infrastructure (P0)**
- **XcodeGen `project.yml`** — the repository no longer requires
  "create a new Xcode project locally" as the README's first
  contributor step. `brew install xcodegen && xcodegen generate`
  produces a reproducible `TurtleFlight.xcodeproj` with deployment
  target / orientations / device capabilities / Info.plist /
  PrivacyInfo / asset catalog / `TurtleFlightTests` target all
  pre-wired. The generated project is intentionally not committed
  so contributor-side drift is impossible.
- **GitHub Actions CI (`.github/workflows/ios-tests.yml`)** — every
  PR and `main` push runs the full XCTest suite (169 cases) against
  the latest iOS simulator on macos-14. Concurrency-grouped per
  branch so newer pushes cancel stale runs. JUnit report uploaded
  as a 14-day artifact for triage.
- **`PRIVACY.md`** — the live privacy policy that `SettingsView.privacyURL`
  has always pointed at but never actually existed in the repo.
  Spells out the "nothing leaves the device" guarantee, every
  UserDefaults key the app writes, every Apple framework declared
  in `PrivacyInfo.xcprivacy`, COPPA/GDPR child-data positioning,
  and the user controls. Bilingual (en/ko).

**Felt acceleration (P1)**
- **Boost camera punch** — `FlightViewModel.updateCamera` now layers
  an 8° FOV widening and a 3m follow-distance pullback at
  `boostProgress == 1`, lerping smoothly back to the resting frame
  as the boost timer drains. The character's apparent on-screen
  size stays roughly constant so max-boost reads as "I got faster"
  rather than "the screen got smaller." Suppressed under Reduce
  Motion (the camera punch is exactly the kind of oscillation
  vestibular-sensitive players asked us to keep off the default
  table). New `Constants.Camera.fieldOfView` / `boostFOVDelta` /
  `boostFollowDistanceDelta` tokens for tunability.

**In-flight a11y (P1)**
- **PauseView sensitivity selector** — the pause modal now optionally
  surfaces a 3-button Easy/Normal/Expert picker under the
  Resume/Restart/Quit row. Wired through to
  `$flightVM.sensitivityLevel`, so the existing `didSet` re-applies
  the profile to both the gyro pipeline and the flight engine
  without a flight restart. Closes the 6-tap path (Exit → Home →
  Settings → Audio → Done → Mode → Stage → Character → FLY) that
  previously stood between a kid feeling "this is too sensitive"
  and actually fixing it. Selector visibility is opt-in via a new
  `sensitivityLevel: Binding<SensitivityLevel>?` parameter — nil
  hides it (preview / future contexts).

**Audio leak guard (P2)**
- **`AudioManager.playOneShot` hard cap** — the per-key cleanup
  scheduler always fired before, but a 0-duration read from
  `AVAudioPlayer.duration` would schedule its `asyncAfter` at +0.1s,
  which on a busy main thread occasionally slipped. Added a 24-entry
  cap on the `sfxPlayers` dictionary with FIFO eviction (calls
  `.stop()` on dropped players) plus a 2s fallback `cleanupDelay`
  when `player.duration <= 0`. Net effect: the dictionary cannot
  grow unbounded even under a frame where 6+ stars pop on the same
  tick.

### Tests — Sprint 4

No new test files this sprint — the changes are CI infra, design
tokens, and view-layer wiring with existing test coverage holding.
The new `Constants.Camera.fieldOfView` / `boostFOVDelta` /
`boostFollowDistanceDelta` tokens are referenced from
`FlightViewModel.startFlight` and `updateCamera` and consequently
exercised by every existing `FlightEngine*` integration case via
the indirect call path. PauseView's optional sensitivity binding
defaults to `nil`, so all pre-existing `PauseFlightTests` continue
to construct PauseView with the original 3-arg initializer.

### Deferred to v1.1

The senior review identified three larger gameplay-content items
that are intentionally NOT in Sprint 4 because they each carry
either test-compatibility risk or a substantial design-content
investment that should go through TestFlight feedback first:

- **Daily Challenge mode** — reuse the existing 5 stages with
  modifiers ("no-boost", "≥5 stars", "<55s"). Closes the
  15★ campaign cap vs. 50★ retention-tier gap. Needs translation
  work and a new MissionEngine modifier API.
- **Ring plane-intersection collision** — the current sphere-distance
  check at `MissionEngine.update:121` allows theoretical side
  passes; a plane-crossing replacement needs `prevPlayerPosition`
  tracking in MissionEngine, which a few existing tests would need
  to be re-pinned around.
- **CharacterRegistry primitive geometry removal** — ~600 LOC of
  legacy `SCNSphere`/`SCNCapsule` builders that the atlas billboard
  path has superseded. Removal saves both binary size and mental
  model overhead but the fallback semantics need to be verified
  on physical hardware before the legacy path can be deleted.

### Added — Retention loop + a11y closure (post-PH polish)

After the Product Hunt launch pass merged, a follow-up review pointed
to two genuine v1 gaps and four small polish items that had regressed
between PR #43 and PR #45. This entry closes them.

**Retention hook (new)**
- **Star-milestone trail color tiers** — the running `totalStars`
  count finally has a cosmetic outlet. Four tiers gate by star total:
  `vehicle` (default — per-vehicle colour) → `magenta` (50★) →
  `gold` (150★) → `rainbow` (300★, full-hue particleColorVariation).
  `MissionViewModel.completeMission` auto-promotes the selected tier
  exactly once per crossed milestone via `lastSeenTrailTierThreshold`,
  so the next flight visually rewards the achievement without the
  player having to discover Settings. Manual downgrades from Settings
  are respected.
- **Settings → Trail Color section** — picker over the four tiers.
  Locked rows show the threshold ("Unlocks at ★ 50"); the section
  footer nudges with "Earn 23 more ★ to unlock Gold". Section is
  built around `TrailTierRow` for VoiceOver clarity (each row exposes
  combined label + value + hint).
- **Codable migration** — `PlayerProgress` gains `selectedTrailTier`
  + `lastSeenTrailTierThreshold` via `decodeIfPresent`, so v1 saved
  blobs from before this PR keep decoding cleanly. `MissionViewModel.
  load()` clamps an over-claimed tier (e.g. after Reset Progress) down
  to whatever's actually earned.

**Observability (new)**
- **MetricKit subscription** — `Core/Observability/MetricsCollector`
  subscribes to `MXMetricManager` in `TurtleFlightApp.init`. Daily
  metric and diagnostic payloads (launch time, hang rate, CPU /
  memory, crashes, disk-write exceptions) log to OSLog. Zero
  third-party SDK; payload delivery is gated on the user's iOS
  analytics-sharing preference.

**A11y closure**
- **Home-screen mute toggle** — speaker chip next to the gear button,
  one-tap mute / unmute. The 3-tap path through Settings → Audio →
  Mute reads as hidden for a kids-rated game.
- **Visible collision flash** — thin red rim that fades 0.9 → 0 over
  ~0.45s on each collision. Edge-driven by a monotonic
  `FlightViewModel.collisionFlashTrigger` counter. Pairs the existing
  haptic + sound with a visual cue so deaf / silent-phone /
  hard-of-hearing players have an equivalent signal. Honours Reduce
  Motion (blinks rather than fades when on).
- **Color-blind safe collision counter** — collision chip on MissionHUD
  now layers three independent channels: icon shape (`triangle.fill`
  vs `checkmark.circle.fill`), colour (red vs green), and a 2pt red
  rim around the chip when count > 0. WCAG SC 1.4.1 closure.
- **`PauseView` Restart confirmation** — `restartRequiresConfirmation`
  flag wired from `FlightView` when `flightMode == .stepGoal &&
  missionState == .playing`. Free Flight and pre-mission pauses keep
  the fast path. Required `MissionDisplayState: Equatable`.

**Home polish**
- **Selected character cameo** — small chip ("Flying as / Turbo")
  between the title and mode buttons so the player always sees *who*
  they'll fly with on the next mode tap.
- **Step Goal smart subtitle** — `"0/15"` cold-start text becomes
  `"5 missions"` for first-run players; flips to running `"%d/%d★"`
  once any star is earned. Mission cap is dynamic via
  `stages.count * 3`.
- **Step Goal mode-button colour** — `starGold` → `brandPrimary` so
  the gold colour stays uniformly tied to "star reward" across the
  app.

**P1-2 closure**
- **Fire button hidden in v1** — `ControlButtons.onFire` is now
  optional; `FlightView` passes `nil`. The projectile has no impact
  behaviour, and showing a useless button trains the player to
  ignore controls. Symmetric padding reserved so the boost button
  stays anchored.

### Tests — post-PH polish
- `Tests/TrailColorTierTests.swift` — 13 cases pinning tier
  thresholds, `highestUnlocked` boundary behaviour, Codable round-
  trip + legacy-blob migration, MissionViewModel auto-promotion,
  manual-downgrade respect, and `load()`-time clamp.

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
