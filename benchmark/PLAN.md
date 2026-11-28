# 반영 계획 (benchmark → 앱)

상태: ☐ 할 일 · ☑ 완료 · ⏸ 보류. 근거는 [README.md](README.md), 기술 노트는 [notes/](notes/).
각 단계는 PR 하나 크기로 잡았다. 성능 단계는 **측정 게이트**를 통과해야 시작한다.

## B0 측정 기반 — 먼저 할 것

| # | 내용 | 완료 기준 |
|---|---|---|
| ☐ B0-1 | `PerfProbe` CSV 에 열 추가: 그 초의 청크 생성 최대 ms, 청크 생성 횟수 | `verify.sh` 요약에 "청크 생성 최악 N ms" 한 줄 |
| ☐ B0-2 | 장면 삼각형 수·노드 수 스냅샷 (DEBUG, 10초마다 장면 그래프를 훑어 `SCNGeometryElement.primitiveCount` 합) | 월드별 수치를 `docs/DEVICE_VERIFICATION.md` 에 기록 |
| ☐ B0-3 | Xcode Instruments(Metal System Trace)로 월드 3곳 GPU 프레임 시간 측정 절차 문서화 | GPU ms / 프레임이 기준(16.6 ms 의 60% = 10 ms) 아래인지 표 |

왜: 지금 `updateChunks` 는 렌더 스레드에서 동기로 청크 3개(67×67 높이 + 장식 + 굽기)를 만든다 (`FlightViewModel.swift` update 루프). 소크 최악 33 ms 로 통과했지만 iPhone 12 미만·발열 상태에서는 여기가 먼저 걸릴 수 있다. 숫자가 있어야 B4/B6 을 할지 말지 정할 수 있다.

## B1 노이즈 레시피 (FastNoise2 아이디어) — 새 월드용

| # | 내용 | 완료 기준 |
|---|---|---|
| ☐ B1-1 | 기존 월드 지형 고정 테스트: 월드 7개 × 샘플 점 20개의 `terrainHeight` 골든 값 | 노이즈 코드를 건드려도 기존 월드 높이가 1e-4 안에서 같음 |
| ☐ B1-2 | `NoiseRecipes` (fbm / ridged / billow / domain warp / island mask) 를 `MathHelpers` 옆에 추가 — [examples/NoiseRecipes.swift](examples/NoiseRecipes.swift) | 단위 테스트: 범위 [0,1], 같은 시드 같은 값, 이음새 없음 |
| ☐ B1-3 | `WorldProfile.Shape` 에 `.recipe(NoiseRecipe)` 케이스 추가 — 기존 케이스는 그대로 | 새 월드 1개(예: 협곡/섬 군도)로 시험, 코스 오르막 제한(`limitClimb`) 테스트 통과 |
| ☐ B1-4 | 높이 격자를 한 번에 채우는 배치 함수 (행 단위 SIMD) | B0-1 의 청크 생성 ms 가 20% 이상 줄면 채택, 아니면 버림 |

예시 — 협곡 월드: `ridged` 를 도메인 워프로 비틀어 구불구불한 능선, 그 사이 골짜기로 링 코스를 낸다. 군도 월드: `islandMask` 로 바다 위 섬 여러 개.

## B2 이펙트 프리셋 (Effekseer 아이디어)

| # | 내용 | 완료 기준 |
|---|---|---|
| ☐ B2-1 | 흩어진 `SCNParticleSystem()` 설정(SkyWonder 4곳, SetPieceFactory, PostcardRewards, 탈것 트레일)을 `EffectPreset` 데이터로 옮김 — [examples/EffectPreset.swift](examples/EffectPreset.swift) | 화면 결과 동일(스크린샷 비교), 코드 줄 수 감소 |
| ☐ B2-2 | 수명 곡선: 크기·투명도 over life (`SCNParticlePropertyController`) — 지금은 엽서 불꽃(`PostcardRewards`)만 투명도 곡선을 쓰고 나머지는 고정값 | 링 BULLSEYE 버스트, 별 획득, 볼거리 통과에 적용 |
| ☐ B2-3 | 프리셋 미리 데우기: `prewarm` 에 이펙트 노드도 포함 (트레일 셰이더 히치와 같은 종류 방지) | 소크 최악 프레임 악화 없음 |
| ☐ B2-4 | DEBUG 이펙트 갤러리 장면 (`-TFScreenshot effects`) — 프리셋을 한 화면에 나열 | 오너가 실기기에서 한 번에 보고 고를 수 있음 |

## B3 스윕 충돌 (Jolt 아이디어)

