# Turtle Flight — Privacy Policy

**Effective date:** 2026-05-18
**Applies to:** Turtle Flight iOS app (CFBundleShortVersionString 1.0+)

> [한국어 버전은 아래로 스크롤하세요 ↓](#turtle-flight--개인정보-처리방침)

---

## Plain-language summary

Turtle Flight is a single-player tilt-controlled flying game for iPhone
and iPad. **It collects nothing about you and sends nothing off-device.**
The only data the app stores is your in-app progress (selected character,
star totals, stage results, audio preferences) and that data lives in the
sandboxed `UserDefaults` on your own device. There is no account, no
sign-in, no analytics SDK, no advertising SDK, no crash-reporting third
party, and no network call of any kind originated by the app.

If you tap **Settings → Progress → Reset Progress**, every byte the app
has ever written about your play session is deleted from your device.
Deleting the app from your home screen achieves the same result.

---

## What we collect

Nothing leaves your device. Inside the device-local sandbox the app
writes the following keys to `UserDefaults`:

| Key | What it stores | Why |
|-----|----------------|-----|
| `playerProgress` | Per-stage star scores, best times, total flight time, total stars, unlocked-stage index, currently selected character / vehicle / map theme, currently selected trail cosmetic tier. | So your progress survives between launches and you don't have to redo Stage 1 every time. |
| `sensitivityLevel` | Your tilt sensitivity choice (`easy` / `normal` / `expert`). | So we honor your control preference each session. |
| `audio.muted`, `audio.bgmVolume`, `audio.sfxVolume` | Audio toggles. | So music / SFX settings persist. |
| `onboardingCompleted` | Whether you've already seen the four-card first-run tutorial. | So we don't pester you with the tutorial on every launch. |

That's the entire on-device storage footprint. None of it is uploaded.

## Apple frameworks the app uses

The `PrivacyInfo.xcprivacy` manifest in the binary declares every system
API category Apple's 2024+ App Review checks for, along with the
Apple-approved reason code:

| API category | Reason code | What we use it for |
|--------------|-------------|--------------------|
| `UserDefaults` | `CA92.1` | Persisting the keys above. |
| `SystemBootTime` | `35F9.1` | `CACurrentMediaTime()` calls inside the animation / cooldown timers. |
| `DiskSpace` | `E174.1` | None directly; declared because SceneKit / AVFoundation may query it. |
| `FileTimestamp` | `C617.1` | None directly; declared because `Foundation` may query it during bundle resource loading. |

We use **CoreMotion** to read gyroscope attitude (`NSMotionUsageDescription`
in the Info.plist explains this to the user on first launch). Motion
samples are processed locally inside the app and are never persisted to
disk, never transmitted, and never shared with any third party.

We use **AVFoundation** to play synthesised audio (no microphone access,
no audio recording). The privacy manifest does not require declaration
for audio playback.

## What we do not do

- No advertising, no ad SDK, no IDFA / SKAdNetwork beyond what the App
  Store binary signs by default (none are read by the app code).
- No analytics, no crash reporting beyond Apple's first-party
  **MetricKit** (`MXMetricManager`) and Apple's first-party crash logs.
  MetricKit reports are gated on iOS's system-wide "Share with App
  Developers" preference and Apple delivers them to the developer; the
  app does not transmit them itself.
- No login, no account, no Game Center sign-in.
- No network calls. The app has no `URLSession` configuration and the
  binary makes no outbound HTTPS request.
- No microphone, no camera, no location, no contacts, no photos, no
  HealthKit, no HomeKit.
- No data shared with third parties, because there is no data to share.

## Children's privacy

Turtle Flight is rated **4+** in the App Store and is designed to be
playable by young children. Because the app collects no personal
information and makes no network call, it complies with COPPA
(Children's Online Privacy Protection Act) and the EU GDPR's child-data
provisions by virtue of never having children's data to handle in the
first place.

There is no chat, no UGC, no public profile, and no way for a child
playing this app to be contacted by another user.

## Your controls

- **Reset all data:** *Settings → Progress → Reset Progress* inside the
  app, or delete the app from the home screen.
- **Mute the app:** *Settings → Audio → Mute* inside the app, or the
  speaker chip on the home screen.
- **Disable MetricKit reports to the developer:** *iOS Settings →
  Privacy & Security → Analytics & Improvements → Share with App
  Developers* on your device.

## Changes to this policy

If a future version of the app starts collecting any data, this document
will be updated and the change will be called out in `CHANGELOG.md`.

## Contact

For privacy questions, open an issue at:
**https://github.com/Denny-Hwang/Turtle_Flight/issues**

---

# Turtle Flight — 개인정보 처리방침

**발효일:** 2026-05-18
**적용 대상:** Turtle Flight iOS 앱 (CFBundleShortVersionString 1.0+)

## 한 줄 요약

Turtle Flight는 1인용 자이로 비행 게임입니다. **수집하는 정보가 없고, 기기 밖으로 보내는 정보도 없습니다.** 앱이 저장하는 유일한 데이터는 게임 진행 상태(선택한 캐릭터, 별 점수, 스테이지 결과, 오디오 설정)뿐이며 이 데이터는 사용자 기기의 샌드박스 `UserDefaults`에만 저장됩니다. 계정도 없고, 로그인도 없고, 광고 SDK도 없고, 분석 SDK도 없고, 외부 크래시 리포팅도 없고, 앱이 만드는 네트워크 요청은 단 하나도 없습니다.

*설정 → 진행 상황 → 진행 기록 초기화* 를 누르면 앱이 작성한 모든 데이터가 기기에서 삭제됩니다. 홈 화면에서 앱을 삭제해도 동일한 효과가 있습니다.

## 수집하는 정보

기기를 떠나는 정보는 없습니다. 기기 내부 샌드박스에서 앱은 다음 `UserDefaults` 키를 기록합니다:

| 키 | 저장 내용 | 이유 |
|----|----------|------|
| `playerProgress` | 스테이지별 별 점수, 최고 기록 시간, 총 비행 시간, 총 별, 잠금 해제 스테이지, 현재 선택한 캐릭터/탈것/맵 테마, 트레일 색상 단계. | 매번 Stage 1부터 다시 시작하지 않도록 진행 기록을 유지합니다. |
| `sensitivityLevel` | 자이로 민감도 선택값 (`easy`/`normal`/`expert`). | 다음 세션에서 조작 선호도를 유지합니다. |
| `audio.muted`, `audio.bgmVolume`, `audio.sfxVolume` | 오디오 설정. | 사운드 설정을 유지합니다. |
| `onboardingCompleted` | 첫 실행 튜토리얼 완료 여부. | 매 실행마다 튜토리얼을 다시 보여주지 않습니다. |

이게 기기 내 저장의 전부입니다. 어떤 것도 업로드되지 않습니다.

## 앱이 사용하는 Apple 프레임워크

바이너리의 `PrivacyInfo.xcprivacy` 매니페스트가 Apple App Review가 검사하는 모든 시스템 API 카테고리와 승인된 사유 코드를 선언합니다:

| API 카테고리 | 사유 코드 | 사용 목적 |
|-------------|----------|----------|
| `UserDefaults` | `CA92.1` | 위 키 저장 |
| `SystemBootTime` | `35F9.1` | 애니메이션/쿨다운 타이머 내부의 `CACurrentMediaTime()` |
| `DiskSpace` | `E174.1` | 직접 사용하지 않으나 SceneKit/AVFoundation이 조회할 수 있음 |
| `FileTimestamp` | `C617.1` | 직접 사용하지 않으나 Foundation이 번들 리소스 로딩 중 조회할 수 있음 |

자이로 자세값을 읽기 위해 **CoreMotion**을 사용합니다 (Info.plist의 `NSMotionUsageDescription`이 첫 실행 시 사용자에게 안내). 모션 샘플은 앱 내부에서 즉시 처리되며 디스크에 저장되지 않고, 외부 전송되지 않고, 어떤 제3자와도 공유되지 않습니다.

합성 오디오 재생을 위해 **AVFoundation**을 사용합니다 (마이크 접근 없음, 녹음 없음).

## 하지 않는 것

- 광고 없음. 광고 SDK 없음.
- 분석 없음. Apple 1차 **MetricKit** 외 외부 크래시 리포팅 없음. MetricKit 리포트는 iOS 시스템 설정의 "앱 개발자와 공유" 설정에 따라 Apple이 직접 개발자에게 전달합니다 (앱이 직접 보내지 않음).
- 로그인 없음. 계정 없음. Game Center 사인인 없음.
- 네트워크 호출 없음. 앱에 `URLSession` 설정이 없으며 바이너리는 어떤 outbound HTTPS 요청도 만들지 않습니다.
- 마이크/카메라/위치/연락처/사진/HealthKit/HomeKit 접근 없음.
- 제3자와의 데이터 공유 없음 — 공유할 데이터 자체가 없습니다.

## 어린이 개인정보

Turtle Flight는 App Store에서 **4+** 등급으로 어린 아동도 플레이하도록 설계되었습니다. 개인정보를 수집하지 않고 네트워크 호출을 만들지 않기 때문에 미국 COPPA 및 EU GDPR의 아동 데이터 조항을 자연스럽게 준수합니다 — 처리할 아동 데이터 자체가 없기 때문입니다.

채팅, UGC, 공개 프로필이 없으며, 이 앱을 플레이하는 어린이가 다른 사용자에게 연락받을 방법이 없습니다.

## 사용자 통제

- **모든 데이터 삭제:** 앱 내 *설정 → 진행 상황 → 진행 기록 초기화* 또는 홈 화면에서 앱 삭제.
- **음소거:** 앱 내 *설정 → 사운드 → 음소거* 또는 홈 화면 스피커 칩.
- **MetricKit 리포트 비활성화:** iOS *설정 → 개인정보 보호 및 보안 → 분석 및 향상 → 앱 개발자와 공유*.

## 정책 변경

향후 버전에서 데이터 수집이 시작되면 본 문서가 업데이트되고 변경 사항은 `CHANGELOG.md`에 명시됩니다.

## 문의

개인정보 관련 문의는 다음 주소로 이슈를 열어주세요:
**https://github.com/Denny-Hwang/Turtle_Flight/issues**
