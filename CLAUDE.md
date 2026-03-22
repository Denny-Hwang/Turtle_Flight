# TurtleFlight - Claude Code Instructions

## Project Overview
"날 수 없는 동물들의 하늘 모험" — 자이로 기반 캐릭터 비행 어드벤처. 6종 캐릭터가 직접/탈것으로 하늘을 날아다니는 iOS 앱.

## Key Documents
- `docs/SDD.md` — SW 개발 문서

## Tech Stack
Swift 5.9+, SwiftUI+UIKit, SceneKit, CoreMotion, AVFoundation. iOS 16.0+, Landscape only.

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
