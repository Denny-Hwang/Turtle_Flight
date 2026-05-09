import SwiftUI
import SceneKit

struct FlightView: View {
    @ObservedObject var flightVM: FlightViewModel
    @ObservedObject var missionVM: MissionViewModel
    let character: CharacterType
    let vehicle: VehicleType
    let flightMode: FlightMode
    let mapTheme: MapTheme

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene = SCNScene()
    @State private var lastUpdateTime: TimeInterval = 0
    @State private var showGyroAlert = false
    /// True after the user taps Exit on Free Flight. We don't dismiss
    /// immediately — the FreeFlightResultView surfaces the run summary
    /// first, then dismiss is wired through its Home button.
    @State private var showFreeFlightResult = false

    var body: some View {
        ZStack {
            SceneKitView(
                scene: scene,
                flightVM: flightVM,
                onUpdate: { time in
                    // Skip the very first frame: with no prior timestamp, any
                    // assumed delta either stutters (too small) or pops the
                    // camera (too large). Establish the baseline and bail.
                    guard lastUpdateTime != 0 else {
                        lastUpdateTime = time
                        return
                    }
                    let delta = Float(time - lastUpdateTime)
                    lastUpdateTime = time
                    // Clamp for tab-switch / debugger pause spikes.
                    flightVM.update(deltaTime: min(delta, 0.05))
                }
            )
            .ignoresSafeArea()

            HUDOverlay(flightVM: flightVM)

            if flightMode == .stepGoal, let engine = flightVM.missionEngine {
                MissionHUD(missionEngine: engine, missionVM: missionVM)
            }

            ControlButtons(
                onBoost:     { flightVM.activateBoost() },
                onFire:      { flightVM.fireItem() },
                onCalibrate: { flightVM.calibrateGyro() },
                onPause:     { flightVM.pauseFlight() },
                onExit: {
                    // Free Flight: surface the result screen before
                    // dismissing so the player sees their run stats.
                    // Step Goal: just dismiss — if the player exits a
                    // mission mid-run, the result/fail overlay would
                    // already have surfaced if they completed it.
                    if flightMode == .freePlay {
                        flightVM.pauseFlight()       // freeze numerics for the summary
                        showFreeFlightResult = true
                    } else {
                        flightVM.stopFlight()
                        dismiss()
                    }
                }
            )

            // Step Goal — full-screen StageResultView when the mission
            // finishes (success or fail). Replaces the previous in-HUD
            // overlay (DESIGN_GAP_REPORT §S6).
            stageResultOverlay

            // Free Flight — end-of-run summary triggered by the Exit
            // button (DESIGN_GAP_REPORT §S7).
            if showFreeFlightResult {
                FreeFlightResultView(
                    flightTime: flightVM.flightTime,
                    starsCollected: flightVM.starsCollected,
                    isNewBestStars: flightVM.starsCollected > missionVM.progress.bestFreeFlightStars,
                    onHome: {
                        flightVM.stopFlight()
                        dismiss()
                    },
                    onAgain: {
                        // Retry the same character/vehicle/theme — restart
                        // the flight in place and dismiss the result modal.
                        showFreeFlightResult = false
                        flightVM.restartFlight()
                    }
                )
                .transition(.opacity)
            }

            // Pause modal — driven by flightVM.isPaused so both the
            // explicit Pause button and the scene-phase auto-pause
            // surface the same UI.
            if flightVM.isPaused {
                PauseView(
                    onResume:  { flightVM.resumeFlight() },
                    onRestart: {
                        flightVM.restartFlight()
                        // For Step Goal, also restart the current stage's
                        // rings + timer so retry-from-pause matches the
                        // result-overlay Retry semantics.
                        if flightMode == .stepGoal,
                           let stage = missionVM.currentStage {
                            flightVM.missionEngine?.startStage(stage)
                            missionVM.startMission()
                        }
                    },
                    onQuit: {
                        flightVM.stopFlight()
                        dismiss()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: flightVM.isPaused)
        .onAppear { setupScene() }
        .onDisappear { flightVM.stopFlight() }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background, .inactive:
                // Auto-pause when iOS takes the foreground (call, Siri,
                // app switcher). The user has to explicitly Resume on
                // return — no surprise mid-flight on reactivation.
                if flightVM.isFlying {
                    flightVM.pauseFlight()
                }
                lastUpdateTime = 0
            case .active:
                // Stay paused — user must tap Resume. If the user never
                // paused (e.g. control center swipe-up), we still wait for
                // their explicit Resume because pauseFlight() above
                // already flipped isPaused.
                break
            @unknown default:
                break
            }
        }
        .alert(L10n.t("flight.gyro.unavailable.title"), isPresented: $showGyroAlert) {
            Button(L10n.t("common.ok")) { dismiss() }
        } message: {
            Text(L10n.t("flight.gyro.unavailable.message"))
        }
        .statusBar(hidden: true)
    }

    // MARK: - Stage Result overlay

    /// Renders the full-screen Step Goal result (or fail) view when the
    /// MissionViewModel transitions to a terminal state. Renders nothing
    /// in Free Flight or while the mission is still in progress.
    @ViewBuilder
    private var stageResultOverlay: some View {
        if flightMode == .stepGoal, let stage = missionVM.currentStage {
            switch missionVM.missionState {
            case .completed:
                if let result = missionVM.lastResult {
                    StageResultView(
                        stage: stage,
                        outcome: .success(result),
                        // priorBest is the *previous* best; the most-recent
                        // result is already merged into stageResults by
                        // completeMission(), so we read from before that
                        // by computing it before the state flips. For now
                        // we pass the current best — the badge logic
                        // tolerates equal scores by NOT showing NEW BEST
                        // unless the time is strictly faster.
                        priorBest: missionVM.priorBestForLastResult,
                        hasNextStage: missionVM.hasNextStage,
                        onHome: {
                            missionVM.returnToSelect()
                            flightVM.stopFlight()
                            dismiss()
                        },
                        onRetry: {
                            flightVM.missionEngine?.startStage(stage)
                            missionVM.startMission()
                        },
                        onNext: {
                            if missionVM.advanceToNextStage(),
                               let next = missionVM.currentStage {
                                flightVM.missionEngine?.startStage(next)
                                missionVM.startMission()
                            }
                        }
                    )
                    .transition(.opacity)
                }
            case .failed(let reason):
                StageResultView(
                    stage: stage,
                    outcome: .failure(reason: reason),
                    priorBest: missionVM.progress.stageResults[stage.index],
                    hasNextStage: false,
                    onHome: {
                        missionVM.returnToSelect()
                        flightVM.stopFlight()
                        dismiss()
                    },
                    onRetry: {
                        flightVM.missionEngine?.startStage(stage)
                        missionVM.startMission()
                    },
                    onNext: { /* unused for failure */ }
                )
                .transition(.opacity)
            case .selecting, .playing:
                EmptyView()
            }
        }
    }

    // MARK: - Scene Setup

    private func setupScene() {
        scene.background.contents = mapTheme.backgroundColor

        // Ambient light
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = mapTheme.ambientLightIntensity
        ambient.light?.color = mapTheme.ambientLightColor
        scene.rootNode.addChildNode(ambient)

        // Directional light (sun / star)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = mapTheme.sunLightIntensity
        sun.light?.color = mapTheme.sunLightColor
        sun.light?.castsShadow = true
        sun.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sun)

        // Theme-specific extras
        switch mapTheme {
        case .sky:
            addSunSphere()
        case .space:
            addStarDome()
        case .ocean:
            addCausticsOverlay()
        }

        flightVM.startFlight(scene: scene, character: character, vehicle: vehicle, theme: mapTheme)

        // Check gyro availability after starting flight
        if !flightVM.gyroController.isAvailable {
            showGyroAlert = true
        }

        if flightMode == .stepGoal, let stage = missionVM.currentStage {
            flightVM.missionEngine?.startStage(stage)
            missionVM.startMission()
        }
    }