| # | 내용 | 완료 기준 |
|---|---|---|
| ☐ B3-1 | 테스트로 먼저 확인: 얇은 랜드마크(탑 다리, 아치 기둥)를 한 프레임에 건너뛰는지. 에너지 속도 상한 380 × 부스트 2.0 이면 프레임당 12.7 m(60 fps) / 25 m(30 fps)인데, 충돌은 프레임 끝 점 하나만 `playerPad` 6 m 로 검사한다 | 터널링이 재현되면 B3-2, 아니면 ⏸ |
| ☐ B3-2 | 프레임 이동 구간을 `pad/2` 간격으로 나눠 첫 접촉을 찾는 `SweptContact` — [examples/SweptContact.swift](examples/SweptContact.swift) | 재현 테스트 통과, 정상 비행 비용 증가 < 0.1 ms |

## B4 먼 지형 링 (Terrain3D 아이디어) — 측정 게이트

시작 조건: B0 에서 먼 지형 재생성(400 m마다 45×45) 또는 청크 교체가 최악 프레임의 원인으로 보일 때.

| # | 내용 | 완료 기준 |
|---|---|---|
| ☐ B4-1 | 먼 지형을 가운데가 빈 링으로 (상세 청크 영역은 삼각형 없음) — 지금은 6 m 낮춰 겹쳐 그림 | 겹침 삼각형 0, 가장자리 틈은 스커트로 막음 |
| ☐ B4-2 | 재생성을 백그라운드로: 메시 데이터는 백그라운드에서 만들고 노드 교체만 렌더 스레드 (랜드마크 풀과 같은 패턴) | 청크 생성 ms 가 렌더 스레드에서 사라짐 |
| ⏸ B4-3 | 진짜 클립맵(정점 셰이더에서 높이 계산) | 보류 — 충돌·장식이 CPU 높이를 쓰므로 이득보다 복잡도가 큼 |

## B5 텍스처 합성 파이프라인 (Material Maker 아이디어)

| # | 내용 | 완료 기준 |
|---|---|---|
| ☐ B5-1 | `scripts/textures/render_textures.swift` + `build_textures.sh`: 노이즈로 타일 텍스처 PNG 생성 (구름 결, 모래 물결, 물 반짝임) | 오디오처럼 CI·에이전트에서 재생성 가능, 결과 커밋 |
| ☐ B5-2 | 지형 디테일 텍스처: 가까운 청크에만 세계 좌표 UV 타일(정점 색에 곱하기) | 번들 증가 < 1 MB, 소크 GPU ms 악화 < 1 ms |
| ☐ B5-3 | Material Maker 는 오너가 노드 그래프로 모양을 잡아 보는 **스케치 도구**로만 — 결과물은 스크립트로 다시 만든다 | 문서화만 |

## B6 meshoptimizer LOD — 측정 게이트

시작 조건: B0-3 에서 GPU 프레임 시간이 10 ms 를 넘는 월드가 있거나, 랜드마크·볼거리 삼각형이 장면의 40% 이상.

| # | 내용 | 완료 기준 |
|---|---|---|
| ☐ B6-1 | SwiftPM 로컬 패키지로 meshoptimizer C 소스 벤더링 (`Packages/MeshOpt`), `ACKNOWLEDGEMENTS` 추가 | 앱 크기 증가 < 300 KB |
| ☐ B6-2 | `bake()` 출력에 `meshopt_optimizeVertexCache` — [examples/MeshoptBridge.swift](examples/MeshoptBridge.swift) | GPU ms 측정 비교 |
| ☐ B6-3 | 랜드마크 풀 생성 시 `meshopt_simplify` 로 LOD 2단계 → `SCNLevelOfDetail` | 먼 랜드마크 삼각형 50% 감소, 눈으로 차이 없음 |

## B7 동행 무리 회피 (DetourCrowd 아이디어) — 낮은 우선

| # | 내용 | 완료 기준 |
|---|---|---|
| ☐ B7-1 | 동행 새끼리 분리(separation) + 랜드마크 앞에서 속도 샘플링 회피 — `CompanionFlight` 순수 상태기계 안에서 | 새가 랜드마크를 뚫고 지나가는 일 0 (테스트) |

## 하지 않을 것

- Effekseer / Jolt / The Forge / ozz 런타임 링크 — 이유는 각 노트.
- Voxel Tools — 파괴 지형·동굴이 게임 콘셉트에 없다.
- 기존 7개 월드의 지형 노이즈 교체 — 코스·고스트 호환.

## 권장 순서

B0 → B2 → B1 → B3-1 → (측정 결과에 따라 B4 / B6) → B5 → B7.
B2(이펙트)는 측정 없이도 바로 눈에 띄는 개선이라 B0 다음에 두었다.
