# TurtleFlight - Claude Code Instructions

## Project Overview
"날 수 없는 동물들의 하늘 모험" — 자이로 기반 캐릭터 비행 어드벤처. 6종 캐릭터가 직접/탈것으로 하늘을 날아다니는 iOS 앱.

## Key Documents
- `docs/SDD.md` — SW 개발 문서
- `docs/VALIDATION_REPORT.md` — 출시 전 검증 보고서 (historical snapshot; 현재 테스트 460+)
- `docs/APP_STORE_SUBMISSION.md` — 앱스토어 제출 체크리스트 (계정에서 해야 할 일, Game Center ID, 프라이버시 라벨, 리뷰 노트). 마케팅 카피는 `docs/store/<locale>.md`

## Tech Stack — Native iOS only
Swift 5.9+, SwiftUI+UIKit, SceneKit, CoreMotion, AVFoundation. iOS 16.0+, Landscape only.

소스: `TurtleFlight/` (앱), `Tests/` (XCTest).

### React Native/Expo는 폐기됨 (DO NOT REINTRODUCE)
2026-03-27에 RN+Expo+Three.js 포팅 실험이 있었으나 다음 이유로 롤백됨. 같은 결정을 반복하지 말 것:
1. **입력 지연**: 자이로 비행 게임은 입력→화면 latency가 핵심 UX. CoreMotion(~2ms) vs expo-sensors+JS bridge(~30–80ms) 차이가 게임필을 망침.
2. **번들/메모리 예산**: SDD 목표 < 80MB 앱 / < 250MB RAM. RN 런타임 + Hermes + Three.js 조합으로는 거의 불가.
3. **완성도 ROI**: 네이티브가 이미 80% 완성 (검증 보고서 참조). RN은 골격만 있었음.
4. **iOS-only 스펙**: 크로스플랫폼 가치가 없음. RN의 가장 큰 장점이 무력화됨.
5. **하드웨어 통합**: CoreHaptics, GameController(MFi), AVAudioEngine 샘플 정확 동기, Metal 셰이더는 모두 결국 네이티브 모듈을 요구.

RN 실험 코드는 git tag `rn-experiment-20260327` 에 보존되어 있음 (커밋 `fdf250b`). 웹 데모 등 특수 목적이 생기면 그곳에서 참고.

## Core Concept — NOT airplanes
- 비행기가 아님. 캐릭터(동물)가 직접 화면 중앙에서 날아다님.
- 6종 캐릭터: 거북이, 펭귄, 햄스터, 고양이, 개구리, 토끼
- 각 캐릭터는 고유 탈것 1종 + 공통 Cloud Surf 1종
- MVP에서는 비행 물리 동일, 시각/애니메이션/사운드만 차별화

## 6 Characters (all free)
1. 🐢 Turbo (turtle) — Shell Jet (등껍질 제트)
2. 🐧 Pip (penguin) — Belly Glider (배 활공)
3. 🐹 Nutty (hamster) — Hamster Ball Copter
4. 🐱 Mochi (cat) — Magic Broom (마법 빗자루)
5. 🐸 Bounce (frog) — Balloon Body (풍선 비행)
6. 🐰 Hoppy (bunny) — Ear Copter (귀 헬리콥터)
+ ☁️ Cloud Surf (공통 탈것)

## Two Flight Modes
1. Free Flight — 무제한 자유 비행, MM:SS 비행시간 표시
2. Step Goal — 5단계 미션, ⭐ 3단계 평가

## 3-Level Sensitivity
- Lv.1 Easy: Dead zone 8°, Cubic(x³), α=0.08, Auto-Level 2초
- Lv.2 Normal: Dead zone 4°, Quadratic(x²), α=0.15, Auto-Level 4초
- Lv.3 Expert: Dead zone 1.5°, Linear(x), α=0.35, 실속 있음

## Camera — CRITICAL
캐릭터+탈것이 항상 화면 중앙. 3인칭 뒤쪽 상단 카메라. 선회 시 뱅킹 효과. Lerp 추종.

## Performance
60 FPS on iPhone 12+, < 250MB memory, < 80MB app size.

## Open follow-ups (RN 폐기로 인한 손실분)
- 다국어 리소스: 네이티브 `Localizable.strings` (per-locale `.lproj/`)로 재구축 완료. **번들 7개 로케일 — ko/en/ja/zh-Hans/es/fr/de — 모두 407키 패리티** (`Tests/LocalizationParityTests.swift`가 강제). 남은 것은 App Store Connect 마케팅 카피(설명/키워드/스크린샷)로, 번들 문자열과 별개. 로케일 추가 절차는 `docs/I18N.md` 참조.
- ⚠️ XcodeGen 주의: `project.yml` 의 `Resources` 는 `type: folder` 금지 — `.lproj` 가 `Resources/` 하위로 중첩되면 `NSLocalizedString` 이 못 찾음. 일반 그룹 참조로 두어 변형 그룹이 번들 루트에 위치하게 함.