    /// Bright yellow sun sphere in sky theme
    private func addSunSphere() {
        let sun = SCNNode(geometry: SCNSphere(radius: 30))
        sun.position = SCNVector3(500, 800, -800)
        sun.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 1)
        sun.geometry?.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.9)
        scene.rootNode.addChildNode(sun)
    }

    /// Distant star particles for space theme
    private func addStarDome() {
        let starCount = 200
        for i in 0..<starCount {
            let angle1 = Float(i) / Float(starCount) * .pi * 2
            let angle2 = Float.random(in: 0...(Float.pi))
            let radius: Float = 3000
            let x = radius * sin(angle2) * cos(angle1)
            let y = radius * cos(angle2)
            let z = radius * sin(angle2) * sin(angle1)
            let star = SCNNode(geometry: SCNSphere(radius: CGFloat(Float.random(in: 0.5...2.5))))
            star.position = SCNVector3(x, y, z)
            let brightness = Float.random(in: 0.6...1.0)
            star.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: CGFloat(brightness), green: CGFloat(brightness), blue: 1.0, alpha: 1)
            star.geometry?.firstMaterial?.emission.contents =
                UIColor(red: CGFloat(brightness), green: CGFloat(brightness), blue: 1.0, alpha: 0.8)
            scene.rootNode.addChildNode(star)
        }
        // Distant nebula sphere
        let nebula = SCNNode(geometry: SCNSphere(radius: 2800))
        nebula.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.2, green: 0.05, blue: 0.35, alpha: 0.4)
        nebula.geometry?.firstMaterial?.isDoubleSided = true
        scene.rootNode.addChildNode(nebula)
    }

    /// Subtle caustic glow layer for ocean theme
    private func addCausticsOverlay() {
        let caustics = SCNNode(geometry: SCNSphere(radius: 2800))
        caustics.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.1, green: 0.55, blue: 0.75, alpha: 0.25)
        caustics.geometry?.firstMaterial?.isDoubleSided = true
        scene.rootNode.addChildNode(caustics)
        // Gentle light rays from above
        let rays = SCNNode()
        rays.light = SCNLight()
        rays.light?.type = .spot
        rays.light?.intensity = 400
        rays.light?.color = UIColor(red: 0.6, green: 0.9, blue: 1.0, alpha: 1)
        rays.light?.spotInnerAngle = 20
        rays.light?.spotOuterAngle = 60
        rays.position = SCNVector3(0, 1500, 0)
        rays.eulerAngles = SCNVector3(-.pi / 2, 0, 0)
        scene.rootNode.addChildNode(rays)
    }
}

// MARK: - SceneKit UIViewRepresentable

struct SceneKitView: UIViewRepresentable {
    let scene: SCNScene
    let flightVM: FlightViewModel
    let onUpdate: (TimeInterval) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onUpdate: onUpdate) }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.delegate = context.coordinator
        scnView.isPlaying = true
        scnView.showsStatistics = false
        scnView.preferredFramesPerSecond = 60
        scnView.antialiasingMode = .multisampling2X
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var onUpdate: ((TimeInterval) -> Void)?
        init(onUpdate: @escaping (TimeInterval) -> Void) { self.onUpdate = onUpdate }
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            DispatchQueue.main.async { [weak self] in
                self?.onUpdate?(time)
            }
        }
    }
}
