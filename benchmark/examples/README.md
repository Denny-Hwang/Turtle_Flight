# examples

Sketches for [../PLAN.md](../PLAN.md). They are **not** in the app or test targets (`project.yml` only picks up `TurtleFlight/`, `Tests/` and `ScreenshotTests/`). When a plan step is picked up, the file moves into `TurtleFlight/` and gets real tests.

| File | Step | Idea from |
|---|---|---|
| `NoiseRecipes.swift` | B1 | FastNoise2 |
| `EffectPreset.swift` | B2 | Effekseer |
| `SweptContact.swift` | B3 | Jolt Physics |
| `MeshoptBridge.swift` | B6 | meshoptimizer (compiled only when the `MeshOpt` package exists) |

Type-check them the same way the app is built (Swift 6, iOS 16):

```sh
xcrun swiftc -typecheck -swift-version 6 \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios16.0-simulator benchmark/examples/*.swift
```
