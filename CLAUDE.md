# TurtleFlight - Claude Code Instructions

## Project Overview
"날 수 없는 동물들의 하늘 모험" — 자이로 기반 캐릭터 비행 어드벤처. 6종 캐릭터가 직접/탈것으로 하늘을 날아다니는 iOS 앱.

## Key Documents
- `docs/SDD.md` — SW 개발 문서
- `docs/VALIDATION_REPORT.md` — 출시 전 검증 보고서 (네이티브 Swift 기준, 109개 테스트, 6 critical 버그 수정 완료)

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
- 다국어 리소스: RN쪽 i18next에 ko/en/ja/zh/es/fr/de/ar/hi/pt 10개 로케일 JSON이 있었음. 네이티브에서는 `Localizable.strings` (per-locale `.lproj/`) 로 다시 구축. v1은 ko/en만으로 출시. v1.x 로케일 추가 절차는 `docs/I18N.md` 참조.

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
PR마다 169 XCTest를 실행합니다. 자세한 절차는 `README.md` Getting
Started / Tooling / CI 섹션 참조.

## v1.1 backlog (Sprint 4 senior review에서 의도적으로 미룬 항목)
- **Daily Challenge 모드**: 기존 5 스테이지 + modifier ("no-boost", "≥5★", "<55s"). 15★ campaign cap과 50★ retention tier 사이 격차 해소
- **링 plane-intersection 충돌**: 현재 sphere-distance 가 측면 fall-through 허용. `prevPlayerPosition` 트래킹 필요
- **CharacterRegistry primitive geometry 600+ LOC 제거**: atlas billboard가 default이므로 dead weight. 실기기 fallback 검증 후 삭제
- **Free Flight soft goal**: 일일 별 목표 / personal best banner. "비행은 하는데 목적이 없다" 해결
