# Turtle Flight — Software Development Document

Character Flight Adventure App "날 수 없는 동물들의 하늘 모험"
Platform: iOS (iPhone) · Strategy: MVP-First Rapid Release

| Field | Value |
|-------|-------|
| Version | 1.0 (MVP) |
| Date | 2026-03-21 |
| Author | Sungjoo |
| Status | DRAFT |

## Table of Contents
1. Executive Summary
2. System Architecture
3. Core Features Specification
4. UI/UX Design
5. Technical Implementation Details
6. Development Roadmap
7. App Store Submission
8. Testing Strategy
9. Risk Assessment
10. Claude Code 운영 가이드
11. Appendix

## 1. Executive Summary

### 1.1 Product Vision
Turtle Flight는 "날 수 없는 동물들이 하늘을 나는" 유쾌한 컨셉의 자이로 기반 비행 어드벤처 앱입니다. 플레이어는 거북이, 펭귄 등 개성 있는 캐릭터를 선택하고, 각자의 탈것(등껍질 제트, 빗자루, 풍선 등)을 골라 직접 하늘을 탐험합니다.

### 1.2 Core Identity
| 요소 | 설명 |
|------|------|
| 컨셉 | "날 수 없는 동물들의 하늘 모험" |
| 마스코트 | 🐢 거북이 (Turbo) |
| 핵심 차별점 | 비행기가 아닌 캐릭터가 직접 화면 중앙에서 날아다님 |
| 조종 방식 | 스마트폰 자이로 센서 |
| 비행 스타일 | 캐릭터별 직접 비행 또는 탈것 선택 가능 |

### 1.3 Target Users
- 주 타겟: 전 연령 (All Ages)
- 4세 아이도 Lv.1에서 조작 가능한 수준
- Category: Games > Simulation (전체 이용가)

### 1.4 MVP Strategy

| Feature | MVP (v1.0) | Full Version (v2.0+) |
|---------|-----------|---------------------|
| 캐릭터 | 6종 전부 무료 개방 | 추가 캐릭터 + 시즌 캐릭터 |
| 탈것/비행 스타일 | 캐릭터별 기본 1종 + 공통 1종 | 캐릭터별 3~5종, 커스터마이징 |
| 자이로 조종 | 좌/우/상/하 기본 조종 | 보정 필터 고도화 |
| 조종 민감도 | 3단계 (Easy / Normal / Expert) | 커스텀 슬라이더 |
| 비행 모드 | 자유 비행 + Step Goal (5단계) | 무한 스테이지, 일일 챌린지 |
| 지형 생성 | Procedural 기본 지형 | 실제 지형 데이터 (DEM) |
| HUD / 계기판 | 속도, 고도, 나침반, 비행시간 | 미니맵, 연료, 날씨 |

## 2. System Architecture

### 2.1 Technology Stack
| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI + UIKit hybrid |
| 3D Engine | SceneKit |
| Sensor | CoreMotion |
| Audio | AVFoundation |
| Persistence | UserDefaults + JSON |
| Min Target | iOS 16.0+ |
| Build | Xcode 15+ |

### 2.2 Architecture Pattern
MVVM (Model-View-ViewModel)

### 2.3 Project Structure
```
TurtleFlight/
├── App/
│   └── TurtleFlightApp.swift
├── Core/
│   ├── Flight/
│   │   └── FlightEngine.swift
│   ├── Gyro/
│   │   ├── GyroController.swift
│   │   └── SensitivityProfile.swift
│   ├── Character/
│   │   ├── CharacterRegistry.swift
│   │   ├── CharacterAnimator.swift
│   │   └── VehicleDefinitions.swift
│   ├── Terrain/
│   │   └── TerrainGenerator.swift
│   ├── Item/
│   │   └── ItemSystem.swift
│   └── Mission/
│       ├── MissionEngine.swift
│       └── StageDefinitions.swift
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── CharacterSelectView.swift
│   ├── Flight/
│   │   └── FlightView.swift
│   ├── HUD/
│   │   ├── HUDOverlay.swift
│   │   └── MissionHUD.swift
│   └── Controls/
│       └── ControlButtons.swift
├── ViewModels/
│   ├── FlightViewModel.swift
│   ├── CharacterViewModel.swift
│   └── MissionViewModel.swift
├── Models/
│   ├── CharacterType.swift
│   ├── VehicleType.swift
│   ├── FlightMode.swift
│   ├── SensitivityLevel.swift
│   └── StageResult.swift
├── Resources/
│   ├── Characters/
│   ├── Vehicles/
│   ├── Textures/
│   └── Sounds/
├── Utils/
│   ├── Extensions.swift
│   ├── Constants.swift
│   └── MathHelpers.swift
└── Tests/
```

