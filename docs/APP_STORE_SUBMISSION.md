# Turtle Flight — App Store Submission Checklist

Everything the repository can do for a submission is done: the app
builds in Release, 390+ tests pass in CI, every locale ships usage
strings, the privacy manifest and policy are in place, and
`scripts/preflight.sh` verifies all of it. What remains is the part
that needs your Apple developer account. Work through this top to
bottom; each step says *where* and *what*.

## 0. Before you open Xcode

```bash
brew install xcodegen xcbeautify
scripts/preflight.sh          # static checks + Release build + full test run
```

`preflight.sh --no-build` is what CI runs; the full script needs Xcode.

## 1. Apple Developer → Identifiers

Bundle ID: `com.turtleflight.app` (from `project.yml`). Enable these
capabilities on the App ID:

| Capability | Why | Code |
|---|---|---|
| Game Center | Opt-in leaderboards / achievements | `GameCenterManager` |
| iCloud → Key-Value storage | Opt-in progress sync | `CloudSync` |

Both are entitlements in `project.yml`; Xcode's automatic signing
will match them once the App ID has the capabilities.

## 2. Xcode signing

`project.yml` leaves `DEVELOPMENT_TEAM` empty on purpose. After
`xcodegen generate`, set your team once in Xcode (Signing &
Capabilities) — or export `DEVELOPMENT_TEAM=XXXXXXXXXX` and add it to
`project.yml` under `settings.base` for a reproducible CI archive.

## 3. App Store Connect → App record

| Field | Value |
|---|---|
| Name | Turtle Flight |
| Primary language | English (development region) — add ko, ja, zh-Hans, es, fr, de |
| Bundle ID | `com.turtleflight.app` |
| SKU | `turtleflight-ios` |
| Category | Games → Simulation (secondary: Family) |
| Age rating | 4+ (current questionnaire; answer "No" / "None" to every item) |
| Price | Free, no IAP |
| Availability | **United States only** (Pricing and Availability → deselect all, select United States) |
| Version release | **Automatically release this version** (goes live as soon as review approves) |
| Privacy Policy URL | `https://github.com/Denny-Hwang/Turtle_Flight/blob/main/PRIVACY.md` (same URL as Settings → Privacy) |
| Support URL | `https://github.com/Denny-Hwang/Turtle_Flight/issues` (same as Settings → Support) |

Owner decisions 2026-11-19: US storefront only, automatic release after
approval. The separate `Turtle-Flight-privacy` GitHub Pages site predates
Game Center / iCloud / clips and is **not** the policy URL; use the
`PRIVACY.md` link above so the store and the app point at one document.

Marketing copy for all seven locales is in `docs/store/<locale>.md`
(name, subtitle, promotional text, description, keywords, what's new).

### Game Center (Features → Game Center)

Create these with the **exact** IDs — the app submits to them by
string and silently logs an error otherwise.

Leaderboards (classic, high score, integer, best score):

| ID | Title | Sort |
|---|---|---|
| `tf.campaign.stars` | Campaign Stars | High to low |
| `tf.daily.score` | Today's Course | High to low |
| `tf.endless.score` | Sky Run | High to low |

Achievements (100 points each, hidden = no):

| ID | Title | Unlock |
|---|---|---|
| `tf.ach.first_bullseye` | First Bullseye | First BULLSEYE judgement |
| `tf.ach.combo_10` | Ten in a Row | Combo x10 in one run |
| `tf.ach.endless_50` | Fifty Gates | 50 gates in Sky Run |
| `tf.ach.campaign_15` | Campaign Complete | 15 campaign stars |
| `tf.ach.streak_7` | One Week | 7-day play streak |

### App Privacy (nutrition labels)

With every opt-in **off** (the default) the app collects nothing.
Answer the questionnaire as:

- Data collection: **No, we do not collect data from this app.**

Game Center and iCloud, when the player enables them, are handled by
Apple's frameworks under Apple's privacy policy; the app itself stores
no account data. `PRIVACY.md` is the policy URL you enter (host it at
the URL in `SettingsView.privacyURL`, or update that constant).

### Export compliance

`ITSAppUsesNonExemptEncryption = false` is already in `Info.plist`, so
App Store Connect will not ask on each build.

## 4. Build & upload

1. Xcode → Product → Archive (scheme `TurtleFlight`, Any iOS Device).
2. Organizer → Distribute App → App Store Connect → Upload.
3. Check the archive size: target < 80 MB (SDD §5.4). The build has no
   bundled audio and 2D atlases only; expect well under that.

Version / build live in `TurtleFlight/Info.plist`
(`CFBundleShortVersionString` = 1.0, `CFBundleVersion` = 1). Bump the
build number for every upload.

## 5. TestFlight (recommended, 1 week)

Instruments passes still needed on real devices (see
`docs/VALIDATION_REPORT.md` §5.2): 60 FPS Time Profiler on iPhone 12,
Allocations < 250 MB over a 5-minute flight. The tuning knobs most
likely to move after real-hand feedback are all constants:

- Gate judgement thresholds: `GateScoring.bullseyeAccuracy` / `greatAccuracy`
- Energy model / stall: `Constants.Flight.energy*`, `stallSpeed`
- Boost gauge: `Constants.Flight.boostChargePerStar` / `boostRechargePerSecond`
- Endless ramp: `EndlessCourse.radius(at:)` / `spacing(at:)`
- Daily Run difficulty: `DailyRun.courseSpec(for:)` ranges

## 6. Review notes (paste into "Notes for Review")

> Tilt-to-fly game. Steering requires a physical device with a
> gyroscope; on Simulator or iPad without a gyro, drag on the screen to
> steer (touch fallback). No account, no purchases. Game Center, iCloud
> sync, daily reminder and clip recording are all off by default and can
> be enabled in Settings → "Game Center & Reminders". Landscape only.
> Settings → "Secret code" accepts free promotional codes we hand out on
> social media. Codes are never sold, are checked on the device, and
> everything a code gives (a trail colour, in-game stars, early access
> to the last route) can also be earned by simply playing. Stars and
> treats are earned in play only; there is nothing to buy.

If App Review still objects to the code field (guideline 3.1.1), set
`SecretCodes.isEnabled = false` and resubmit — nothing else depends on it.

## 7. Screenshots (iPhone 6.9" + iPad 13", landscape)

App Store Connect now needs only the largest size per device family and
scales it down for the rest:

| Slot | Landscape pixels | Capture on |
|---|---|---|
| iPhone 6.9" (required) | 2868 × 1320 (or 2796 × 1290) | iPhone 16/17 Pro Max simulator or device |
| iPhone 6.5" (only if no 6.9") | 2778 × 1284 or 2688 × 1242 | — |
| iPad 13" (required: the app runs on iPad) | 2752 × 2064 (or 2732 × 2048) | iPad Pro 13" simulator |

