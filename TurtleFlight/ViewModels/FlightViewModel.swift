import Foundation
import SceneKit
import Combine

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
    var characterNode: SCNNode?
    var vehicleNode: SCNNode?
    var cameraNode: SCNNode?

    // MARK: - Character Info
    var currentCharacter: CharacterType = .turtle
    var currentVehicle: VehicleType = .shellJet

    // MARK: - Sensitivity
    @Published var sensitivityLevel: SensitivityLevel = .easy {
        didSet {
            gyroController.updateSensitivity(sensitivityLevel)
            flightEngine.updateSensitivity(sensitivityLevel)
            save()
        }
    }

    // MARK: - Init
    init() {
        flightEngine = FlightEngine()
        gyroController = GyroController()
    }

    // MARK: - Flight Control

    func startFlight(scene: SCNScene, character: CharacterType, vehicle: VehicleType) {
        currentCharacter = character
        currentVehicle = vehicle

        // Build character and vehicle nodes
        let registry = CharacterRegistry.shared
        let charNode = registry.buildCharacterNode(for: character)
        let vehNode = registry.buildVehicleNode(for: vehicle)

        // Position vehicle relative to character
        vehNode.position = SCNVector3(0, -0.3, 0)
        charNode.addChildNode(vehNode)

        // Place in scene
        charNode.position = SCNVector3(0, 500, 0)
        scene.rootNode.addChildNode(charNode)

        self.characterNode = charNode
        self.vehicleNode = vehNode

        // Setup camera
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zFar = 5000
        camera.camera?.fieldOfView = 70
        scene.rootNode.addChildNode(camera)
        self.cameraNode = camera

        // Setup terrain
        terrainGenerator = TerrainGenerator(parentNode: scene.rootNode)
        terrainGenerator?.updateChunks(playerPosition: charNode.position)

        // Setup items
        itemSystem = ItemSystem(parentNode: scene.rootNode)
        itemSystem?.spawnStars(around: charNode.position)

        // Setup mission engine
        missionEngine = MissionEngine(parentNode: scene.rootNode)

        // Start gyro
        gyroController.start()
        isFlying = true
    }

    func stopFlight() {
        gyroController.stop()
        isFlying = false
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

        // Update character position and rotation
        characterNode?.position = flightState.position
        characterNode?.eulerAngles = flightState.rotation

        // Animate character + vehicle
        if let charNode = characterNode, let vehNode = vehicleNode {
            characterAnimator.applyFlightPose(
                to: charNode,
                vehicleNode: vehNode,
                rollInput: gyroController.rollInput,
                pitchInput: gyroController.pitchInput,
                speed: speed,
                isBoosting: flightState.isBoosting,
                character: currentCharacter,
                vehicle: currentVehicle,
                deltaTime: deltaTime
            )
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
        // Simple region based on position hash
        let regionIndex = abs(Int(pos.x / 500) + Int(pos.z / 500) * 7) % Constants.regionNames.count
        let newRegion = Constants.regionNames[regionIndex]
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