### 2.4 Data Flow
```
[CoreMotion Sensor] → [GyroController] → Dead Zone → Low-pass Filter → Response Curve
→ [FlightViewModel] → [FlightEngine] → Position, Rotation, Speed
                    → [CharacterAnimator] → 캐릭터+탈것 자세/애니메이션
                    → [TerrainGenerator] → Chunk loading/unloading
                    → [ItemSystem] → Projectile + Star collection
                    → [MissionEngine] → Stage objectives check
→ [FlightView (SceneKit)] → 3D 렌더링
→ [HUDOverlay (SwiftUI)] → 속도/고도/비행시간
→ [MissionHUD (SwiftUI)] → 미션 목표
→ [ControlButtons (SwiftUI)] → 부스터 + 아이템 버튼
```

## 3. Core Features Specification

### 3.1 Character System

#### 3.1.1 MVP 6 Characters

| # | Character | 기본 비행 스타일 | 기본 탈것 | 성격/비주얼 |
|---|-----------|----------------|----------|------------|
| 1 | 🐢 거북이 Turbo | 등껍질이 제트로 변신 | Shell Jet | 앱 마스코트. 느리지만 꿋꿋한. 고글 착용 |
| 2 | 🐧 펭귄 Pip | 배로 미끄러지듯 활공 | Belly Glider | 통통하고 명랑. 스카프 휘날림 |
| 3 | 🐹 햄스터 Nutty | 햄스터볼이 프로펠러로 변환 | Hamster Ball Copter | 호기심 왕. 볼이 빵빵하게 부풀어 있음 |
| 4 | 🐱 고양이 Mochi | 마법 빗자루를 타고 비행 | Magic Broom | 도도하지만 무서움 많은. 마녀 모자 |
| 5 | 🐸 개구리 Bounce | 몸이 풍선처럼 부풀어 비행 | Balloon Body | 느긋한 성격. 볼이 부풀면 표정 변화 |
| 6 | 🐰 토끼 Hoppy | 귀를 프로펠러처럼 돌려 비행 | Ear Copter | 활발하고 용감한. 빨간 비행 고글+스카프 |

#### 3.1.2 캐릭터 + 탈것 선택 시스템

| 탈것 유형 | 캐릭터 | 비행 애니메이션 |
|----------|--------|---------------|
| Shell Jet | 🐢 Turbo | 등껍질에서 화염 분사 |
| Belly Glider | 🐧 Pip | 배로 미끄러지며 활공 |
| Hamster Ball Copter | 🐹 Nutty | 공이 회전하며 프로펠러 역할 |
| Magic Broom | 🐱 Mochi | 빗자루 위에 앉아 비행 |
| Balloon Body | 🐸 Bounce | 몸이 부풀어 떠오름 |
| Ear Copter | 🐰 Hoppy | 긴 귀가 프로펠러처럼 회전 |
| Cloud Surf | ALL | 구름 서핑보드에 서서 비행 |

### 3.2 Gyroscope Control System

#### 3.2.1 Input Mapping
| 동작 | 폰 움직임 | CoreMotion 축 |
|------|----------|--------------|
| 좌회전 | 폰을 왼쪽으로 기울임 | Roll (attitude.roll) |
| 우회전 | 폰을 오른쪽으로 기울임 | Roll (attitude.roll) |
| 상승 | 폰 윗부분을 들어올림 | Pitch (attitude.pitch) |
| 하강 | 폰 윗부분을 내림 | Pitch (attitude.pitch) |

#### 3.2.2 Sensitivity Profiles (3단계)

| Parameter | Lv.1 Easy | Lv.2 Normal | Lv.3 Expert |
|-----------|-----------|-------------|-------------|
| Dead Zone | ±8° | ±4° | ±1.5° |
| Max Tilt Angle | ±25° | ±35° | ±50° |
| Response Curve | Cubic (x³) | Quadratic (x²) | Linear (x) |
| Smoothing (α) | 0.08 | 0.15 | 0.35 |
| Turn Speed | 45°/s max | 90°/s max | 180°/s max |
| Pitch Speed | ±30 m/s max | ±60 m/s max | ±120 m/s max |
| Auto-Level | 2초 미조작 시 | 4초 미조작 시 | 없음 |
| 최저고도 보호 | 50m 자동 상승 | 20m 자동 상승 | 5m (경고만) |
| Stall 실속 | 없음 | 없음 | < 100km/h 시 |

### 3.3 Thumb Button Controls
| 위치 | 버튼 | 기능 |
|------|------|------|
| 왼쪽 하단 | 🚀 부스터 | 속도 가속 |
| 오른쪽 하단 | ⭐ 아이템 | 발사체 발사 |

### 3.4 3D World

#### 3.4.1 Camera System
- 3인칭 카메라: 캐릭터 뒤쪽 상단에서 추종
- 캐릭터+탈것이 화면 중앙 30~40% 영역 차지
- 부드러운 카메라 (Lerp, damping)
- 선회 시 뱅킹 효과

