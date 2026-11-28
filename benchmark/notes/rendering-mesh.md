# 렌더링 · 메시 — meshoptimizer, The Forge

## 우리 현재 상태

- 모든 3D 모양은 SceneKit 기본 도형 + 코드로 만든 메시. 모델 파일이 없다.
- 정지 부분은 재질별 메시 하나로 굽는다: 지형 장식(`bakeStaticProps`), 볼거리(`SetPieceFactory.bake`, `PropMesh`).
- LOD 없음(`SCNLevelOfDetail` 사용 0곳). 인덱스 순서 최적화 없음.
- 최근 히치는 모두 **CPU** 쪽이었다: 노드 생성(284 ms), 랜드마크 생성(67–100 ms), 첫 셰이더 컴파일(83 ms). 사전 생성 + `SCNView.prepare` 로 해결해 최악 33 ms.
- GPU 프레임 시간은 아직 잰 적이 없다 → B0-3.

## meshoptimizer — 조건부 채택 후보 1순위

이유: 이 목록에서 **링크해도 되는 유일한 라이브러리**다. C API(`src/meshoptimizer.h`), 의존성 없음, MIT, 작다.

쓸 함수 (2026-11 헤더 기준 시그니처):

```c
void   meshopt_optimizeVertexCache(unsigned int* destination, const unsigned int* indices,
                                   size_t index_count, size_t vertex_count);
void   meshopt_optimizeOverdraw(unsigned int* destination, const unsigned int* indices, size_t index_count,
                                const float* vertex_positions, size_t vertex_count,
                                size_t vertex_positions_stride, float threshold);
size_t meshopt_optimizeVertexFetch(void* destination, unsigned int* indices, size_t index_count,
                                   const void* vertices, size_t vertex_count, size_t vertex_size);
size_t meshopt_simplify(unsigned int* destination, const unsigned int* indices, size_t index_count,
                        const float* vertex_positions, size_t vertex_count, size_t vertex_positions_stride,
                        size_t target_index_count, float target_error, unsigned int options,
                        float* result_error);
```

`meshopt_simplify` 주의(헤더 주석): 결과 버퍼는 `index_count` 크기가 필요하다(`target_index_count` 가 아님). 위치는 각 정점의 앞 12바이트가 float3 여야 하고, `target_error` 는 메시 크기 대비 비율(0.01 = 1%)이다. 우리 `SCNVector3` 배열(iOS 에서 Float 3개, stride 12)을 그대로 넘길 수 있다.

적용 지점:
| 어디 | 무엇 | 기대 |
|---|---|---|
| `bake()` 출력 (볼거리, 청크 장식) | `optimizeVertexCache` | 같은 모양, 정점 셰이더 실행 감소 |
| 랜드마크 풀 생성(백그라운드) | `simplify` 로 LOD 2단계 → `SCNLevelOfDetail` | 먼 랜드마크 삼각형 절반 |
| 먼 지형 | `simplify` + `meshopt_SimplifyLockBorder` | 평지 삼각형 감소 |

**시작 조건**(PLAN B6): GPU 프레임 시간이 10 ms 를 넘는 월드가 있거나, 랜드마크·볼거리 삼각형이 장면의 40% 이상일 때. 지금 소크 결과로는 필요 없을 가능성이 높다. 측정 전에 넣지 않는다.

벤더링 방법(넣게 되면):

```
Packages/MeshOpt/
  Package.swift
  Sources/MeshOpt/*.cpp                   ← meshoptimizer/src/*.cpp 복사 (VERSION 파일에 태그 기록)
  Sources/MeshOpt/include/meshoptimizer.h ← 공개 헤더 (extern "C" 라 Swift 에서 바로 import 됨)
```

```swift
// Packages/MeshOpt/Package.swift
// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "MeshOpt",
    platforms: [.iOS(.v16)],
    products: [.library(name: "MeshOpt", targets: ["MeshOpt"])],
    targets: [.target(name: "MeshOpt", path: "Sources/MeshOpt",
                      publicHeadersPath: "include",
                      cxxSettings: [.unsafeFlags(["-O3"])])],
    cxxLanguageStandard: .cxx11)
```

`project.yml` 에서는 `packages: MeshOpt: path: Packages/MeshOpt` 로 연결한다. MIT 고지는 `ACKNOWLEDGEMENTS.md` 와 설정 → 정보에 넣는다. Swift 쪽 래퍼는 [../examples/MeshoptBridge.swift](../examples/MeshoptBridge.swift).
(`unsafeFlags` 는 로컬 경로 패키지에서만 허용된다. 빼도 Release 빌드는 기본 최적화가 걸린다.)

## The Forge — 불채택 (습관만 참고)

The Forge 는 콘솔·PC·모바일 공용 렌더러 프레임워크다(Visibility Buffer, 레이 트레이싱 등). 우리에게는 SceneKit 을 버리고 렌더러를 새로 짜는 일이 된다. 앱 크기, 개발 시간, 기존 460+ 테스트를 생각하면 얻을 것이 없다.

참고할 습관:
- **프레임 예산을 숫자로 관리.** 16.6 ms 를 CPU 시뮬레이션 / SceneKit 제출 / GPU 로 나눠 각 예산을 정한다. B0 로 PerfProbe 에 청크 생성 ms·삼각형 수를 넣는 것이 첫걸음이다.
- **셰이더 미리 컴파일.** The Forge 는 셰이더를 빌드 시점에 컴파일한다. 우리 대응책은 `SCNView.prepare` 로 미리 데우기이고, 이미 쓰고 있다. 새 재질을 추가할 때마다 prewarm 목록에 넣는 규칙을 유지한다.
