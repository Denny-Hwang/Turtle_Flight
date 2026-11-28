# 지형 · 노이즈 — FastNoise2, Terrain3D, Voxel Tools

## 우리 현재 상태

- `TerrainGenerator`: 200 m 청크, 64×64 격자, 플레이어 주변 3×3. 장식은 청크 메시 하나로 굽는다(드로우 콜 1).
- 먼 지형: 100 m 칸 44×44 메시 하나, 400 m 움직이면 다시 만듦. 상세 청크와 겹치지 않게 6 m 낮춰 그린다.
- 높이: `MathHelpers.fractalNoise` (value noise, 4옥타브) → `WorldProfile.Shape` (`rolling` / `dunes` / `plain`).
- 색: 정점 색. 높이 램프 + 경계 블렌드 + 경사면 바위 + 저주파 밝기 변화(V2).
- `updateChunks` 는 렌더 스레드 `update()` 에서 동기 호출된다.

## FastNoise2 — 가져올 것: 노이즈 "레시피"

FastNoise2 는 노이즈를 노드 그래프로 조합한다. 생성기 목록(`include/FastNoise/Generators/`):
Value, Perlin, Simplex, Cellular, Fractal(FBm/Ridged), DomainWarp(Gradient/Simplex), DomainWarpFractal, Blends, Modifiers.

우리에게 필요한 건 SIMD 라이브러리가 아니라 **조합 방식**이다. 지형 다양성의 대부분이 몇 가지 레시피에서 나온다.

| 레시피 | 모양 | 우리 월드 예 |
|---|---|---|
| Ridged multifractal | 날카로운 능선, 매끈한 골짜기 | 협곡 / 산등성이 월드, 링 코스가 골짜기를 따라감 |
| Domain warp | 덩어리가 구불구불한 강·계곡으로 | 사막 와디, 강이 굽이치는 도시 |
| Billow | 둥근 언덕 | 동화풍 초원 |
| Cellular 거리 + 마스크 | 섬, 분화구, 테라스 | 군도 월드(바다 위 섬 여러 개) |
| Terrace (Modifiers) | 계단식 지형 | 계단식 논 / 메사 |

구현: [../examples/NoiseRecipes.swift](../examples/NoiseRecipes.swift). 기존 `valueNoise2D` 를 그대로 쓰고 [0,1] 범위를 유지한다(스크래치 검사: 2만 점에서 0.0001–0.955).

주의:
- **기존 7개 월드는 바꾸지 않는다.** 코스, 고스트, 랜드마크 배치가 지금 높이에 묶여 있다. 그래서 B1-1 골든 테스트가 먼저다.
- Value noise 는 격자 방향 무늬가 보인다. 새 월드에서 눈에 띄면 OpenSimplex2 를 Swift 로 옮긴다(공개 알고리즘, 150줄 안팎). 그 전에는 도메인 워프만으로도 격자 느낌이 크게 줄어든다.
- 곁가지: `MathHelpers.pseudoRandom` 의 `abs(hash)` 는 `hash == Int.min` 이면 트랩한다(확률 2⁻⁶⁴). B1-2 때 `abs(hash)` 를 `hash.magnitude`(UInt, 트랩 없음)로 바꾸면 `Int.min` 외의 모든 입력에서 값이 같다. 비트 마스크(`& 0x7fff…`)는 음수에서 값이 달라지므로 쓰지 말 것. 바꾼 뒤 골든 테스트(B1-1)로 기존 높이가 그대로인지 확인한다.
- SIMD 배치 생성(FastNoise2 의 핵심 성능 기법)은 B0 측정에서 청크 생성이 병목으로 나올 때만(B1-4).

## Terrain3D — 가져올 것: 링 구조, 자동 셰이더 개념

Terrain3D 문서(`doc/docs/system_architecture.md`)의 핵심:
- **Geometry clipmap**: 메시를 한 번 만들고 카메라를 따라 옮기며, 높이는 GPU 정점 셰이더가 하이트맵에서 읽는다. "청크를 만들고 부수는" 방식과 대비해 설명한다. 우리는 그 청크 방식이다.
- **Autoshader**: 경사·높이로 텍스처를 자동 선택한다. 우리 V2 정점 색(경사면 바위)과 같은 생각이고, 이미 하고 있다.
- **World noise**: 편집 영역 밖의 배경 언덕을 셰이더 fbm 으로 그린다. 충돌은 없고 보기용이다. 우리 "먼 지형"과 같은 역할이다.

우리에게 맞는 부분:
1. **먼 지형을 가운데가 빈 링으로**(B4-1). 지금은 상세 청크 밑에 먼 지형이 6 m 낮게 겹쳐 있다. 보이지 않는 삼각형을 그리고 있고, 언덕 꼭대기에서 겹침이 비칠 수 있다.
2. **메시 데이터는 백그라운드, 교체만 렌더 스레드**(B4-2). 랜드마크 풀과 같은 패턴이다.
3. 진짜 클립맵(셰이더 높이)은 **보류**. `ChunkGround` 충돌, 장식 배치, 코스 고도 검사가 모두 CPU 높이를 쓴다. SceneKit 셰이더 모디파이어로 높이를 두 번 구현하면 두 값이 어긋날 위험이 크다.

## Voxel Tools — 불채택

복셀은 파괴·굴착 지형, 동굴, 오버행을 위한 것이다. 비행 게임에서 지형은 배경이고, 동굴 같은 볼거리는 `SetPiece`(터널 통과형)로 이미 만든다. 메모리(청크별 복셀 데이터)와 메싱 비용에 비해 얻는 것이 없다.

기억해 둘 아이디어 하나: **SDF(부호 거리 함수)로 볼거리 모양 만들기.** 아치·동굴 입구를 SDF 합집합으로 정의하면 충돌(`contact`)과 모양이 한 정의에서 나온다. 지금은 `LandmarkShape` 를 손으로 근사한다. 볼거리 종류가 크게 늘 때 다시 검토한다.