## Sprint 0–4 closure
출시 차단급 P0 + 주요 P1 + 선택된 P2 항목 정리. 전체 변경 로그는 `CHANGELOG.md` 참조.

| Sprint | 핵심 변경 |
|--------|----------|
| 0 (PR #43) | 미션 완료 wiring, 충돌 판정, dead code (~190 LOC) 제거, MapTheme/Stage L10n |
| 1 (PR #43) | HUD pulse, boost ring, 목표 화살표, 5/3/1초 비프, 별 재스폰, Stage 3 클리어런스, Stage 4 산 |
| 2 (PR #43) | SettingsView 신규, 오디오 볼륨 API, Reduce Motion 카메라 완화 |
| 3 (PR #43) | Simulator 자이로 폴백, Dynamic Type 토큰, iPad 1.4× 적응 사이즈, i18n 프로세스 문서 |
| 4 (this PR) | XcodeGen `project.yml`, GitHub Actions CI, `PRIVACY.md`, 부스터 카메라 임팩트, PauseView 인비행 sensitivity selector, AudioManager leak guard |

이전 보고서(`docs/VALIDATION_REPORT.md`, `docs/DESIGN_GAP_REPORT.md`, `docs/AUDIO_AUDIT.md`)는 historical snapshot으로 유지. 본 PR 시리즈로 닫힌 항목들은 각 보고서 끝의 closure log 섹션 참조.

## Build (Sprint 4 이후)
`TurtleFlight.xcodeproj` 는 커밋하지 않습니다 — `project.yml` 에서
재생성: `brew install xcodegen && xcodegen generate`. GitHub Actions가
PR마다 Debug 빌드 + 전체 XCTest(390+) + Release 빌드 + `scripts/preflight.sh
--no-build` 를 실행합니다. 업로드 전에는 `scripts/preflight.sh` (정적 검사 +
Release 빌드 + 테스트) 를 로컬에서 돌립니다. 자세한 절차는 `README.md` 와
`docs/APP_STORE_SUBMISSION.md` 참조.

## 2026-09 로드맵 (4 phase, 모두 머지됨)
| Phase | PR | 핵심 |
|---|---|---|
| 1 기반 수리 | #49 | CI 복구(Xcode/시뮬레이터 unpin), 빌드 깨짐 수정, 통계 저장 버그, 링 평면 교차 판정, 렌더 스레드 루프 + HUD 발행 병합, `CourseSpec`, on-device `Analytics` |
| 2 코어 재미 | #50 | BULLSEYE/GREAT/OK/MISS 판정 + 콤보, 축소/기울기/이동 게이트, 에너지 모델 + 실속, 부스트 게이지, 즉시 비행 |
| 3 리텐션 | #51 | 오늘의 코스(`DailyRun`), 스카이런(`EndlessCourse`), 퀘스트 + 연속 출석, 고스트, 옵트인 Game Center/알림 |
| 4 완성도 | #52 | 오디오 에셋 훅 + BGM 재작성, ReplayKit 클립, iCloud KVS 동기화, 캐릭터 숙련도, 문서 |
| 5 제출 준비 | #53 | CharacterRegistry 프리미티브 600 LOC 제거, 로케일별 `InfoPlist.strings`, Release 빌드 CI 게이트, `scripts/preflight.sh`, 제출 체크리스트 + 7개 로케일 마케팅 카피 |

**설계 원칙 (유지할 것)**
- 시뮬레이션은 SceneKit 렌더 스레드에서 돌고 `@Published` 는 main 에서만 쓴다 (`FlightViewModel` 상단 주석). 테스트는 main 에서 동기 호출.
- 새 저장 필드는 항상 `decodeIfPresent` (또는 `Optional` + 기본값) 로 추가해 구 블롭 호환.
- 새 문자열은 7개 로케일 전부에 추가 (`LocalizationParityTests` 가 강제).
- 링 통과 관련 테스트는 `MissionEngine.testPass(ringIndex:)` 로 2프레임 세그먼트를 날린다.
- 외부로 나가는 것(Game Center, 알림, iCloud, 녹화)은 전부 옵트인 + 기본 OFF, `PRIVACY.md` 에 기록.
- iPad 크기 대응은 `.deviceCanvas()` 한 가지로 (`Theme.swift` 의 `DeviceCanvas`). 새 전체화면 커스텀 화면은 배경(`ignoresSafeArea`)을 뺀 전경에만 적용하고, 개별 컨트롤에 iPad 배율을 따로 곱하지 말 것. 시스템 시트(설정·상점·앨범)와 SceneKit 뷰는 스케일하지 않는다.

## 월드 투어 (2026-11-20)
월드 7개(`MapTheme`: sky/desert/city/seoul/wild/space/ocean). 지형·색은 `WorldProfile` 데이터, 랜드마크 25개는 `LandmarkFactory` 가 SceneKit 기본 도형으로 생성(모델 파일 없음). **랜드마크는 실제 건축물 모델이 아니라 "명소풍" 오리지널 + 자체 이름** — 실존 명소를 그대로 재현하거나 실명으로 바꾸지 말 것(상표·저작권). 랜드마크/엽서/인사 비행은 자유 비행 전용. 새 월드·랜드마크 추가 시 `WorldTourTests` 가 이름·소속·빌드를 강제. 진행표와 남은 아이디어는 `docs/LAUNCH_POLISH_PLAN.md`.

## 루트 · Kids · 보상 · 햅틱 · 시크릿 코드 (2026-11-20)
설계와 진행표는 `docs/ROUTES_REWARDS_PLAN.md`. 캠페인은 루트 5개(`RouteCatalog`, 코스 21개)이고 기존 5개 스테이지는 Sky School 루트(index 0–4 유지). 루트 코스는 index 10/20/30/40 대역 + 고정 월드. 잠금 규칙은 `PlayerProgress.isCourseUnlocked` 한 곳. Kids 모드는 `StageDefinition.kidsVariant()` + `MissionEngine` 의 `isKids` 분기(실패 없음). 진동은 반드시 `Haptics.shared.play(_:)` 로 (직접 `UIImpactFeedbackGenerator` 쓰지 말 것). 화폐는 별 지갑(`starsBanked − starsSpent`)과 캐릭터별 간식(`treats`), 상품은 `Shop`. **시크릿 코드 원문은 절대 커밋하지 말 것** (저장소는 2026-11-20 에 private 으로 바뀌었지만 그 전 기록이 공개된 적이 있고, 다시 공개될 수도 있다) — `SecretCodes` 에는 솔트 해시만, 원문은 gitignore 된 `marketing/secret_codes.md`. 테스트도 대역 코드로만 검증.

## 비행 방향 · 하늘 추가 요소 · 오디오 · Swift 6 (2026-11-22)
- 비행 중 캐릭터는 **기본으로 앞(날아가는 쪽)을 본다** — 뒷모습 아틀라스 `<name>_back_atlas` / `<name>_cloud_back_atlas`. "나를 봐" 버튼(비행 컨트롤)과 설정 → 조작에서 앞모습으로 전환, `flight.lookAtMe` 에 저장. 뒷모습은 각 캐릭터 모듈의 `ride_back` / `fig_back` (생성기), 아틀라스 셀 순서는 앞모습과 동일.
- 자유 비행 전용: 랜드마크 충돌(`LandmarkKind.colliders`, 벌점 없는 튕김), 하늘의 신비(`SkyWonder`, 비행당 35%), 엽서 마일스톤(절반 5★ / 전부 10★ + 축제 `FestivalLayer`). 미션은 `startStage` 에서 모두 제거.
- 번들 오디오 `TurtleFlight/Audio/` 는 `bash scripts/audio/build_audio.sh` 로 재생성 (전부 합성, 샘플·생성형 모델 없음 → 에이전트/CI 에서 실행 가능). 파일이 없으면 기존 인앱 합성으로 폴백.
- 앱 타깃은 **Swift 6 언어 모드** (`project.yml`), 테스트 타깃은 Swift 5.9. 스레드를 넘는 타입은 `@unchecked Sendable` + 보호 방법(락/직렬 큐/메인 전용) 주석을 단다. 렌더 스레드에서 UI·햅틱·오디오는 `onMain` / `performOnMainActor` 로만.

## 남은 백로그 (저장소 밖 또는 선택 사항)
- **Apple 계정 작업**: App ID capability(Game Center, iCloud KVS), App Store Connect 리더보드/업적 생성, 프라이버시 정책 URL 호스팅 — 절차와 정확한 ID는 `docs/APP_STORE_SUBMISSION.md`
- **음성 콜아웃 클립 생성 (오너)**: `VoiceLine` 9종 + 재생 경로는 머지됨. Google Cloud TTS Neural2 (`en-US-Neural2-F`) 로 `scripts/audio/generate_voice.sh` 를 **오너 터미널에서** 실행 (Claude Code/CI 안에서는 거부, 에이전트는 `--dry-run` 만). 생성형 음성(Chirp/Journey/Studio/Gemini, Lyria 음악)은 4+ 앱이라 Google 약관상 금지. 절차는 `docs/APP_STORE_SUBMISSION.md` §9
- **오디오 귀 검수 (오너)**: 번들 오디오는 오프라인 합성으로 만들어 넣었지만 사람이 들어본 적이 없다. 실기기에서 월드별 BGM·루프 이음새·효과음 크기를 듣고, 바꿀 곳은 `scripts/audio/render_assets.swift` 의 `songs` / `sfx` 를 고쳐 재생성
- **출시 설정 (오너 결정 2026-11-19)**: 미국 스토어만, 심사 통과 후 자동 출시
- **실기기 튜닝**: TestFlight 후 `GateScoring`, `Constants.Flight.energy*`, `EndlessCourse.radius(at:)` 상수 조정
