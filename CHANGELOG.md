# Changelog

All notable changes to Turtle Flight per release.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely.
Versioning: [Semantic Versioning](https://semver.org/) for the iOS marketing
release; commits track sprint number for the current pre-1.0 development
window.

## [Unreleased]

### World music: a real form instead of a 40 s loop (2026-11-26, plan M1–M3)
- Each world's song is now a 2–3 minute form, A → A′ → B → breakdown → A″ → B′ → A‴, that loops back to A. Before, one 8-chord progression looped for 37–53 s.
- B has its own chord progression and swaps the lead and counter voices.
- One motif per song is developed rather than copied:
  - stated, then sequenced up and down the scale
  - inverted in B
  - ornamented with passing notes in A‴
  - phrases end on a half cadence the first time and on the tonic after that
- Texture and dynamics follow the form:
  - drum intensity changes by section: light, full, half-time, none, then driving
  - a fill every 4 bars in A sections
  - a crescendo into the breakdown, where drums and bass drop out
  - accents on strong beats and ±8 ms timing variation
- Still fully synthesised offline (`scripts/audio/render_assets.swift`). Vehicle and effect files are byte-identical.
- Bundled audio grew from 6.4 MB to 17 MB.
- Not yet heard by a person: owner ear check (H4 / A1) pending.

### Ring path, course climb limit, miss feedback (2026-11-26, plan R1/R3/R4)
- The ring after the target is shown bright and opaque. Rings further on are dimmed to 50%. Seven sparkle dots light up in turn from the target ring toward the next one, so the next turn reads early.
- Audit: some courses asked for climbs steeper than Easy can fly.
  - Mountain Cross needed about 2.0 m up per metre forward. Some Daily Run days needed about 1.7, and route 23 about 1.4.
  - `CourseGenerator.limitClimb` now caps every step at a slope of 0.5. That is about 28 m/s at cruise, against Easy's 40 m/s.
  - The cap applies to all courses and to Sky Run chunks. `CourseClimbTests` enforces it.
- A missed ring flashes red as it fades, and the screen-edge guide pops for a moment.
- The ring guide now measures from the chase camera. Before, it showed for a ring a little above and ahead that was plainly on screen.

### Set pieces along the route (2026-11-26, plan W1–W3)
- Free Flight now places a set piece ahead of the player every 25–35 s. It appears 420–560 m ahead at the player's own height, and is skipped near landmarks and during a sky wonder. At most 2 are in the sky at once.
- 21 original pieces, 3 per world:
  - 14 to fly through, worth +1 ★ each: arches, tunnels and gates.
  - 2 updrafts that lift 30 m/s without costing speed.
  - 3 boost refills (+50% gauge).
  - 2 star bundles (+3 ★).
  - Seeing a piece for the first time shows a "New sight" banner (`SetPieceLog`, kept on the device).
- Static parts are baked into one mesh per material (`SetPieceFactory.bake`, reusing `PropMesh`). `flattenedClone()` lost rotated parents and produced empty meshes in tests.
- Not in missions. Screenshot runs skip set pieces unless `-TFSetPiece` is passed.
- 26 new strings in all 7 locales (457 keys with the joystick strings).

### On-screen joystick + control modes (2026-11-26)
- Settings → Controls now offers three ways to fly:
  - **Tilt** (default).
  - **Joystick**: a floating thumb stick in the lower half of the screen; the sensor and the calibration are skipped.
  - **Mixed**: tilt to turn, thumb for up and down, so the phone never has to be tipped away.
  - Options: invert up/down, and stick on the left (Boost moves right).
- The last onboarding page asks "How do you want to fly?" (tilt or finger).
  The calibration card has a "Use my finger instead" link.
- `StickInput` filters the stick on the render thread, frame-rate
  independent, with the level's curve. It fixes the old drag fallback,
  which never reached full input while the finger was still and kept
  65–92% of the turn after the finger lifted. A full diagonal is full turn
  plus full climb. Devices without a gyro fly with the joystick.
- 19 new strings × 7 locales; the 2 old touch-toggle strings were removed
  (431 keys).

### Tilt comfort + ring flow (2026-11-26, owner device feedback)
- Steering and climbing have their own tilt ranges (`AxisResponse`): full
  climb at 12–15°, full turn at 18–25°, smaller dead zones and gentler
  curves. Before, climbing needed so much tilt the screen was hard to see.
  Easy/Normal climb rate 40/70 m/s.
- Every stage start (including Retry and Next) puts the character back at
  the course start, level with and facing the first ring. Retry/Next used
  to start wherever the last run ended, often km away from the new rings.
- A missed ring (near miss, wide pass, or drifting 80 m past it) now counts
  as MISS and the target moves to the next ring instead of staying behind
  the player. Missing more than half fails the course; missed rings cap the
  stars (any → 2, over a quarter → 1). Kids unchanged.
- Screen-edge ring guide (`RingGuideIndicator`): a gold arrow plus the
  distance when the target ring is off-screen, "Behind you" when it is
  behind.
- Free flight: stars left 700 m behind are dropped and new clusters spawn
  250 m ahead, which ends the "star desert" after the first cluster.
- 3 new strings in all 7 locales (414 keys).
- Plan for the joystick, set pieces along the route and varied BGM:
  `docs/FLIGHT_FUN_PLAN.md`.

### Tilt controls fix + start-of-flight calibration (2026-11-24)
- Fix: in landscape the tilt axes were crossed. Leaning the phone
  forward/back turned the character, and tilting it left/right barely
  steered. Tilt is now read from gravity in landscape screen axes
  (`TiltMapping`), for both landscape sides, without yaw drift.
- Every flight, retry, resume, stage start and the Calibrate button now
  take the way the player is holding the phone as neutral. The world waits
  under a small card ("Hold it how you like") until the phone is still for
  0.6 s (or 2.5 s pass), or the player taps Start now (`CalibrationOverlay`,
  3 new strings in all 7 locales).
- Tipping the phone forward dives and speeds up, standing it up climbs and
  slows down, on every level. Easy gets the energy model too (about
  165–235 km/h at full tilt, no stall).
- The onboarding tilt preview uses the same mapping.
- `scripts/device/verify.sh`: fixed device detection (it passed the word
  `available` as the device id) and added `--no-scenes`.

### HUD tidy V9 (2026-11-23)
- Free flight now uses a quieter HUD by default. The speed and altitude gauges
  rest at 80% size and 60% opacity. They come back in full for 2.5 s when a
  value crosses a band (50 km/h / 100 m), and stay full while stalled, boosting
  or below 40 m. The sensitivity chip and compass letters are hidden; the
  flight clock, star counter and region name stay.
- Missions keep the full HUD.
- New setting: Settings → Controls → "Quiet gauges in free flight" (`hud.simple`,
  default ON, all 7 locales). Turning it off restores the previous HUD exactly.

### Decoration variety V8 (2026-11-23)
- Repeated ground props come in three shapes each, picked from their
  placement hash (same spot, same prop): meadow tree, pine, palm, blossom
  tree, tiled-roof house, town house (plus roof colours), and clouds. Each
  prop also gets its own size and turn (houses in quarter turns).
- Meadow speckles: flower bunches and grass tufts in patches on gentle
  ground (sky, seoul, wild, city; pebbles/scrub in the desert; shells and
  sea grass in the ocean).
- Static props and speckles are baked into the chunk's terrain mesh
  (`PropMesh`), and each cloud is one shared mesh: geometry nodes in the
  loaded chunks drop 40–80% per world. Chunk build time is within ~1–2 ms of
  before (cached primitive templates, speckles sample the chunk height grid).
- `LandmarkGalleryTests.testRenderDecorGallery` (`TEST_RUNNER_TF_DECOR=<dir>`)
  renders each world's ground from a low flight for before/after review.

### Landmark detail V7 (2026-11-22)
- Detail pass on the eight landmarks seen first in each world: floating castle,
  pyramids, sand guardian, grand arch, palace gate, canyon arch, ring planet,
  shipwreck (windows, trims, steps, faces, props; small motion on the castle
  banner, canyon birds, ring rocks and kelp). Colliders cover the new parts
  that stick out.
- Fix: `flattenedClone()` dropped geometry nested two levels down, so the
  palace gate never showed its roofs and the hanok village showed one house.
  Geometry is now lifted under the root before flattening.
- Review tools: `LandmarkGalleryTests` (off-screen renders, skipped unless
  `TEST_RUNNER_TF_GALLERY` is set) and `-TFTourKind` for the `tour` scene.

### Landmark materials V6 (2026-11-22)
- One material language for all 25 landmarks (`LandmarkStyle`, two SceneKit
  shader modifiers): darker, cooler feet fading to full colour at the top;
  soft two-band toon light over a gentle lambert slope; a per-world rim light
  that lifts silhouettes off the terrain. Glowing parts stay flat.
- Styling happens before flattening (`LandmarkFactory.styledParts`): a
  flattened clone fills in its materials lazily, so changes made to it are
  lost.

### Visual pass V1–V5 (2026-11-22)
- Terrain: real per-vertex normals (every vertex used to point straight up, so
  hills had no lit or shaded side), soft colour blending between height bands,
  rock on steep slopes, broad light/dark variation. Open-sky worlds get less
  ambient and a little more sun (flat ground was clipping to white).
- Water: the terrain noise is in [0, 1], so no world ever had water. Seoul,
  city and wild now sit lower (`WorldProfile.seaOffset`) so their valleys hold
  rivers and lakes under a rippling, sun-glinting water plane
  (`WaterSurface`); river boats in the city finally appear. Sky, space and
  ocean keep their 1.0 shape.
- Sky: painted cube map per world and mood (zenith-to-horizon gradient, sun or
  moon with glow, far cloud layer) replaces the flat colour and the drifting
  sun sphere; fog takes the horizon colour.
- Character leans into turns (billboard roll, up to ~22°, halved with Reduce
  Motion).
- Device verification kit: `scripts/device/verify.sh`, `PerfProbe`
  (`-TFPerfProbe YES`), `soak` scene; `docs/DEVICE_VERIFICATION.md`,
  `docs/VISUAL_AUDIO_PLAN.md`.

### Look ahead, sky extras, bundled audio, Swift 6 (2026-11-22)
- **Characters face where they fly.** In flight the character used to look
  back at the player the whole time. It now shows its back by default (new
  back-view art for all six friends on their own ride and on Cloud Surf:
  `<name>_back_atlas`, `<name>_cloud_back_atlas`, same 2×2 expression cells,
  so joy / scared / speed still read through pose and effects). A new
  **Look at me** button in the flight controls turns it round (and **Look
  ahead** back); the choice is remembered (`flight.lookAtMe`) and also lives
  in Settings → Controls.
- **Landmarks are solid** in Free Flight: a friendly bump (pushed out and
  turned away, soft haptic + "boing", scared face) with no penalty. Each
  landmark has a rough hull (`LandmarkKind.colliders`) that leaves the
  openings that look flyable open — under arches, between tower legs,
  through the sky wheel and the rainbow gate, behind the waterfall.
- **Sky wonders**: about one Free Flight in three, a surprise appears ahead
  — meteor shower (night / space), round rainbow (day), cloud whale, glow
  tide (ocean). Fly up to it for +3 stars; the album gets a "Sky Wonders"
  page (`wonders.v1`).
- **Postcard milestones and Festival**: half a world's postcards pays 5
  stars, all of them 10 stars and unlocks that world's Festival — paper
  lanterns (pearls under the sea, star lanterns in space) and fireworks in
  Free Flight, switchable per world in the album. Paid with the Free Flight
  result; an in-flight banner marks the moment.
- **Bundled audio**: a music loop for each of the 7 worlds (the four new
  worlds used to fall back to the sky tune), an engine loop per vehicle and
  the 8 sound effects, all rendered offline by
  `scripts/audio/render_assets.swift` (plucked strings, FM bells, flute,
  pads, hand drums — no samples) into `TurtleFlight/Audio/` (6.4 MB).
  `bash scripts/audio/build_audio.sh` regenerates them. The in-app synth
  stays as the fallback.
- **Swift 6**: the app target now builds in the Swift 6 language mode with
  zero warnings. Shared singletons say how they are thread-safe (lock,
  serial queue, or main-only contract); haptics and audio hop to the main
  actor through `performOnMainActor`; the ReplayKit preview is wrapped
  instead of retro-conforming an Apple class. Tests stay in Swift 5 mode.
- Store screenshots: two more scenes (`tour` at sunset in the desert, and a
  sky wonder over a festival) — 8 per device.
- Tests: 469 (new `SkyExtrasTests`, `FacingTests`, bundled-audio coverage).

### Result screens, iPad layout (2026-11-21)
- The in-flight HUD and control buttons (gauges, stage/timer chip, Pause/Exit,
  ring/score, Boost) hide while a result screen is up — on iPad the scaled-up
  result card overlapped the timer chip. They are also out of hit-testing and
  VoiceOver while hidden, and come back on Retry.
- Stage result card is fully opaque (the character ghosted through at 90%); the
  Home button gets its own light fill so it no longer reads as bare text.
- Free Flight summary scales up on iPad like the stage result.
- iPhone landscape: the stage result and the Free Flight summary switch to two
  columns (title + stars on the left, stats on the right, buttons underneath).
  Stacked, Stage 3's six stat lines pushed the card to the screen edge and the
  Free Flight summary ran off the top and bottom. Free Flight gets the same
  solid card as the stage result.
- Fix: tapping Exit in Free Flight (and Share clip) paused the flight, which drew
  the Pause menu on top of the summary. The Pause menu no longer shows over a
  result screen; stage Retry / Next resume a flight Share clip paused.
- **iPad layout: device canvas.** iPads used iPhone point sizes (tiny text, a
  mostly empty 13" screen); only a few tiles had a 1.4x bump. Each custom
  full-screen UI (Home, character select, route map, onboarding, flight HUD and
  controls, pause, results) now lays its foreground out on a ~880x580pt canvas
  and scales it to fill the safe area (`DeviceCanvas`, `.deviceCanvas()`):
  about 1.2x on iPad mini, 1.3x on 11", 1.55x on 13". iPhones stay at 1x.
  Backgrounds, the SceneKit view and system sheets are not scaled.
  `Theme.iPadScale` / `adaptiveFrame` are removed.
- Pause menu: the HUD hides behind it (the stage/timer chip overlapped the
  panel), the panel is opaque, and Quit / unselected sensitivity chips get a
  visible fill.
- QA capture scenes: `freeflight-result`, and `stage-result` with
  `-TFStageIndex <n>`; `qa_matrix.sh` takes `EXTRA_ARGS`.

### Routes follow-ups (2026-11-20)
- Route map announces Star Road the first time it shows open (banner, haptic,
  VoiceOver announcement, scrolls to the route) — whether the last course or a
  secret code opened it. The flag clears itself after a progress reset.
- Docs: the repository is private now; the "never commit code plaintext" rule stays.

### Routes, Kids mode, rewards, haptics, secret codes (2026-11-20)
Design + progress: `docs/ROUTES_REWARDS_PLAN.md`.
- **Routes.** The campaign is now five parallel routes (`RouteCatalog`):
  Sky School (the original five stages, indices unchanged), Sun Road
  (desert → city), East Trail (seoul → wild), Deep Blue (ocean) and Star
  Road (space). Each world's courses differ in ring count and ring size
  and get harder step by step. Four routes start with their first course
  open; Star Road opens when the other four are finished, or with a code.
  The stage picker is now a route map.
- **Kids mode.** A global switch (route map + Settings). Every course
  becomes its `kidsVariant()`: bigger and fewer plain rings, no clock, a
  missed ring is skipped instead of sending the player back, bumps don't
  cost stars. A Kids course cannot be failed.
- **Haptics.** `Haptics` maps every game moment to its own pattern
  (bullseye / great / ok, rim bump, miss, ground hit, boost, pickups,
  clear / fail, shop, codes). Settings → Controls → Vibration.
- **Rewards.** A star wallet shared by all characters plus one treat per
  animal (lettuce, fish, sunflower seed, yarn, firefly, carrot). Stars buy
  Free Flight skies and open the next course early; treats buy that
  character's own trails. No purchases with real money.
- **Secret codes.** Five free promo codes, entered in Settings or the
  shop, validated offline against salted hashes (`SecretCodes`), once per
  save. `SecretCodes.isEnabled` hides the field.
- **iCloud sync** now merges the two saves field by field
  (`CloudSync.merge`: best result per course, union of purchases /
  unlocks / used codes, larger balances) instead of replacing one blob
  with the other, and compares against live progress rather than a
  launch-time snapshot. Kids mode stays per device.
- Kids clears are stored apart (`kidsResults`): they open the next
  course and pay rewards but are not campaign stars. A replay that
  doesn't beat the best pays one star.
- New saved fields are all optional-on-decode; an old save's wallet
  starts with the stars it already earned.
- Tests: `RoutesRewardsTests`. 452 tests.

### World tour & flight delight (2026-11-20)

- **Four new worlds** — Desert Ruins, City of Lights, Seoul Sky, Wild
  Nature (`MapTheme` now has 7). Terrain shape and colour are data
  (`WorldProfile`: rolling / dunes / plain), each world has its own
  props, and a coarse far-terrain mesh plus distance haze give every
  world a horizon.
- **25 landmarks** (`LandmarkKind`, `LandmarkFactory`, `LandmarkField`)
  — original, primitive-built places on a deterministic grid, 3–4 per
  world including the original three. They are "inspired by a kind of
  place", never a model of a real monument, with our own names.
  Free Flight only; missions keep the airspace clear.
- **Sky Postcards** — fly within 150 m of a landmark to collect its
  postcard; every character can add a stamp (`PostcardAlbum`, on-device
  only, cleared by Reset Progress). Compass chip to the nearest place
  this character has not visited; album on the Home screen.
- **Hello fly-bys** — passing close to a balloon, whale, UFO, camel
  caravan, river boat, cable car or eagle earns +1 star and a hop back.
- **Sky mood** — open-sky worlds pick morning / day / sunset / night
  per flight (`SkyMood`, deterministic, cosmetic only).
- **Character specialties** (`FlightSpecialty`) — Turbo long boost, Pip
  fastest dash, Nutty quick refill, Mochi star magnet, Bounce boost
  lift, Hoppy bullseye refund. Shown on Character Select.
- **Touch controls** (Settings → Controls), **gate-pass pulse**,
  Free Flight **clean view**, and a **streak rest day** (one missed day
  no longer breaks the streak).
- Renamed an ocean region that read as "Pearl Harbor" (en/ko/zh).
- Tests: `WorldTourTests` + additions. 419 tests.

### Launch polish — character redesign, layout QA (2026-11-20)

- **Character art redesigned** (all six + app icon). Sources are now a
  deterministic generator, `scripts/characters/generate.py` (shared eye,
  shading and outline system in `kit.py`, one module per character) →
  `assets/characters/**.svg` → `scripts/build_assets.sh`. Palettes are
  unchanged; every character gets a silhouette-level trait (Turbo's
  shell + goggles + scarf, Hoppy's flopped ear, …).
- **The vehicle is visible in flight.** The in-flight atlas is now
  "riding the vehicle × 4 expressions" (`{name}_atlas`), with a second
  `{name}_cloud_atlas` for Cloud Surf
  (`CharacterRegistry.atlasName(for:vehicle:)`). Billboard 2.0 → 5.0
  world units (~4% → ~13% of screen height).
- **Fixed: expressions were vertically flipped.** Texture space starts
  at the top of the image, so the game showed "scared" in normal flight
  and "speed" on a bullseye. `CharacterExpression.atlasCell` corrected.
- **Fixed: trail particles rendered as opaque squares** over the
  character (no particle image). Soft round sprite; the emitter moved to
  the art's lower edge.
- **Layout (found by `scripts/screenshots/qa_matrix.sh`: 3 devices × 7
  languages × 9 screens):** pause panel no longer runs off a landscape
  iPhone; Home and Character Select are two-column on short screens so
  the mode cards, sensitivity and the character tiles are visible
  without scrolling; stage cards fit with their description; white
  labels on the pale end of the Sky gradient got dark chips.
- **Strings (7 locales):** singular streak ("1 Tag in Folge", not
  "1 Tage"), sensitivity names localized (were hard-coded English),
  `characterSelect.section.character`. Long German labels shrink
  instead of breaking mid-word.
- Tests: per-vehicle atlases ship for every character, billboard size,
  atlas rows, trail particle image. 399 tests.

### Launch prep — voice callouts, US launch settings

- **Voice callouts** — `VoiceLine` (9 lines: go, bullseye, great,
  combo 5/10/20, boost, stage clear, stage fail) played on one
  priority channel in `AudioManager.playVoice`: a line only cuts in
  when strictly more important, OK passes stay silent, combo
  milestones beat the judgement. Follows Mute and SFX volume, silent
  under VoiceOver, new Settings toggle "Announcer voice"
  (`settings.audio.voice`, 7 locales). Clips are bundled only — a
  missing clip is silent, nothing is fetched at runtime.
- **`scripts/audio/generate_voice.sh`** + `voice-lines.json` — Google
  Cloud Text-to-Speech Neural2 (`en-US-Neural2-F`) → AAC m4a.
  `--dry-run` for agents/CI; a real run is refused inside Claude Code
  or CI and uses Application Default Credentials only. Generative
  voices are refused (4+ app; Google Service Specific Terms).
- **Preflight** validates the voice manifest and reports missing clips.
- **Submission doc** — US-only availability, automatic release,
  privacy/support URLs, current screenshot sizes (6.9" + 13"),
  voice-clip runbook (§9). **Tests:** `VoiceLineTests` (7).
- **Automated store screenshots** — Debug-only `ScreenshotDirector`
  (autopilot through real ring centres, freeze on a combo bullseye),
  `scripts/screenshots/capture.sh` (iPhone 6.9" + iPad 13", status bar
  9:41, Dynamic Island removed), `compose.py` (captioned store shots +
  social / square / story promo images) → `marketing/` (gitignored).
- **Layout fixes found by the captures** (all iPhones in landscape):
  Home, Character Select and Stage Select were taller than the screen —
  Character Select's FLY button and Stage Select's back button were
  off-screen; they now scroll under a pinned header. Plus / Pro Max
  landscape no longer gets the iPad 1.4× tile scale (`AdaptiveSize`
  needs regular *height* too). In-flight: the ALT gauge sat under the
  Calibrate / Pause / Exit row, and in Step Goal the course title box
  covered the compass clock — ALT moves below the row, the free-flight
  readout hides in Step Goal. Daily / Sky Run titles were the Korean
  fallback ("Stage 101: 오늘의 코스") in every language; they now use
  the localized "Today's Course" / "Sky Run". **Tests:**
  `LaunchPolishTests` (2).

### Phase 5 — App Store readiness

Closes every item the repository can close before an upload.

- **Dead code:** the ~600-LOC low-poly `SCNSphere`/`SCNCapsule` character
  and vehicle builders in `CharacterRegistry` are gone. Nothing outside
  their own tests could reach them since the atlas billboard landed in
  PR #36. The registry now exposes only `buildInflightBillboard` and
  the trail particle builder.
- **Usage strings:** `NSPhotoLibraryAddUsageDescription` (ReplayKit's
  "Save" in the share sheet) added; `InfoPlist.strings` in all seven
  locales carry the motion + photo-library descriptions so permission
  prompts are localized.
- **CI:** a Release-configuration build now gates every PR (optimised
  builds surface diagnostics Debug hides), and `scripts/preflight.sh
  --no-build` runs the static submission checks.
- **`scripts/preflight.sh`:** local pre-archive gate — Info.plist keys,
  privacy manifest, localization parity (both `.strings` files), icon
  slot, entitlements, then Release build + full tests.
- **Docs:** `docs/APP_STORE_SUBMISSION.md` (capabilities, exact Game
  Center IDs, privacy labels, export compliance, review notes,
  screenshot plan, tuning knobs) and `docs/store/<locale>.md` marketing
  copy (name, subtitle, promo, description, keywords, what's new) for
  en/ko/ja/zh-Hans/es/fr/de. README, CLAUDE.md, I18N and
  VALIDATION_REPORT refreshed.


### Phase 4 — 완성도 (polish)

Last roadmap phase. Everything here is either opt-in or invisible
until a player has earned it.

**Audio**
- Bundled-asset hook: `AudioManager.assetURL(named:)` looks for
  `bgm_<theme>`, `vehicle_<name>`, `sfx_<event>` in m4a / caf / wav /
  mp3 before falling back to synthesis, so real recordings can be
  dropped in with no code change and a partial drop still works.
- Synth BGM rewritten: a four-bar progression per theme with a triangle
  pad, plucked arpeggio and low-passed wind bed, looping cleanly at 32 s,
  replacing the single static chord that fatigued by the third run.

**Clip sharing (opt-in)** — `ClipRecorder`
- Settings → "Record clips" starts a ReplayKit recording at flight
  start (mic off); result screens gain "Share clip", which opens Apple's
  trim/share preview. Home / Retry discard the recording.

**iCloud progress sync (opt-in)** — `CloudSync`
- Mirrors the progress blob through iCloud Key-Value Storage. Merge
  rule: a remote copy is accepted only when strictly ahead (campaign
  stars, then bonus stars, then flight time), so an old device can
  never clobber a newer one. Entitlement via `project.yml`.

**Character mastery** — `CharacterMastery`
- Per-character XP from flights (start, gates, bullseyes, clears, minutes)
  → 10 levels with five titles. Level badge on the character tile and
  the Home cameo. Pairs with the `flyCharacter` quest.

**Docs** — README (tooling, CI, features), SDD §3.5/§3.7, CLAUDE.md
roadmap closure, PRIVACY.md (iCloud, ReplayKit).
**L10n:** 12 keys × 7 locales (273 each). **Tests:** `Phase4PolishTests` (13).


### Phase 3 — 리텐션 (retention loop)

Third roadmap phase: the reasons to open the app *today*.

**Today's Course (Daily Run)** — `DailyRun`
- A 12-gate course generated from a stable hash of the calendar date:
  same course for every player, new one tomorrow. Pattern, gate recipe,
  spacing, amplitude, jitter and radius all come from the seed. 120 s
  limit, ★★★ under 75 s. Best result stored per day
  (`PlayerProgress.dailyResults`, trimmed to 60 days), never in the
  campaign ladder.

**Sky Run (endless)** — `EndlessCourse`
- Rings arrive in 24-ring chunks; `MissionEngine` refills when fewer
  than 10 remain and detaches passed rings, so memory stays flat.
  Radius, spacing and wobble tighten with distance; hard gate kinds
  appear more often deeper in. Three misses end the run as a
  *completion* whose headline is gates passed. Hearts on the HUD.
  `PlayerProgress.endlessBest`.

**Daily quests + streak** — `QuestSystem`
- Three quests a day from a seeded pool (stars, gates, bullseyes, clean
  clear, minutes, daily course, combo, character). Progress is fed from
  the game loop; claiming pays **bonus stars** that count toward the
  trail-colour tiers (`effectiveStars`), finally making the 50/150/300★
  cosmetics reachable. Day streak (from `Analytics` play days) shown on
  Home.

**Ghost replay** — `GhostTrack` / `GhostRecorder` / `GhostStore`
- Every course run is recorded at 10 Hz; the best-scoring run per
  course is saved (~20 KB JSON) and replayed as a 35 % opacity billboard
  keyed on the mission clock. Daily ghosts are keyed by day.

**Game Center (opt-in)** — `GameCenterManager`
- Off by default. When enabled: leaderboards for campaign stars, Daily
  Run score, Sky Run length; achievements for first bullseye, combo 10,
  Sky Run 50, campaign 15★, 7-day streak. Entitlement added via
  `project.yml`.

**Reminders (opt-in)** — `ReminderScheduler`
- Local notifications only: daily 18:00 "today's course is ready" and a
  one-shot streak nudge that is pushed a day out on every launch.

**UI** — Home: Today's Course + Sky Run buttons under Fly now, quest
strip with claim, streak chip. Settings: Game Center & Reminders
section. Result screen: Sky Run headline, special-course titles.

**Privacy** — `PRIVACY.md` updated (quests, ghosts, opt-in Game Center
and notifications). **L10n:** 35 keys × 7 locales (261 each).
**Tests:** `RetentionTests` (16).


### Phase 2 — 코어 재미 (core fun loop)

Second roadmap phase: turns "flying through hoops" into a precision game
with a skill ceiling. Builds directly on Phase 1's plane-crossing
`RingCrossing.accuracy`.

**Gate judgement + combo scoring**
- Every crossing is judged by centre accuracy: **BULLSEYE** (≤ 20 % of
  the radius, ×3), **GREAT** (≤ 60 %, ×2), **OK** (inside the rim, ×1),
  **MISS** (plane crossed outside, combo reset). `GateScoring` /
  `RunScore` (pure, tested); `MissionEngine.score`, `lastJudgement`,
  `lastPointsEarned`. Combo adds +10 % per step up to +100 %.
- `StageResult` gains optional `score`, `maxCombo`, `bullseyes` (old
  saved blobs still decode). `StageResultView` shows them with a
  score-line "New Best!" badge.
- HUD: centre-screen judgement callout with points, score chip, combo
  chip (from x2), VoiceOver announcement; rigid haptic on bullseye,
  warning haptic on miss.

**Gate kinds** (`GateKind`, assigned per course by `GateRecipe`)
- `shrinking` — from full size when it becomes the target down to 50 %
  over 6 s. Hesitate and the hole closes.
- `tilt` — an elliptical slit (45 %, rolled 45°). Lateral *and* vertical
  precision at once. Rendered by squashing + rolling the torus.
- `moving` — centre oscillates ±40 m laterally with a 4 s period; the
  hit test uses the live centre.
- Combo shrink (`CourseSpec.comboShrink`): the judged radius tightens
  4 % per combo step down to 60 %, and the ring is drawn at exactly
  that size.
- Campaign: Cloud Maze + Valley Run get shrinking gates every third
  ring, Mountain Cross alternates tilted slits, Sky Race mixes all four
  after a 3-ring warm-up and has combo shrink on. Sky Walk stays plain.

**Flight energy model** (`SensitivityProfile.energyModelEnabled`)
- Normal / Expert: diving trades altitude for speed (0.6 km/h per s per
  m/s), climbing bleeds it, drag relaxes toward cruise (2 s half-life),
  clamped 60–380 km/h. Easy keeps constant airspeed.
- Expert stall is now real: below 100 km/h the nose drops 25 m/s and
  turn authority falls to 35 % until a dive restores speed. HUD shows a
  red STALL chip; `FlightEngine.isStalling` finally means something.

**Boost gauge**
- Boost needs a full gauge and drains it; each star restores 20 %
  (5 stars = a boost) and it trickles back over 40 s. The button ring
  now shows charge when idle (gold when ready) and remaining burst when
  boosting. Stars have a purpose.

**Fly now**
- Home gets a primary "Fly now" button: one tap into Free Flight with
  the current character / vehicle / theme. The old shortest path was
  four screens.

**L10n:** 13 new keys × 7 locales (226 each).
**Tests:** `GateScoringTests` (17), `EnergyModelTests` (10).


### Phase 1 — 기반 수리 (foundation repair)

First of the four roadmap phases from the 2026-09 senior review
("1만명 지속 사용자" plan). This phase fixes what the later phases
build on; no new player-facing modes yet.

**CI**
- `.github/workflows/ios-tests.yml` no longer pins `Xcode_15.4.app` /
  `iPhone 15`. Both had vanished from the hosted image, so every run
  since Sprint 4 failed in ~20s before building. The workflow now uses
  the image's default Xcode, picks the newest iPhone simulator at
  runtime, and formats output with `xcbeautify`.

**Bugs**
- `PlayerProgress.totalFlightTime` and `bestFreeFlightStars` were never
  written — the Home stats row read "Best: 0 | 00:00" forever and the
  Free Flight "New Best!" badge compared every run against zero.
  `MissionViewModel.recordFreeFlight(flightTime:starsCollected:)` now
  persists both on Exit / Quit; stage clears and fails add their
  elapsed time (`failMission(reason:elapsed:)`).

**Ring passage is a plane-crossing test**
- `MissionEngine` tracks `prevPlayerPosition` and tests the segment
  against each ring's disc (`MissionEngine.crossing(of:index:from:to:)`).
  A fly-by 49m beside a 50m ring no longer counts. Each crossing
  reports `accuracy` (0 = centre, 1 = rim, >1 = miss) via
  `lastCrossing` / `crossingCount` / `ringMisses` — the hook Phase 2's
  BULLSEYE / GREAT / OK scoring plugs into.
- Rings carry a `normal` and the torus node is rotated to face the
  course direction, so what the player sees is the plane that's tested.
- Every stage's first ring now starts one spacing ahead of the spawn
  point instead of on top of it.

**Flight loop runs on the render thread**
- `SceneKitView.Coordinator` calls `FlightViewModel.tick(at:)`
  synchronously from `renderer(_:updateAtTime:)`. The old
  `DispatchQueue.main.async` hop added a frame of input latency and let
  the rendered position lag the simulation by a frame.
- `@Published` HUD values are collected into a `HUDFrame`, compared at
  display granularity (whole km/h, metres, seconds, ~1° arrow buckets)
  and applied on main at most once per render frame. Level cruise now
  produces zero SwiftUI invalidations per second instead of ~500.
- Haptics, audio and the mission-terminal callback route through
  `onMain(_:)` (synchronous when already on main, so tests are unchanged).
- The chase camera's `SCNLookAtConstraint` is created once per flight
  instead of once per frame.

**Data-driven courses**
- `CourseSpec` (Codable) + `CourseGenerator` replace the five hard-coded
  `sin` formulas in `StageDefinition`. Same layouts, now expressible as
  data, seedable (`SeededRandom`, SplitMix64) and jitterable — the
  foundation for Daily Run and Endless in Phase 3.

**On-device analytics**
- `Analytics` records funnel events (session, onboarding, flight start,
  ring pass / miss with accuracy, stage clear / fail, free-flight end)
  to OSLog and to three `UserDefaults` counters. **Nothing leaves the
  device**; Reset Progress wipes them. Documented in `PRIVACY.md`.
  Also the single source of truth for "days played" / streaks.

**Tests**
- `Tests/RingCrossingTests.swift` (20), `Tests/AnalyticsTests.swift`
  (8), `Tests/Phase1FoundationTests.swift` (12). Ring-passage tests
  migrated to `MissionEngine.testPass(ringIndex:)` (two-frame segment
  through the ring) via `Tests/MissionEngineTestDrive.swift`.


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
