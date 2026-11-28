# 이펙트 · 텍스처 — Effekseer, Material Maker

## 우리 현재 상태

- 파티클은 `SCNParticleSystem()` 을 각 파일에서 직접 설정한다: SkyWonder(유성우, 반짝임, 안개, 물기둥), SetPieceFactory, PostcardRewards(불꽃놀이), CharacterRegistry(탈것 트레일).
- 이미지는 거의 모두 `WonderFactory.dotImage` 하나. 수명 곡선은 엽서 불꽃의 투명도 하나뿐이다.
- 링 통과(BULLSEYE/GREAT/OK)는 링 자체 애니메이션과 HUD 위주이고, 공간 이펙트는 약하다.
- 텍스처 에셋은 캐릭터 아틀라스뿐(6.3 MB). 지형·구름·물은 정점 색과 재질 색으로 그린다.

## Effekseer — 가져올 것: "이펙트 = 데이터" 분리

Effekseer 는 에디터와 런타임으로 나뉜다. 런타임에는 Metal 백엔드(`Dev/Cpp/EffekseerRendererMetal`)도 있다.

런타임을 들이지 않는 이유:
- SceneKit 렌더 패스 안에 별도 Metal 인코더로 그려야 한다(`SCNSceneRendererDelegate` + `currentRenderCommandEncoder`). 깊이·투명 정렬을 SceneKit 과 맞추기 어렵다.
- C++ 런타임 + 셰이더 + 에디터 포맷(.efkefc) 의존이 생긴다. 지금 이펙트 수(10개 미만)로는 과하다.
- Swift 6 엄격 동시성 경계에 C++ 상태가 생긴다.

가져올 개념:
1. **이펙트를 데이터로**: 방출기 설정 + 수명 곡선을 값 타입 하나로 → [../examples/EffectPreset.swift](../examples/EffectPreset.swift). 코드 7곳의 설정이 한 빌더로 모이고, 테스트에서 프리셋 목록을 검사할 수 있다.
2. **수명 곡선(over life)**: 크기·투명도가 시간에 따라 변해야 "팡" 하는 맛이 난다. Effekseer 이펙트의 대부분이 이 곡선이다. SceneKit 은 `SCNParticlePropertyController` + `CAKeyframeAnimation` 으로 같은 걸 할 수 있다.
3. **레이어 합성**: 이펙트 하나 = 섬광(짧고 큼) + 파편(빠르고 작음) + 잔광(느리고 흐림). 프리셋 배열로 표현한다.
4. **미리보기 도구**: Effekseer 에디터처럼 한 화면에서 돌려 보는 DEBUG 장면(B2-4). 오너가 실기기에서 보고 고른다.

적용 후보 (효과 대비 비용 순):
| 이펙트 | 지금 | 프리셋 |
|---|---|---|
| BULLSEYE 링 통과 | 링 애니메이션 | 금색 섬광 + 파편 (`bullseyeBurst`) |
| 별 획득 | 소리·HUD | 위로 튀는 반짝임 (`starPickup`) |
| 상승기류 볼거리 | 고정 파티클 | 커지며 사라지는 안개 (`updraftMist`) |
| 링 트레일 완주 | 토스트 | 민트색 링 5개 자리에 연속 섬광 |
| 부스트 시작 | 카메라 임팩트 | 속도선(길쭉한 파티클, 카메라 앞) |

주의: 새 파티클 재질은 첫 등장 때 셰이더 컴파일 히치가 난다(링 트레일 83 ms 사례). 프리셋은 비행 시작 `prewarm` 에 넣는다(B2-3).

## Material Maker — 가져올 것: 텍스처도 합성 파이프라인으로

Material Maker 는 Godot 기반 절차적 텍스처 노드 에디터다. 노이즈·패턴 노드를 조합해 PNG 맵(알베도·노멀·거칠기)을 내보낸다.

우리 오디오 파이프라인(`scripts/audio/render_assets.swift` → `build_audio.sh`)과 똑같은 생각을 텍스처에 적용한다:

```
scripts/textures/render_textures.swift   ← 노이즈 레시피로 타일 PNG 생성 (CoreGraphics, 외부 에셋 없음)
scripts/textures/build_textures.sh       ← 렌더 → Assets.xcassets 또는 TurtleFlight/Textures/
```

후보 텍스처 (모두 작은 타일, 256² 그레이스케일 → 색은 재질에서 곱함):
- 구름 결: 구름 퍼프 표면의 부드러운 명암 (지금은 단색)
- 모래 물결: 사막 월드 가까운 청크 디테일
- 물 반짝임: `WaterSurface` 의 스펙큘러 마스크
- 지형 디테일: 정점 색 위에 세계 좌표 UV 로 곱하는 잔무늬. 64×64 격자의 밋밋함을 줄인다

Material Maker 자체는 **스케치 도구**로만 쓴다. 오너가 노드로 모양을 잡아 보고 마음에 들면, 같은 레시피를 스크립트로 옮긴다. 결과물 재현성(CI·에이전트에서 다시 만들 수 있음)이 우리 규칙이기 때문이다.

예산: 번들 증가 1 MB 미만, 소크 GPU ms 악화 1 ms 미만(B5-2).