Screenshots are generated, not hand-captured:

```bash
scripts/screenshots/capture.sh     # ~6 min: iPhone 17 Pro Max + iPad Pro 13" simulators
python3 scripts/screenshots/compose.py
```

- `marketing/screenshots/<device>/` — raw captures (2868×1320 / 2752×2064),
  upload-ready as they are.
- `marketing/store/<device>/` — the same with a headline, sky backdrop and
  character stickers, same pixel size. **Upload these**, in file order.
- `marketing/promo/` — 1200×630 social card, 1080×1080 square, 1080×1920 story.

How: a Debug-only screenshot mode (`ScreenshotDirector`, compiled out of
Release) skips onboarding and lets an autopilot fly the real flight engine
through each ring's centre, so judgements, score, combo, the result screen,
quests and mastery on screen are genuinely produced by the game. The
capture script erases each simulator, pins the status bar to 9:41, and
paints out the Dynamic Island pill the Simulator draws (real-device
screenshots don't contain it). Store order: flight + BULLSEYE, characters,
Sky Run, result, Home, Stage Select. `marketing/` outputs are gitignored —
rerun the two commands after UI changes.

## 8. What is still not in the repo

- **Voice callout clips** (owner, ~5 minutes, < $0.01). See §9.
- Real BGM / SFX recordings remain optional: `AudioManager.assetURL`
  picks up `bgm_<theme>` / `vehicle_<name>` / `sfx_<event>`
  (m4a/caf/wav/mp3) automatically; the synthesised fallback ships
  otherwise. (Google's only music generator, Lyria, is a Generative AI
  Service and is off-limits for a 4+ app — same rule as the voices.)
- Swift 6 strict-concurrency mode (not required for submission).

## 9. Voice callouts (Google Cloud Text-to-Speech)

Nine short English callouts ("Ready... fly!", "Bullseye!", "Great!",
combo 5/10/20, "Boost!", "Nice flying!", "So close! Try again!") play
over the synthesised SFX. The app ships and works without them (each
missing clip is silent); `scripts/preflight.sh` lists which are missing.

Voice: `en-US-Neural2-F`, rate 1.08, pitch +2 (`scripts/audio/voice-lines.json`).
Only Neural2/WaveNet voices are allowed: Chirp, Journey, Studio and
Gemini voices are Generative AI Services, which Google's Service
Specific Terms bar from services likely used by under-18s. The script,
the tests and preflight all refuse them.

Run in **your own terminal, not Claude Code** (the script refuses inside
Claude Code / CI so credentials never touch an agent shell):

```bash
# once: a Google Cloud project with "Cloud Text-to-Speech API" enabled and billing on
gcloud auth application-default login
cd ~/workspace/Turtle_Flight
scripts/audio/generate_voice.sh --dry-run                    # 9 lines, ~119 characters
scripts/audio/generate_voice.sh --project <your-gcp-project-id>
gcloud auth application-default revoke                       # done with credentials
```

Clips land in `TurtleFlight/Resources/Audio/voice_<key>.m4a` (AAC 64 kbps
mono, ~10 KB each, silence trimmed when ffmpeg is present). Then
`xcodegen generate`, run on a device, and listen: Settings → Audio →
"Announcer voice" toggles them; they follow Mute and the SFX slider and
stay silent under VoiceOver. To audition another voice:
`--voice en-US-Neural2-H --only bullseye,great`, then put the keeper in
the manifest and regenerate all lines. Commit the `.m4a` files.
