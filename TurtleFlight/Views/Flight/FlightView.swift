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

    var body: some View {
        ZStack {
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

            HUDOverlay(flightVM: flightVM)

            if flightMode == .stepGoal, let engine = flightVM.missionEngine {
                MissionHUD(missionEngine: engine, missionVM: missionVM) {
                    flightVM.stopFlight()
                    dismiss()
                }
            }

            ControlButtons(
                onBoost:     { flightVM.activateBoost() },
                onFire:      { flightVM.fireItem() },
                onCalibrate: { flightVM.calibrateGyro() },
                onExit: {
                    flightVM.stopFlight()
                    dismiss()
                }
            )
        }
        .onAppear { setupScene() }
        .onDisappear { flightVM.stopFlight() }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background, .inactive:
                flightVM.gyroController.stop()
                lastUpdateTime = 0
            case .active:
                if flightVM.isFlying {
                    flightVM.gyroController.start()
                    flightVM.calibrateGyro()
                }
            @unknown default:
                break
            }
        }
        .alert("자이로스코프를 사용할 수 없습니다", isPresented: $showGyroAlert) {
            Button("확인") {
                dismiss()
            }
        } message: {
            Text("이 기기에서는 자이로 센서가 지원되지 않습니다. 자이로 센서가 있는 기기에서 플레이해 주세요.")
        }
        .statusBar(hidden: true)
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
