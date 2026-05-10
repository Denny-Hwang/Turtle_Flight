# AudioManager Audit (v1.0 출시 전 점검)

**감사일:** 2026-05-04
**대상:** `TurtleFlight/Core/Audio/AudioManager.swift`
**관점:** Apple HIG · App Store Review · 성능 · 메모리

## 요약

런타임 합성 오디오(WAV PCM 즉석 생성) 방식. 자산 부담 0이라 < 80MB 앱 크기 목표에 유리. 다만 **세션 라이프사이클 처리, 사용자 컨트롤, 생성 비용** 3가지 영역에 미해결 항목이 있어 이번 라운드에서 일부 처리. 나머지는 follow-up.

## 강점 (유지)

- `AVAudioSession.ambient + .mixWithOthers` — 사용자 다른 오디오(Apple Music 등)와 공존. App Review에서 호평.
- Off-main-thread 재생 셋업 (`DispatchQueue.global(qos: .userInitiated)`).
- 스테레오 SFX 루프에 fade-in/out crossfade 적용 → 클릭 아티팩트 없음.
- 테마별 BGM 차별화 (sky/space/ocean) 화음 구조 다름.
- 모든 재생 진입점에 `isMuted` 가드.

## 이번 PR에서 수정 (4건)

| # | 이슈 | 처리 |
|---|------|------|
| A1 | **Audio session interruption 미처리** — 전화/Siri 후 BGM 복원 안 됨 | `AVAudioSession.interruptionNotification` 옵저버 추가, `.shouldResume` 옵션 존중 |
| A2 | **Route change 미처리** — 헤드폰 분리 시 스피커로 폭발 | `.oldDeviceUnavailable` 라우트 변경 시 자동 일시정지 (Apple HIG 준수) |
| A3 | **Mute 상태 비영속** — 앱 재시작 시 음소거 풀림 | `UserDefaults` "audio.muted" 영속, `toggleMute()` 추가 |
| A4 | **BGM/Vehicle SFX 매번 재합성** — 30초 BGM ≈ 1.32 MB WAV를 비행 시작마다 새로 생성 | `wavCache: [String: Data]` 메모이제이션 |

추가로 `wavData(from:)` 의 `Data.reserveCapacity(44 + dataSize)` 추가 → 샘플당 O(N) 재할당 제거.

## Follow-up (다음 PR 후보)

### Medium

- ~~**인게임 음소거 UI 부재**~~ — ✅ **PR #43 Sprint 2에서 해소**. `SettingsView`(Audio 섹션)에 mute toggle 추가, `HomeView` 우상단 gear 버튼으로 진입.
- ~~**Volume slider 부재**~~ — ✅ **PR #43 Sprint 2에서 해소**. `setBGMVolume(_:)` / `setSFXVolume(_:)` 공개 API + UserDefaults 영속화. 슬라이더는 SettingsView Audio 섹션에서 0–100% 노출.
- **`sfxPlayers` 딕셔너리 상한 없음** — 일회성 SFX는 0.1~1.2초 후 timer로 자동 정리되지만, 연타 시 일시 피크 발생 가능. 16개 정도로 캡 권장. (여전히 open — v1.x 후보.)

### Low

- **AVAudioPlayer 재생 latency ~50–100ms** — UI 탭 사운드(0.1초)에는 체감 지연 있음. AVAudioEngine + AVAudioPlayerNode + 사전 로드 buffer 로 <10ms 가능. 캐주얼 게임 기준 비필수.
- **합성 함수의 `whiteNoise()`가 `Double.random(in:)` 사용** — 결정적 시드가 없어 매 호출마다 다른 노이즈. 의도적이지만, 캐싱과 결합 시 첫 합성된 노이즈가 영구화됨. 음향 디자인적으로 OK 또는 의도와 어긋남 둘 다 가능 — 디자이너 확인 필요.

## 의도적으로 미적용

- **AVAudioEngine으로의 전환** — CLAUDE.md가 가능성을 언급했지만, 이 게임 장르에는 sample-accurate sync가 필요한 컨텐츠(리듬·박자)가 없음. 현재 AVAudioPlayer 방식이 유지 비용 대비 충분.
- **CoreHaptics와의 동기 재생** — 햅틱 별도 시스템이라 오디오 트리거와 시간 정합 우선순위 낮음. UIImpactFeedbackGenerator로도 출시 가능.

## 검증 방법 (TestFlight)

- [ ] BGM 재생 중 전화 수신 → 통화 종료 시 BGM 자동 재개
- [ ] 헤드폰 사용 중 빼기 → 즉시 일시정지 (스피커로 안 나감)
- [ ] Mute 상태에서 앱 종료 후 재시작 → 여전히 음소거
- [ ] 연속 비행 시작 (홈 → 비행 → 홈 → 비행 ×5) → 메모리 증가 없는지 Instruments Allocations 확인
- [ ] 동일 테마(sky) 두 번째 비행 시작 → 첫 번째와 같은 BGM (캐시 동작 확인)
