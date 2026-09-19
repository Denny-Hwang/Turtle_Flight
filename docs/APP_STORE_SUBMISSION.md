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
| Age rating | 4+ (no objectionable content; answer "No" to all) |
| Price | Free, no IAP |

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

## 7. Screenshots (6.7", 6.5", 5.5", iPad 12.9")

Capture in this order — each one shows a hook, not a menu:

1. Free flight with a BULLSEYE callout mid-screen.
2. Sky Race with a tilted slit gate and the combo chip visible.
3. Home: Fly now + Today's Course + Sky Run + quest strip.
4. Result screen with score, best combo, "New Best!".
5. Character select with mastery badges.
6. Settings → Game Center & Reminders (shows the opt-in posture).

## 8. What is still not in the repo

- Real audio recordings. `AudioManager.assetURL` picks up
  `bgm_<theme>` / `vehicle_<name>` / `sfx_<event>` (m4a/caf/wav/mp3)
  automatically; the synthesised fallback ships otherwise.
- The privacy policy must be reachable at a public URL.
- Swift 6 strict-concurrency mode (not required for submission).