#### 3.4.2 Terrain (MVP)
- Perlin Noise 기반 Procedural 지형
- 고도별 색상: 물(파란) → 모래(노란) → 풀(초록) → 산(갈색) → 눈(흰색)
- Chunk 방식: 캐릭터 주변 3×3 청크만 로드

### 3.5 Flight Modes

#### 3.5.1 자유 비행 (Free Flight)
- 종료 조건 없음
- 비행 시간 HUD 상단에 MM:SS 표시
- 별 수집 계속 누적

#### 3.5.2 Step Goal (단계별 미션)

**Stage 1: 하늘 산책** ★☆☆☆☆ - 링 10개 순서대로 통과
**Stage 2: 구름 미로** ★★☆☆☆ - 구름 기둥 사이 경로 비행
**Stage 3: 계곡 비행** ★★★☆☆ - 구불구불한 계곡 저공비행
**Stage 4: 산맥 넘기** ★★★★☆ - 산봉우리 7개의 정상 링 통과
**Stage 5: 스카이 레이스** ★★★★★ - 에어 레이스 코스 완주

### 3.6 HUD

| 요소 | 위치 | 표시 내용 |
|------|------|----------|
| 속도 게이지 | 좌상단 | 현재 속도 (KM/H) |
| 고도 게이지 | 우상단 | 현재 고도 (M) |
| 나침반 | 상단 중앙 | 비행 방향 (N/S/E/W) |
| 비행 시간 | 상단 중앙-우측 | MM:SS |
| 민감도 레벨 | 좌상단 | Lv.1 / Lv.2 / Lv.3 |
| 별 카운터 | 좌하단 | ⭐ × 12 |
| 지역명 | 하단 중앙 | Fade in/out |

## 4. UI/UX Design

### 4.1 Color Palette
| Element | Hex | Usage |
|---------|-----|-------|
| Sky Blue | #87CEEB | 하늘 배경 |
| Turtle Green | #2ECC71 | 마스코트 컬러, Easy |
| Boost Orange | #FF6B35 | 부스터 버튼, 화염 |
| Star Gold | #FFD700 | 아이템 버튼, 별 |
| HUD Cyan | #7FDBFF | HUD 텍스트 |
| Panel Dark | #1A1A2E | HUD 배경 |

## 5. Technical Implementation Details

See source code for detailed implementations of:
- CharacterConfig / CharacterType / VehicleType
- CharacterAnimator
- SensitivityProfile
- FlightEngine
- TerrainGenerator

### 5.4 Performance Targets
| Metric | Target |
|--------|--------|
| Frame Rate | 60 FPS |
| Memory | < 250MB |
| App Size | < 80MB |
| Launch Time | < 3초 |
| Sensor Latency | < 16ms |

## 6. Development Roadmap

### 6.1 MVP (v1.0) — 6주
- W1: Foundation (Xcode, SceneKit, Perlin noise, CoreMotion)
- W2: Character (거북이 Turbo + Shell Jet, 3인칭 카메라)
- W3: Controls (자이로 3단계, 부스터/아이템 버튼)
- W4: World + 5캐릭터 (나머지 캐릭터, 아이템, HUD, 사운드)
- W5: Modes (자유 비행, Step Goal 5스테이지, 홈/캐릭터선택)
- W6: Polish (최적화, 테스트, App Store 준비)

## 7. App Store Submission

| Field | Value |
|-------|-------|
| App Name | Turtle Flight |
| Subtitle | Tilt to Fly |
| Category | Games > Simulation |
| Age Rating | 4+ |
| Price | Free |

## 8. Testing Strategy

- Unit Test: FlightEngine, GyroController, SensitivityProfile, CharacterRegistry, MissionEngine
- UI Test: 캐릭터 선택, 탈것 전환, 모드 전환, 스테이지 해금
- Performance: FPS, 메모리, 배터리
- Device Test: iPhone 12~16

## 9. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|-----------|
| 6종 캐릭터 모델링 시간 초과 | HIGH | Low-poly 스타일, W4에서 4종만 우선 |
| 자이로 멀미 | HIGH | FOV 제한, Lv.1 강한 스무딩 |
| 민감도 밸런스 실패 | HIGH | 3단계 프로파일 실제 테스트 |
| App Size 초과 | MED | Low-poly + 텍스처 압축 |

## 10. Claude Code 운영 가이드

See CLAUDE.md for project instructions.

## 11. Appendix

### 11.1 Glossary
| Term | Definition |
|------|-----------|
| CoreMotion | Apple 모션 센서 프레임워크 |
| SceneKit | Apple 3D 렌더링 프레임워크 |
| Dead Zone | 센서 입력 무시 범위 |
| Perlin Noise | 자연 지형 생성 알고리즘 |
| Low-poly | 적은 폴리곤으로 스타일화된 3D 모델 |
| MVP | Minimum Viable Product |
| Stall | 실속 — 속도 부족으로 양력 상실 |
