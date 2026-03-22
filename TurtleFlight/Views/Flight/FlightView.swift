import SwiftUI
import SceneKit

struct FlightView: View {
    @ObservedObject var flightVM: FlightViewModel
    @ObservedObject var missionVM: MissionViewModel
    let character: CharacterType
    let vehicle: VehicleType
    let flightMode: FlightMode

    @Environment(\.dismiss) private var dismiss
    @State private var scene = SCNScene()
    @State private var lastUpdateTime: TimeInterval = 0

    var body: some View {
        ZStack {
            // SceneKit 3D View
            SceneKitView(
                scene: scene,
                flightVM: flightVM,
                onUpdate: { time in
                    let delta = lastUpdateTime == 0 ? 0.016 : Float(time - lastUpdateTime)
                    lastUpdateTime = time
                    flightVM.update(deltaTime: min(delta, 0.05))
                }
            )
            .ignoresSafeArea()

            // HUD Overlay
            HUDOverlay(flightVM: flightVM)

            // Mission HUD (Step Goal mode only)
            if flightMode == .stepGoal, let engine = flightVM.missionEngine {
                MissionHUD(missionEngine: engine, missionVM: missionVM)
            }

            // Control Buttons
            ControlButtons(
                onBoost: { flightVM.activateBoost() },
                onFire: { flightVM.fireItem() },
                onCalibrate: { flightVM.calibrateGyro() },
                onExit: {
                    flightVM.stopFlight()
                    dismiss()
                }
            )
        }
        .onAppear {
            setupScene()
        }
        .onDisappear {
            flightVM.stopFlight()
        }
        .statusBar(hidden: true)
    }

    private func setupScene() {
        // Sky
        scene.background.contents = UIColor(
            red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0
        )

        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 600
        ambientLight.light?.color = UIColor.white
        scene.rootNode.addChildNode(ambientLight)

        // Directional light (sun)
        let sunLight = SCNNode()
        sunLight.light = SCNLight()
        sunLight.light?.type = .directional
        sunLight.light?.intensity = 800
        sunLight.light?.castsShadow = true
        sunLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sunLight)

        // Start flight
        flightVM.startFlight(scene: scene, character: character, vehicle: vehicle)

        // Start mission if Step Goal mode
        if flightMode == .stepGoal, let stage = missionVM.currentStage {
            flightVM.missionEngine?.startStage(stage)
            missionVM.startMission()
        }
    }
}

// MARK: - SceneKit UIViewRepresentable

struct SceneKitView: UIViewRepresentable {
    let scene: SCNScene
    let flightVM: FlightViewModel
    let onUpdate: (TimeInterval) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onUpdate: onUpdate)
    }

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
        let onUpdate: (TimeInterval) -> Void

        init(onUpdate: @escaping (TimeInterval) -> Void) {
            self.onUpdate = onUpdate
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            DispatchQueue.main.async {
                self.onUpdate(time)
            }
        }
    }
}
