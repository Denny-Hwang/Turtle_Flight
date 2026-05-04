# TurtleFlight

**A Sky Adventure for Animals That Can't Fly** — A gyroscope-based character flight adventure game for iOS.

Six adorable animals take to the skies with their unique vehicles in this tilt-controlled flying experience. No airplanes here — the characters themselves soar through the air!

## Characters

| Character | Name | Unique Vehicle | Description |
|-----------|------|---------------|-------------|
| Turbo | Turtle | Shell Jet | A jet-powered shell strapped to his back |
| Pip | Penguin | Belly Glider | Glides on his belly through the sky |
| Nutty | Hamster | Hamster Ball Copter | A hamster ball turned helicopter |
| Mochi | Cat | Magic Broom | Rides a magical broomstick |
| Bounce | Frog | Balloon Body | Inflates like a balloon to fly |
| Hoppy | Bunny | Ear Copter | Ears spin like helicopter blades |

All characters also share the **Cloud Surf** — a cloud-riding vehicle available to everyone.

## Flight Modes

- **Free Flight** — Unlimited open-sky exploration with a flight timer (MM:SS)
- **Step Goal** — Complete 5 stages of missions and earn up to 3 stars per stage

## Controls

TurtleFlight uses your device's gyroscope for intuitive tilt-based controls with three sensitivity levels:

| Level | Dead Zone | Curve | Smoothing | Auto-Level |
|-------|-----------|-------|-----------|------------|
| Easy | 8° | Cubic (x³) | 0.08 | 2s |
| Normal | 4° | Quadratic (x²) | 0.15 | 4s |
| Expert | 1.5° | Linear (x) | 0.35 | Stall enabled |

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI + UIKit
- **3D Engine:** SceneKit
- **Motion:** CoreMotion (gyroscope)
- **Audio:** AVFoundation
- **Platform:** iOS 16.0+, Landscape only

## Project Structure

```
TurtleFlight/
├── App/                    # App entry point
├── Core/
│   ├── Character/          # Character registry, animator, vehicle definitions
│   ├── Flight/             # Flight physics engine
│   ├── Gyro/               # Gyroscope controller & sensitivity profiles
│   ├── Item/               # Collectible item system
│   ├── Mission/            # Mission engine & stage definitions
│   └── Terrain/            # Procedural terrain generation
├── Models/                 # Data models (CharacterType, VehicleType, etc.)
├── ViewModels/             # Flight, Mission, Character view models
├── Views/
│   ├── Home/               # Home screen & character selection
│   ├── Flight/             # Main flight view
│   ├── HUD/                # HUD overlay & mission HUD
│   └── Controls/           # On-screen control buttons
├── Utils/                  # Constants, extensions, math helpers
└── Resources/
    ├── ko.lproj/           # Korean Localizable.strings
    └── en.lproj/           # English Localizable.strings
Tests/                      # XCTest suites for core systems (109+ cases)
docs/
├── SDD.md                  # Software Development Document
└── VALIDATION_REPORT.md    # Pre-submission validation report
```

## Requirements

- iOS 16.0 or later
- iPhone with gyroscope (iPhone 12+ recommended)
- Xcode 15.0+

## Performance Targets

- 60 FPS on iPhone 12+
- < 250 MB memory usage
- < 80 MB app size

## Getting Started

1. Clone the repository
2. Open the project in Xcode 15+
3. Select an iOS device or simulator target
4. Build and run (Cmd + R)

> **Note:** Gyroscope controls require a physical device. The simulator will use fallback input.

## Localization

Korean (`ko`) and English (`en`) are bundled. Strings live in
`TurtleFlight/Resources/<locale>.lproj/Localizable.strings`. The development
region is `en` and Korean is the primary marketing locale for v1.

## Documentation

- [`docs/SDD.md`](docs/SDD.md) — Software Development Document (architecture, roadmap, technical spec)
- [`docs/VALIDATION_REPORT.md`](docs/VALIDATION_REPORT.md) — Pre-submission validation report (109+ XCTest cases, bug fixes)

## License

This project is licensed under the BSD 3-Clause License. See [LICENSE](LICENSE) for details.
