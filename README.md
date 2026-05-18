# TurtleFlight

**Tilt your phone. Fly a turtle.** A gyroscope-controlled flying game where six animals that have no business being in the sky take to it anyway — strapped into custom vehicles, one to each species. Built native iOS for the lowest possible input latency, because the whole game lives in the ~2ms gap between your wrist and the screen.

> [한국어 README는 아래로 스크롤하세요 ↓](#터틀-플라이트-한국어)

## Why TurtleFlight

- **The mechanic is the whole game.** CoreMotion sampled at 60 Hz, sub-3ms input-to-camera latency, three discrete sensitivity profiles (Easy → Expert) so a four-year-old and a teenager both find a setting that feels right.
- **Six characters, six handling signatures.** The jets are sharp, the balloons are floaty, the hamster ball turns on a dime. Same physics core, different multipliers — pick the one whose feel matches the stage.
- **Mission mode that actually ramps.** Five stages from "tap-the-rings" to a 20-ring sky-race with branching three-star paths, tuned against an Apple-senior-grade gameplay review.
- **Built for the App Store launch.** Privacy manifest, VoiceOver across the HUD, Reduce Motion, Dynamic Type on modal copy, Korean + English at parity, gracefully degrades when the gyro isn't available (Simulator, iPad mini without one).

## Characters

| Character | Name | Unique Vehicle | Description |
|-----------|------|---------------|-------------|
| Turbo | Turtle | Shell Jet | A jet-powered shell strapped to his back |
| Pip | Penguin | Belly Glider | Glides on his belly through the sky |
| Nutty | Hamster | Hamster Ball Copter | A hamster ball turned helicopter |
| Mochi | Cat | Magic Broom | Rides a magical broomstick |
| Bounce | Frog | Balloon Body | Inflates like a balloon to fly |
| Hoppy | Bunny | Ear Copter | Ears spin like helicopter blades |

All characters also share the **Cloud Surf** — a cloud-riding vehicle available to everyone.

## Flight Modes

- **Free Flight** — Unlimited open-sky exploration with a flight timer (MM:SS)
- **Step Goal** — Complete 5 stages of missions and earn up to 3 stars per stage

## Controls

TurtleFlight uses your device's gyroscope for intuitive tilt-based controls with three sensitivity levels:

| Level | Dead Zone | Curve | Smoothing | Auto-Level |
|-------|-----------|-------|-----------|------------|
| Easy | 8° | Cubic (x³) | 0.08 | 2s |
| Normal | 4° | Quadratic (x²) | 0.15 | 4s |
| Expert | 1.5° | Linear (x) | 0.35 | Stall enabled |

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI + UIKit
- **3D Engine:** SceneKit
- **Motion:** CoreMotion (gyroscope)
- **Audio:** AVFoundation
- **Platform:** iOS 16.0+, Landscape only

## Project Structure

```
TurtleFlight/
├── App/                    # App entry point
├── Core/
│   ├── Character/          # Character registry, animator, vehicle definitions
│   ├── Flight/             # Flight physics engine
│   ├── Gyro/               # Gyroscope controller & sensitivity profiles
│   ├── Item/               # Collectible item system
│   ├── Mission/            # Mission engine & stage definitions
│   └── Terrain/            # Procedural terrain generation
├── Models/                 # Data models (CharacterType, VehicleType, etc.)
├── ViewModels/             # Flight, Mission, Character view models
├── Views/
│   ├── Home/               # Home screen & character selection
│   ├── Flight/             # Main flight view
│   ├── HUD/                # HUD overlay & mission HUD
│   └── Controls/           # On-screen control buttons
├── Utils/                  # Constants, extensions, math helpers
└── Resources/
    ├── ko.lproj/           # Korean Localizable.strings
    └── en.lproj/           # English Localizable.strings
Tests/                      # XCTest suites for core systems (109+ cases)
docs/
├── SDD.md                  # Software Development Document
└── VALIDATION_REPORT.md    # Pre-submission validation report
```

## Requirements

- iOS 16.0 or later
- iPhone with gyroscope (iPhone 12+ recommended)
- Xcode 15.0+

## Performance Targets

- 60 FPS on iPhone 12+
- < 250 MB memory usage
- < 80 MB app size

## Getting Started

The project file is generated from `project.yml` via **[XcodeGen](https://github.com/yonsm/XcodeGen)**.
The generated `TurtleFlight.xcodeproj` is intentionally **not** committed
so contributors can't drift settings — regenerate it locally.

```bash
# One-time setup
brew install xcodegen

# From the repo root, every time project.yml changes
xcodegen generate

# Open the freshly-generated project in Xcode
open TurtleFlight.xcodeproj
```

The generated project sets Deployment Target = iOS 16.0, Devices =
iPhone + iPad, Orientation = Landscape only, and propagates the
required device capabilities, Info.plist path, asset catalog,
PrivacyInfo manifest, and the `TurtleFlightTests` unit-test target
automatically. Hit `⌘R` to build and run.

> **Note:** Gyroscope controls require a physical device. On Simulator /
> iPad-without-gyro, drag on the scene view to steer (touch-fallback).

## Tooling

| Tool | Purpose | Install |
|------|---------|---------|
| XcodeGen | Reproducible `.xcodeproj` from `project.yml` | `brew install xcodegen` |
| xcpretty | Pretty xcodebuild logs (used by CI) | `gem install xcpretty` |
| librsvg + ImageMagick | Regenerate raster icons from SVG (`scripts/build_assets.sh`) | `brew install librsvg imagemagick` |

## Continuous Integration

GitHub Actions (`.github/workflows/ios-tests.yml`) runs the full
XCTest suite on every PR and push to `main` against the latest iOS
simulator on macOS 14. The same `xcodegen generate` step the README
recommends is the first thing CI does, so a working PR is one that
builds from a clean checkout with no human-in-the-loop project file.

## Localization

Korean (`ko`) and English (`en`) are bundled. Strings live in
`TurtleFlight/Resources/<locale>.lproj/Localizable.strings`. The development
region is `en` and Korean is the primary marketing locale for v1.

## Documentation

- [`docs/SDD.md`](docs/SDD.md) — Software Development Document (architecture, roadmap, technical spec)
- [`docs/VALIDATION_REPORT.md`](docs/VALIDATION_REPORT.md) — Pre-submission validation report (109+ XCTest cases, bug fixes)

## License

This project is licensed under the BSD 3-Clause License. See [LICENSE](LICENSE) for details.

---

# 터틀 플라이트 (한국어)

**날 수 없는 동물들의 하늘 모험** — 자이로 기반 캐릭터 비행 어드벤처 iOS 앱.

비행기가 아닌 6종 동물 캐릭터가 직접(또는 고유 탈것으로) 하늘을 날아다니는 기울기 조작 게임입니다.

## 캐릭터

| 캐릭터 | 이름 | 고유 탈것 | 설명 |
|--------|------|-----------|------|
| Turbo  | 거북이 🐢 | Shell Jet (등껍질 제트) | 등껍질에 제트 엔진 장착 |
| Pip    | 펭귄 🐧 | Belly Glider (배 활공) | 배로 미끄러지며 활공 |
| Nutty  | 햄스터 🐹 | Hamster Ball Copter (햄스터볼 헬리콥터) | 햄스터볼이 회전하며 비행 |
| Mochi  | 고양이 🐱 | Magic Broom (마법 빗자루) | 마법 빗자루를 타고 비행 |
| Bounce | 개구리 🐸 | Balloon Body (풍선 비행) | 몸이 풍선이 되어 두둥실 |
| Hoppy  | 토끼 🐰 | Ear Copter (귀 헬리콥터) | 귀가 프로펠러처럼 회전 |

모든 캐릭터는 **Cloud Surf (구름 서핑)** 공통 탈것도 사용 가능합니다.

## 비행 모드

- **자유 비행 (Free Flight)** — 무제한 자유 비행, MM:SS 비행 시간 표시
- **스텝 골 (Step Goal)** — 5단계 미션 클리어, 스테이지당 최대 ⭐ 3개

## 조종

기기를 기울여 조종합니다. 3단계 민감도를 지원합니다.

| 단계 | 데드존 | 응답 곡선 | 스무딩 α | 자동 수평화 |
|------|--------|-----------|----------|-------------|
| 쉬움 (Easy) | 8° | 3차 (x³) | 0.08 | 2초 |
| 보통 (Normal) | 4° | 2차 (x²) | 0.15 | 4초 |
| 전문가 (Expert) | 1.5° | 선형 (x) | 0.35 | 실속 있음 |

## 기술 스택

- **언어:** Swift 5.9+
- **UI:** SwiftUI + UIKit
- **3D 엔진:** SceneKit
- **모션:** CoreMotion (자이로스코프)
- **오디오:** AVFoundation
- **플랫폼:** iOS 16.0+, 가로 모드 전용

## 요구 사항

- iOS 16.0 이상
- 자이로 센서가 있는 iPhone (iPhone 12 이상 권장)
- Xcode 15.0+

## 성능 목표

- iPhone 12 이상에서 60 FPS
- 메모리 < 250 MB
- 앱 크기 < 80 MB

## 시작하기

프로젝트 파일은 `project.yml` 로부터 **[XcodeGen](https://github.com/yonsm/XcodeGen)**
이 생성합니다. `TurtleFlight.xcodeproj`는 의도적으로 커밋되지 않습니다
— 각자 로컬에서 생성해 설정 드리프트를 막습니다.

```bash
# 최초 1회
brew install xcodegen

# 저장소 루트에서, project.yml이 바뀔 때마다
xcodegen generate

# Xcode로 열기
open TurtleFlight.xcodeproj
```

Deployment Target = iOS 16.0, Devices = iPhone + iPad,
Orientation = Landscape only, Required device capabilities, Info.plist,
Asset catalog, PrivacyInfo 매니페스트, `TurtleFlightTests` 유닛 테스트
타깃이 자동 설정됩니다. ⌘R로 빌드/실행.

> 자이로 조작은 실기기에서만 동작합니다. 시뮬레이터/자이로 없는 iPad에서는
> 화면을 손가락으로 드래그하여 조종합니다 (touch-fallback).

## 도구 (Tooling)

| 도구 | 용도 | 설치 |
|------|------|------|
| XcodeGen | `project.yml` 에서 재현 가능한 `.xcodeproj` 생성 | `brew install xcodegen` |
| xcpretty | xcodebuild 로그 가독성 (CI 사용) | `gem install xcpretty` |
| librsvg + ImageMagick | SVG → 래스터 아이콘 재생성 (`scripts/build_assets.sh`) | `brew install librsvg imagemagick` |

## CI

GitHub Actions(`.github/workflows/ios-tests.yml`)가 main 푸시와 모든 PR에
대해 macOS 14 + 최신 iOS 시뮬레이터에서 전체 XCTest 스위트를 실행합니다.
CI 첫 단계가 `xcodegen generate` 이므로 깔끔한 체크아웃에서 사람 손을
거치지 않고 빌드되는 PR만 통과합니다.

## 다국어

한국어(`ko`), 영어(`en`)가 번들에 포함됩니다. 문자열은 `TurtleFlight/Resources/<로케일>.lproj/Localizable.strings` 에 있으며, 개발 리전은 `en`, v1 주요 마켓 로케일은 `ko` 입니다.

## 접근성

- **모션 줄이기 (Reduce Motion)** — 시스템 설정이 켜져 있으면 자이로 민감도가 자동으로 *쉬움*으로 클램프됩니다(저장된 사용자 선호값은 유지). 토글 시 즉시 반영.
- **VoiceOver** — 비행 컨트롤(부스터·아이템·보정·종료)과 홈 화면 버튼에 한국어/영어 라벨·힌트 제공.

## 문서

- [`docs/SDD.md`](docs/SDD.md) — 소프트웨어 개발 문서 (아키텍처, 로드맵, 기술 스펙)
- [`docs/VALIDATION_REPORT.md`](docs/VALIDATION_REPORT.md) — 출시 전 검증 보고서 (XCTest 109+ 케이스, 버그 수정 내역)

## 라이선스

본 프로젝트는 BSD 3-Clause 라이선스로 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 를 참고하세요.
