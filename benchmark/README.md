# benchmark — 오픈소스 게임 기술 참고 노트

2026-11-28. 게임 개발용 무료 오픈소스 도구 10개를 TurtleFlight 기준으로 살펴본 기록이다.
라이브러리를 그대로 가져오는 것보다 **아이디어·알고리즘·파이프라인을 우리 구조(SceneKit + Swift 6, 전부 합성, 모델 파일 없음)에 맞게 옮기는 것**이 기본 방향이다.

- 반영 계획(단계·측정 기준·체크리스트): [PLAN.md](PLAN.md)
- 분야별 노트: [notes/](notes/)
- 예제 코드(앱 타깃 밖, 타입 검사만): [examples/](examples/)

## 한눈에 보기

| 도구 | 라이선스 | 무엇 | 우리에게 | 판정 |
|---|---|---|---|---|
| [FastNoise2](https://github.com/Auburn/FastNoise2) | MIT | SIMD 노드 그래프 노이즈 | 지형 모양 다양화 (도메인 워프, 능선, 셀룰러) | **아이디어 채택** — Swift로 몇 가지만 구현 |
| [meshoptimizer](https://github.com/zeux/meshoptimizer) | MIT | 메시 최적화·단순화 | 랜드마크·볼거리 LOD, 인덱스 캐시 정렬 | **조건부 채택** — 측정에서 GPU 여유가 부족할 때 |
| [Effekseer](https://github.com/effekseer/Effekseer) | MIT | 파티클 이펙트 에디터 + 런타임 (Metal 백엔드 있음) | 링 통과·보상 연출 품질 | **아이디어 채택** — 런타임 대신 데이터형 이펙트 프리셋 |
| [Terrain3D](https://github.com/TokisanGames/Terrain3D) | MIT | Godot 지형 (클립맵, 자동 셰이더) | 먼 지형 링 구조, 높이·경사 기반 색 | **아이디어 일부** — 먼 지형 겹침 제거 |
| [Material Maker](https://github.com/RodZill4/material-maker) | MIT | 절차적 텍스처 노드 에디터 | 디테일 텍스처를 "합성 파이프라인"으로 | **파이프라인 참고** — `scripts/textures/` 구상 |
| [Jolt Physics](https://github.com/jrouwe/JoltPhysics) | MIT | 리지드바디 물리 | 부스트 시 충돌 터널링 방지(스윕) | **아이디어만** — 라이브러리 불필요 |
| [Recast Navigation](https://github.com/recastnavigation/recastnavigation) | Zlib | 내비메시 + 군중 회피 | 동행 새 무리 회피 조향 | **아이디어만, 낮은 우선** |
| [ozz-animation](https://github.com/guillaumeblanc/ozz-animation) | MIT | 스켈레탈 애니메이션 | 캐릭터는 2D 빌보드 — 레이어 블렌딩 개념만 | **보류** |
| [Voxel Tools](https://github.com/Zylann/godot_voxel) | MIT | Godot 복셀 지형 | 파괴 지형 없음 | **불채택** |
| [The Forge](https://github.com/ConfettiFX/The-Forge) | Apache-2.0 | 멀티플랫폼 렌더러 프레임워크 | SceneKit 을 버릴 이유 없음 | **불채택** — 프로파일링 습관만 |

(라이선스·최근 커밋은 2026-11-28 GitHub API 기준. ozz 는 API 에 NOASSERTION 으로 나오지만 `LICENSE.md` 는 MIT.)

## 테크 트리

```
B0 측정 기반 (PerfProbe 확장: 청크 생성 ms, 삼각형 수, 드로우 콜)
 ├─ B1 노이즈 레시피 (FastNoise2 아이디어) ──► B4 먼 지형 링 (Terrain3D 아이디어)
 │        └─ 새 월드·변형 월드에만 적용 (기존 월드 지형은 고스트·코스 때문에 고정)
 ├─ B2 이펙트 프리셋 (Effekseer 아이디어) ──► B5 텍스처 합성 파이프라인 (Material Maker 아이디어)
 ├─ B3 스윕 충돌 (Jolt 아이디어) ──► B7 동행 무리 회피 (Recast/DetourCrowd 아이디어)
 └─ (측정 결과 GPU 여유 < 기준일 때만) B6 meshoptimizer LOD
```

## 원칙 (CLAUDE.md 와 같은 방향)

1. **네이티브 유지.** C++ 런타임(Effekseer, Jolt, The Forge)을 통째로 들이지 않는다. 번들 < 80 MB, Swift 6 엄격 동시성, 렌더 스레드 규칙을 지키기 어렵다.
2. **꼭 링크해야 하면 C API 만, 작게.** 후보는 meshoptimizer 하나(C 인터페이스, 의존성 없음). 넣을 때는 `ACKNOWLEDGEMENTS`(MIT 고지)와 설정 → 정보 화면에 라이선스 표시를 같이 넣는다.
3. **합성 파이프라인.** 오디오처럼 텍스처·이펙트도 저장소의 스크립트로 재생성할 수 있어야 한다. 생성형 모델·외부 에셋 금지.
4. **측정 먼저.** 성능 관련 단계(B4, B6)는 B0 측정에서 문제가 보일 때만 진행. 지금 iPhone XS 소크는 60 fps / 최악 33 ms / 126 MB 로 통과 상태.
5. **기존 월드의 지형 모양은 바꾸지 않는다.** 코스·고스트·랜드마크 위치가 `terrainHeight` 에 묶여 있다. 새 노이즈는 새 월드나 옵트인 프로필에만.
