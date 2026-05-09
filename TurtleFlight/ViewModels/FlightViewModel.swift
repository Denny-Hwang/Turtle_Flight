import Foundation
import SceneKit
import AVFoundation
import Combine
import UIKit

final class FlightViewModel: ObservableObject {
    // MARK: - Published State
    @Published var speed: Float = 0
    @Published var altitude: Float = 500
    @Published var heading: Float = 0
    @Published var flightTime: TimeInterval = 0
    @Published var starsCollected: Int = 0
    @Published var isBoosting: Bool = false
    @Published var currentRegion: String = ""
    @Published var isFlying: Bool = false

    // MARK: - Components
    let flightEngine: FlightEngine
    let gyroController: GyroController
    let characterAnimator = CharacterAnimator()
    var terrainGenerator: TerrainGenerator?
    var itemSystem: ItemSystem?
    var missionEngine: MissionEngine?

    // MARK: - Scene Nodes
    /// In-flight billboard: a single SCNPlane textured with the character's
    /// expression atlas (see `CharacterRegistry.buildInflightBillboard`).
    /// Replaces the previous (charNode + vehNode) primitive pair.
    var characterNode: SCNNode?
    /// Retained `nil` for the in-flight scene because the vehicle is baked
    /// into the atlas. Selection-screen vehicle previews use a separate path
    /// (`Image("…_vehicle_only")`). Kept as a stored property for backwards
    /// compatibility with code paths that probed it; new code should not
    /// rely on it being non-nil during flight.
    var vehicleNode: SCNNode?
    var cameraNode: SCNNode?

    /// Last-applied expression — used to skip redundant per-frame UV
    /// transitions when the latched / boost / idle state hasn't flipped.
    private var lastDisplayedExpression: CharacterExpression = .default

    /// Pure state-machine that decides which expression to show each frame
    /// (latched joy/scared > speed > default). See ExpressionLatch.swift.
    private var expressionLatch = ExpressionLatch()

    // MARK: - Trail emitter
    /// Empty SCNNode that sits ~1.2 world units behind the character along
    /// its heading; the per-vehicle trail particle system is attached here.
    /// Lives in scene root (not as a child of the billboard) so its world
    /// position is independent of the billboard's camera-facing constraint.
    private var trailEmitterNode: SCNNode?
    private var trailParticleSystem: SCNParticleSystem?
    /// Captured at startFlight from the per-vehicle TrailParameters; used
    /// each frame to decide the boost-modulated birth rate without
    /// re-fetching the parameter table.
    private var baseTrailBirthRate: CGFloat = 0

    // MARK: - Character Info
    var currentCharacter: CharacterType = .turtle
    var currentVehicle: VehicleType = .shellJet
    var currentMapTheme: MapTheme = .sky

    // MARK: - Sensitivity
    /// User's preferred sensitivity (persisted). When Reduce Motion is on,
    /// the engines run with `effectiveSensitivity` clamped to .easy, but
    /// this stored choice is preserved so the user gets it back when they
    /// disable Reduce Motion.
    @Published var sensitivityLevel: SensitivityLevel = .easy {
        didSet {
            applyEffectiveSensitivity()
            save()
        }
    }

    /// True when iOS Reduce Motion is enabled. We mirror it as @Published
    /// so SwiftUI can show an info indicator if desired.
    @Published private(set) var reduceMotionEnabled: Bool = false

    /// What's actually fed into the gyro/flight engines.
    var effectiveSensitivity: SensitivityLevel {
        reduceMotionEnabled ? .easy : sensitivityLevel
    }

    private var reduceMotionObserver: NSObjectProtocol?

    // MARK: - Init
    init() {
        flightEngine = FlightEngine()
        gyroController = GyroController()
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        reduceMotionObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            self.applyEffectiveSensitivity()
        }
        applyEffectiveSensitivity()
    }

    deinit {
        if let token = reduceMotionObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    private func applyEffectiveSensitivity() {
        let level = effectiveSensitivity
        gyroController.updateSensitivity(level)
        flightEngine.updateSensitivity(level)
    }

    // MARK: - Flight Control

    func startFlight(scene: SCNScene, character: CharacterType, vehicle: VehicleType, theme: MapTheme = .sky) {
        currentCharacter = character
        currentVehicle = vehicle
        currentMapTheme = theme

        // Build the atlas-textured billboard. Vehicle is baked into the
        // flying-pose art, so a single billboard subsumes both per spec
        // (docs/CHARACTER_DESIGN_PROMPT.md §Technical Notes / 2).
        let registry = CharacterRegistry.shared
        let charNode = registry.buildInflightBillboard(for: character)

        // Place in scene
        charNode.position = SCNVector3(0, 500, 0)
        scene.rootNode.addChildNode(charNode)

        self.characterNode = charNode
        self.vehicleNode = nil
        self.lastDisplayedExpression = .default
        self.expressionLatch.reset()

        // Build per-vehicle trail emitter and attach to scene root (not the
        // billboard) so its world position can track behind the heading.
        let trailNode = SCNNode()
        let trailSystem = registry.buildTrailParticleSystem(for: vehicle)
        trailNode.addParticleSystem(trailSystem)
        trailNode.position = charNode.position
        scene.rootNode.addChildNode(trailNode)
        self.trailEmitterNode = trailNode
        self.trailParticleSystem = trailSystem
        self.baseTrailBirthRate = CharacterRegistry.trailParameters(for: vehicle).baseBirthRate

        // Setup camera
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zFar = 5000
        camera.camera?.fieldOfView = 70
        scene.rootNode.addChildNode(camera)
        self.cameraNode = camera

        // Setup terrain with selected theme
        terrainGenerator = TerrainGenerator(parentNode: scene.rootNode, seed: 42, theme: theme)
        terrainGenerator?.updateChunks(playerPosition: charNode.position)

        // Setup items
        itemSystem = ItemSystem(parentNode: scene.rootNode)
        itemSystem?.spawnStars(around: charNode.position)

        // Setup mission engine
        missionEngine = MissionEngine(parentNode: scene.rootNode)

        // Start gyro
        gyroController.start()
        isFlying = true

        // Start audio
        let audio = AudioManager.shared
        audio.startBGM(theme: theme.rawValue)
        if let def = VehicleDefinition.definition(for: vehicle) {
            audio.playVehicleSound(def.soundEffect)
        }
    }

    func stopFlight() {
        gyroController.stop()
        isFlying = false
        AudioManager.shared.stopAll()
        // Detach the trail so a stopped flight doesn't keep an emitter
        // alive in the scene tree (FlightView typically rebuilds the scene
        // anyway, but explicit cleanup keeps memory predictable on retry).
        trailEmitterNode?.removeFromParentNode()
        trailEmitterNode = nil
        trailParticleSystem = nil
        baseTrailBirthRate = 0
    }

    /// Main update loop - called every frame from SCNSceneRendererDelegate
    func update(deltaTime: Float) {
        guard isFlying else { return }

        // Update flight physics
        flightEngine.update(
            deltaTime: deltaTime,
            rollInput: gyroController.rollInput,
            pitchInput: gyroController.pitchInput,
            isBoosting: isBoosting,
            shouldAutoLevel: gyroController.shouldAutoLevel
        )

        let flightState = flightEngine.state

        // Update published state
        speed = flightState.speed
        altitude = flightState.altitude
        heading = flightState.heading
        flightTime = flightState.flightTime
        self.isBoosting = flightState.isBoosting

        // Update character position. Rotation is intentionally NOT applied
        // here: the billboard plane always faces the camera, so eulerAngles
        // on it would be a no-op. Bank/pitch feedback comes through the
        // chase-camera framing instead.
        characterNode?.position = flightState.position

        // Trail emitter sits behind the character in heading direction, so
        // particles drift away naturally as the world moves underneath. The
        // back-offset matches the ~1.2 unit gap that reads as "tail" without
        // overlapping the billboard sprite.
        if let trailNode = trailEmitterNode {
            let h = Double(flightState.heading).rad
            let backOffset: Float = 1.2
            trailNode.position = SCNVector3(
                flightState.position.x - sin(Float(h)) * backOffset,
                flightState.position.y - 0.4,
                flightState.position.z + cos(Float(h)) * backOffset
            )
            // Rotate the emitter so its local +Z (the emittingDirection)
            // aligns with the world-space "behind heading" vector
            // (-sin h, 0, +cos h). A Y-rotation of -h achieves that.
            // Particles then streak rearward, drifting away from the
            // character as it flies on.
            trailNode.eulerAngles.y = -Float(h)
        }
        if let trail = trailParticleSystem {
            characterAnimator.setTrailBoosting(
                trail,
                boosting: flightState.isBoosting,
                baseBirthRate: baseTrailBirthRate
            )
        }

        // Drive the atlas expression cell from flight state. Priority is
        // resolved by ExpressionLatch (see Core/Character/ExpressionLatch.swift):
        // latched(joy|scared) > speed > default.
        if let charNode = characterNode {
            let stateKey = Self.missionStateKey(missionEngine?.state)
            let target = expressionLatch.update(
                missionStateKey: stateKey,
                isBoosting: flightState.isBoosting,
                now: CACurrentMediaTime()
            )
            if target != lastDisplayedExpression {
                characterAnimator.setExpression(target, on: charNode)
                lastDisplayedExpression = target
            }
        }

        // Update camera (3rd person follow)
        updateCamera(deltaTime: deltaTime)

        // Update terrain chunks
        if let pos = characterNode?.position {
            terrainGenerator?.updateChunks(playerPosition: pos)
        }

        // Update items
        if let pos = characterNode?.position {
            let collected = itemSystem?.checkCollection(playerPosition: pos) ?? 0
            starsCollected += collected
            if collected > 0 {
                AudioManager.shared.playStarCollect()
            }
            for _ in 0..<collected {
                missionEngine?.registerStarCollected()
            }
        }
        itemSystem?.updateStarAnimations(deltaTime: deltaTime)
        itemSystem?.updateProjectiles(deltaTime: deltaTime)

        // Update mission
        if let pos = characterNode?.position {
            missionEngine?.update(deltaTime: deltaTime, playerPosition: pos)
        }

        // Update region name
        updateRegionName()
    }

    // MARK: - Actions

    func activateBoost() {
        isBoosting = true
        AudioManager.shared.playBoost()
    }

    func fireItem() {
        guard let pos = characterNode?.position else { return }
        let headingRad = heading.rad
        let direction = SCNVector3(sin(headingRad), 0, -cos(headingRad))
        itemSystem?.fireProjectile(from: pos, direction: direction)
    }

    func calibrateGyro() {
        gyroController.calibrate()
    }

    /// Convert a MissionEngine state into the stable string key that
    /// ExpressionLatch edge-detects on. Nil ↔ "notStarted" so Free-Flight
    /// (which has no mission engine attached) reads as a non-trigger state.
    static func missionStateKey(_ state: MissionEngine.MissionState?) -> String {
        guard let state = state else { return "notStarted" }
        switch state {
        case .notStarted:    return "notStarted"
        case .inProgress:    return "inProgress"
        case .completed:     return "completed"
        case .failed:        return "failed"
        }
    }

    // MARK: - Camera

    private func updateCamera(deltaTime: Float) {
        guard let charNode = characterNode, let camNode = cameraNode else { return }

        let headingRad = heading.rad
        let dist = Constants.Camera.followDistance
        let height = Constants.Camera.followHeight

        // Target camera position: behind and above character
        let targetX = charNode.position.x - sin(headingRad) * dist
        let targetY = charNode.position.y + height
        let targetZ = charNode.position.z + cos(headingRad) * dist

        let targetPos = SCNVector3(targetX, targetY, targetZ)

        // Smooth camera follow
        let t = Constants.Camera.lerpSpeed
        camNode.position = SCNVector3.lerp(camNode.position, targetPos, t: t)

        // Look at character
        let lookAt = SCNLookAtConstraint(target: charNode)
        lookAt.isGimbalLockEnabled = true
        lookAt.influenceFactor = 0.9
        camNode.constraints = [lookAt]
    }

    private func updateRegionName() {
        guard let pos = characterNode?.position else { return }
        let names = currentMapTheme.regionNames
        let regionIndex = abs(Int(pos.x / 500) + Int(pos.z / 500) * 7) % names.count
        let newRegion = names[regionIndex]
        if newRegion != currentRegion {
            currentRegion = newRegion
        }
    }

    // MARK: - Persistence

    func save() {
        UserDefaults.standard.set(sensitivityLevel.rawValue, forKey: "sensitivityLevel")
    }

    func load() {
        if let str = UserDefaults.standard.string(forKey: "sensitivityLevel"),
           let level = SensitivityLevel(rawValue: str) {
            sensitivityLevel = level
        }
    }
}
