import Foundation
import SceneKit
import AVFoundation
import Combine
import UIKit

/// THREADING MODEL — read before touching this type.
///
///   • `tick(at:)` / `update(deltaTime:)` run on the SceneKit render
///     thread, called synchronously from `SCNSceneRendererDelegate`
///     (`SceneKitView.Coordinator`). Phase 1 removed the previous
///     `DispatchQueue.main.async` hop: it cost a full frame of input
///     latency and let the simulation drift a frame behind the render.
///     SceneKit explicitly allows node mutation inside the delegate
///     callback, so physics, camera, terrain and item updates all stay on
///     the render thread.
///   • `@Published` properties are only ever written on the main thread.
///     The per-frame path collects them into a `HUDFrame` and publishes
///     through `publish(_:)`, which applies the frame immediately when
///     already on main (unit tests, previews) and otherwise coalesces
///     into a single `DispatchQueue.main.async` per render frame. Values
///     are compared at display granularity first, so a constant-speed
///     cruise produces zero publishes instead of ~500/s.
///   • UI side effects (haptics, audio, mission-terminal callbacks) go
///     through `onMain(_:)` for the same reason.
///   • `GyroController` publishes on `.main`; the render thread only
///     *reads* its inputs. That read is technically racy but benign for
///     a Double snapshot; Swift 6 strict-concurrency adoption is tracked
///     as a follow-up.
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
    /// True while a pause modal owns the screen. The flight loop's
    /// `update(deltaTime:)` early-exits when this flips on, so:
    ///   • the simulation freezes (position/heading/speed don't drift)
    ///   • the mission timer stops counting down
    ///   • boost / item buttons stop registering
    /// Gyro and audio are managed by the FlightView lifecycle (gyro stops
    /// the moment we pause; audio keeps playing under the modal so the
    /// pause overlay reads as "wait" rather than "the world died").
    @Published var isPaused: Bool = false

    // MARK: - Phase 2: gate scoring surface

    /// One gate judgement, published for the HUD callout. `id` is
    /// monotonic so SwiftUI's `onChange` fires even for two identical
    /// judgements in a row.
    struct JudgementEvent: Equatable {
        let id: Int
        let judgement: GateJudgement
        let points: Int
    }

    /// Latest gate judgement (nil until the first crossing of a run).
    @Published private(set) var judgementEvent: JudgementEvent?
    /// Running precision score for the active course.
    @Published private(set) var score: Int = 0
    /// Current combo (consecutive passes).
    @Published private(set) var combo: Int = 0
    /// True while the Expert energy model has the character stalled.
    @Published private(set) var isStalled: Bool = false

    // MARK: - Per-frame publishing

    /// Snapshot of every per-frame published value. Built on the render
    /// thread, applied on main. Compared at *display* granularity so the
    /// HUD is only invalidated when a visible digit actually changes.
    struct HUDFrame: Equatable {
        var speed: Float
        var altitude: Float
        var heading: Float
        var flightTime: TimeInterval
        var isBoosting: Bool
        var starsCollected: Int
        var boostProgress: Float
        var directionToObjective: Double?
        var currentRegion: String
        var score: Int = 0
        var combo: Int = 0
        var isStalled: Bool = false
        var judgementEvent: JudgementEvent? = nil

        /// True when the two frames would render identically on the HUD.
        func displaysSame(as other: HUDFrame) -> Bool {
            Int(speed) == Int(other.speed)
                && Int(altitude) == Int(other.altitude)
                && Int(heading) == Int(other.heading)
                && Int(flightTime) == Int(other.flightTime)
                && isBoosting == other.isBoosting
                && starsCollected == other.starsCollected
                && Int(boostProgress * 100) == Int(other.boostProgress * 100)
                && Self.quantize(directionToObjective) == Self.quantize(other.directionToObjective)
                && currentRegion == other.currentRegion
                && score == other.score
                && combo == other.combo
                && isStalled == other.isStalled
                && judgementEvent?.id == other.judgementEvent?.id
        }

        private static func quantize(_ radians: Double?) -> Int? {
            radians.map { Int($0 * 50) }   // ~1.1° buckets
        }
    }

    private var lastPublishedFrame: HUDFrame?
    /// Frame waiting to be applied on main (render-thread path only).
    private var pendingFrame: HUDFrame?
    private let pendingFrameLock = NSLock()

    /// Number of times a frame was actually pushed to the published
    /// properties. Exposed for tests / profiling.
    private(set) var publishedFrameCount: Int = 0

    /// Run `work` now if on main, else hop asynchronously. Keeps unit
    /// tests (which drive `update` from main) fully synchronous.
    func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// Publish `frame` to the `@Published` mirrors if anything visible
    /// changed since the last publish.
    private func publish(_ frame: HUDFrame) {
        if let last = lastPublishedFrame, last.displaysSame(as: frame) { return }
        lastPublishedFrame = frame
        if Thread.isMainThread {
            apply(frame)
            return
        }
        pendingFrameLock.lock()
        let hadPending = pendingFrame != nil
        pendingFrame = frame
        pendingFrameLock.unlock()
        // One hop per render frame at most: if a hop is already queued it
        // will pick up the newest pending frame.
        guard !hadPending else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingFrameLock.lock()
            let next = self.pendingFrame
            self.pendingFrame = nil
            self.pendingFrameLock.unlock()
            if let next { self.apply(next) }
        }
    }

    private func apply(_ frame: HUDFrame) {
        publishedFrameCount += 1
        if speed != frame.speed { speed = frame.speed }
        if altitude != frame.altitude { altitude = frame.altitude }
        if heading != frame.heading { heading = frame.heading }
        if flightTime != frame.flightTime { flightTime = frame.flightTime }
        if isBoosting != frame.isBoosting { isBoosting = frame.isBoosting }
        if starsCollected != frame.starsCollected { starsCollected = frame.starsCollected }
        if boostProgress != frame.boostProgress { boostProgress = frame.boostProgress }
        if directionToObjective != frame.directionToObjective {
            directionToObjective = frame.directionToObjective
        }
        if currentRegion != frame.currentRegion { currentRegion = frame.currentRegion }
        if score != frame.score { score = frame.score }
        if combo != frame.combo { combo = frame.combo }
        if isStalled != frame.isStalled { isStalled = frame.isStalled }
        if judgementEvent?.id != frame.judgementEvent?.id { judgementEvent = frame.judgementEvent }
    }

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

    /// Last observed MissionEngine state key. Used to edge-detect terminal
    /// transitions (.completed / .failed) so the FlightView can bridge them
    /// to MissionViewModel exactly once. The expression latch uses the same
    /// key shape but maintains its own copy — they're orthogonal concerns
    /// (UI/persistence vs. cosmetic facial cue).
    private var lastObservedMissionStateKey: String = "notStarted"

    /// Wall-clock time of the last collision event. Used to debounce so
    /// hugging the terrain at 60fps doesn't fire 60 collisions/sec.
    private var lastCollisionTime: TimeInterval = 0

    /// Last second-bucket the timer-countdown beep fired in. -1 means
    /// "no beep emitted yet for this run". The beep sequence (5/3/1s)
    /// only fires once per integer second, so this is reset on stage
    /// start and updated each frame the engine still has time left.
    private var lastTimerBeepBucket: Int = -1

    /// Render-thread copy of the star count. `starsCollected` (published)
    /// is a display mirror of this.
    private var simStarsCollected: Int = 0
    /// Render-thread copy of the boost request. `activateBoost()` sets it
    /// from main; the engine consumes it on the next frame.
    private var boostRequested: Bool = false
    /// Last `MissionEngine.crossingCount` we reacted to, for edge-detecting
    /// ring pass / miss events.
    private var lastSeenCrossingCount: Int = 0
    /// Render-thread copy of the latest judgement, mirrored into the
    /// published `judgementEvent` through the HUD frame.
    private var simJudgementEvent: JudgementEvent?

    // MARK: Phase 3 — ghost + quests

    /// Records the player's path during a course for the ghost replay.
    private var ghostRecorder = GhostRecorder()
    /// Ghost of the best previous run on this course, if any.
    private var ghostTrack: GhostTrack?
    private var ghostNode: SCNNode?
    /// Course key of the active special/campaign stage ("stage-2",
    /// "daily-2026-09-19"); nil in Free Flight.
    private(set) var activeCourseKey: String?
    /// Stage the recorder is tracking (for the saved ghost's metadata).
    private var activeStage: StageDefinition?
    /// Highest combo seen this run, reported to quests on completion.
    private var simMaxComboSeen: Int = 0
    /// Gate passes / bullseyes this run (Phase 4 mastery XP). Written on
    /// the render thread, read once on main at completion.
    private(set) var runGatePasses: Int = 0
    private(set) var runBullseyes: Int = 0
    /// Reusable chase-camera constraint (allocated once per flight rather
    /// than once per frame).
    private var lookAtConstraint: SCNLookAtConstraint?
    /// Render timestamp of the previous frame; 0 = no baseline yet.
    private var lastRenderTime: TimeInterval = 0

    /// Wall-clock time of the most recent free-flight star respawn.
    /// Debounces respawn so we don't dump a fresh ring every frame the
    /// pool happens to read low.
    private var lastStarSpawnTime: TimeInterval = 0

    /// Live direction (radians) from the character to the active mission
    /// ring, **relative to current heading**. 0 = straight ahead, +π/2 =
    /// 90° to the right, ±π = directly behind. Nil while no Step-Goal
    /// stage is active. Drives the objective compass arrow on MissionHUD.
    @Published private(set) var directionToObjective: Double? = nil

    /// Monotonically-increasing trigger for a one-shot HUD flash on
    /// collision. Sound + haptic already fire, but a deaf / silent-phone
    /// session needs a visible cue. The HUD overlay observes this
    /// counter via `.onChange(of:)` and runs a brief red-rim animation
    /// each time it ticks up.
    @Published private(set) var collisionFlashTrigger: Int = 0

    /// Boost progress in [0, 1]. 0 = ready (full ring), 1 = full duration
    /// boost just started. Drives the cooldown/duration ring overlaid on
    /// the boost ThumbButton.
    @Published private(set) var boostProgress: Float = 0

    /// Fired exactly once when the MissionEngine transitions to a terminal
    /// state (.completed or .failed). The FlightView wires this to
    /// `MissionViewModel.completeMission(result:)` /
    /// `failMission(reason:)` so star scores, stage progression, and the
    /// `StageResultView` overlay all actually run. Without this bridge the
    /// Step Goal mode never ends from the player's perspective.
    var onMissionTerminalState: ((MissionEngine.MissionState) -> Void)?

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

    func startFlight(scene: SCNScene,
                     character: CharacterType,
                     vehicle: VehicleType,
                     theme: MapTheme = .sky,
                     trailTier: TrailColorTier = .vehicle) {
        currentCharacter = character
        currentVehicle = vehicle
        currentMapTheme = theme

        // Push per-vehicle handling into the physics engine. This is what
        // turns "all six vehicles fly identically" into "the carrot jet
        // really does turn sharper than the cushion balloon."
        flightEngine.vehicleHandling = vehicle.handling

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
        self.lastObservedMissionStateKey = "notStarted"
        self.simStarsCollected = 0
        self.boostRequested = false
        self.lastSeenCrossingCount = 0
        self.simJudgementEvent = nil
        self.judgementEvent = nil
        self.score = 0
        self.combo = 0
        self.isStalled = false
        self.lastPublishedFrame = nil
        self.lastRenderTime = 0

        // Build per-vehicle trail emitter and attach to scene root (not the
        // billboard) so its world position can track behind the heading.
        let trailNode = SCNNode()
        let trailSystem = registry.buildTrailParticleSystem(for: vehicle)
        // Layer the cosmetic trail tier on top of the vehicle's stock
        // colour. Tiers other than `.vehicle` overwrite particleColor
        // (or, for `.rainbow`, push the colour variation up to a full
        // hue range so each particle picks its own hue).
        if let override = trailTier.overrideColor {
            trailSystem.particleColor = override
        } else if trailTier.useRainbow {
            // Full-hue variation, modest saturation/brightness wobble.
            // The vector represents the +/- variation around the base
            // HSBA values, so H = 1.0 spans the entire colour wheel.
            trailSystem.particleColor = .white
            trailSystem.particleColorVariation = SCNVector4(1.0, 0.4, 0.0, 0.0)
        }
        trailNode.addParticleSystem(trailSystem)
        trailNode.position = charNode.position
        scene.rootNode.addChildNode(trailNode)
        self.trailEmitterNode = trailNode
        self.trailParticleSystem = trailSystem
        self.baseTrailBirthRate = CharacterRegistry.trailParameters(for: vehicle).baseBirthRate

        // Setup camera. Field of view is driven dynamically in
        // updateCamera() so boost-progress can punch it; this is the
        // resting value that idle (non-boosting) flight reads at.
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zFar = 5000
        camera.camera?.fieldOfView = Constants.Camera.fieldOfView
        scene.rootNode.addChildNode(camera)
        self.cameraNode = camera
        let lookAt = SCNLookAtConstraint(target: charNode)
        lookAt.isGimbalLockEnabled = true
        camera.constraints = [lookAt]
        self.lookAtConstraint = lookAt

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
        QuestTracker.shared.record(.flightStarted(character: character))
        Analytics.shared.track(.flightStarted, [
            "character": character.rawValue,
            "vehicle": vehicle.rawValue,
            "theme": theme.rawValue,
            "sensitivity": effectiveSensitivity.rawValue
        ])

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
        // Drop the Step-Goal-only published values so a follow-up Free
        // Flight doesn't read stale objective indicators.
        directionToObjective = nil
        boostProgress = 0
        lastTimerBeepBucket = -1
        lastPublishedFrame = nil
        lookAtConstraint = nil
        lastRenderTime = 0
        tearDownGhost()
        activeCourseKey = nil
        activeStage = nil
    }

    /// Start a Step-Goal stage with terrain-aware ring clamping. Wrapper
    /// that supplies `MissionEngine.startStage` with a height function
    /// so rings can't spawn inside the terrain (Stage 3 regression) and
    /// Stage 4's procedural mountain pillars sit on the actual ground.
    /// Resets the per-stage beep bucket so the 5/3/1s countdown chimes
    /// don't carry over from the previous run.
    func startStage(_ stage: StageDefinition) {
        lastTimerBeepBucket = -1
        missionEngine?.startStage(stage) { [weak self] x, z in
            self?.terrainGenerator?.heightAt(x: x, z: z) ?? 0
        }
        // Ghost: load the best previous run on this course and start
        // recording this one. Endless courses have no fixed layout, so
        // no ghost there.
        activeStage = stage
        activeCourseKey = Self.courseKey(for: stage)
        ghostRecorder.reset()
        simMaxComboSeen = 0
        runGatePasses = 0
        runBullseyes = 0
        tearDownGhost()
        if let key = activeCourseKey, !stage.isEndless,
           let track = GhostStore.shared.load(courseKey: key), !track.isEmpty {
            ghostTrack = track
            if let scene = characterNode?.parent {
                let node = CharacterRegistry.shared.buildInflightBillboard(for: track.character)
                node.opacity = 0.35
                node.name = "ghost"
                node.position = track.position(at: 0) ?? SCNVector3(0, 500, 0)
                scene.addChildNode(node)
                ghostNode = node
            }
        }
    }

    /// Stable key for ghost storage. Daily runs key by day so tomorrow's
    /// course never races yesterday's ghost.
    static func courseKey(for stage: StageDefinition) -> String {
        if stage.isDailyRun { return "daily-" + DailyRun.key(for: Date()) }
        if stage.isEndless { return "endless" }
        return "stage-\(stage.index)"
    }

    private func tearDownGhost() {
        ghostNode?.removeFromParentNode()
        ghostNode = nil
        ghostTrack = nil
    }

    /// Save the recorded path as the course ghost when the run beat the
    /// stored one. Called from the terminal-state bridge on completion.
    private func commitGhost(result: StageResult) {
        guard let key = activeCourseKey, let stage = activeStage, !stage.isEndless else { return }
        let track = ghostRecorder.makeTrack(courseKey: key,
                                            score: result.score ?? 0,
                                            completionTime: result.completionTime,
                                            character: currentCharacter)
        GhostStore.shared.saveIfBetter(track)
    }

    // MARK: - Pause / Resume

    /// Pause the simulation. Idempotent. Stops the gyro so phones held
    /// "for a sec" while the modal is up don't drift the neutral baseline.
    /// Audio keeps playing — the BGM under a pause modal reads as ambient,
    /// while a sudden silence would feel like a crash.
    func pauseFlight() {
        guard isFlying, !isPaused else { return }
        isPaused = true
        gyroController.stop()
        lastRenderTime = 0
    }

    /// Resume from pause. Idempotent. Recalibrates the gyro to the
    /// device's current pose so a phone that drifted during the modal
    /// doesn't surprise the player with a hard turn on resume.
    func resumeFlight() {
        guard isFlying, isPaused else { return }
        isPaused = false
        gyroController.start()
        gyroController.calibrate()
        lastRenderTime = 0
    }

    /// Restart the current flight in place. The character respawns at
    /// the start position; if a stage is active, its rings spawn fresh.
    func restartFlight() {
        guard isFlying, let charNode = characterNode else { return }
        // Reset character position + flight state.
        charNode.position = SCNVector3(0, 500, 0)
        flightEngine.reset()
        speed = 0
        altitude = 500
        heading = 0
        flightTime = 0
        starsCollected = 0
        simStarsCollected = 0
        isBoosting = false
        boostRequested = false
        lastSeenCrossingCount = 0
        simJudgementEvent = nil
        judgementEvent = nil
        score = 0
        combo = 0
        isStalled = false
        lastPublishedFrame = nil
        lastRenderTime = 0
        // Reset mission-transition observer so a Retry's terminal state
        // re-fires the bridge (the key was last "completed"/"failed" if the
        // player came from a result screen).
        lastObservedMissionStateKey = "notStarted"
        expressionLatch.reset()
        // If we were paused, drop the modal too.
        isPaused = false
        gyroController.start()
        gyroController.calibrate()
    }

    /// Render-thread entry point. Converts the renderer's absolute time
    /// into a clamped delta and runs one simulation step. The first frame
    /// after a start / pause / resume only establishes the baseline.
    func tick(at time: TimeInterval) {
        guard lastRenderTime != 0 else {
            lastRenderTime = time
            return
        }
        let delta = Float(time - lastRenderTime)
        lastRenderTime = time
        // Clamp for tab-switch / debugger pause spikes.
        update(deltaTime: min(max(delta, 0), 0.05))
    }

    /// Main update loop — one simulation step. Called from `tick(at:)` on
    /// the render thread, or directly by tests on main.
    func update(deltaTime: Float) {
        guard isFlying else { return }
        // Pause modal frozen the simulation. Skip the entire frame so
        // position/heading/speed don't drift and the mission timer
        // doesn't tick down.
        guard !isPaused else { return }

        // Update flight physics. `boostRequested` is a one-shot flag set
        // by activateBoost(); the engine ignores it while a boost is
        // already running, so consuming it here is safe.
        let wantsBoost = boostRequested
        boostRequested = false
        flightEngine.update(
            deltaTime: deltaTime,
            rollInput: gyroController.rollInput,
            pitchInput: gyroController.pitchInput,
            isBoosting: wantsBoost,
            shouldAutoLevel: gyroController.shouldAutoLevel
        )

        let flightState = flightEngine.state

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
            simStarsCollected += collected
            if collected > 0 {
                onMain { AudioManager.shared.playStarCollect() }
            }
            for _ in 0..<collected {
                missionEngine?.registerStarCollected()
                flightEngine.registerStarCollected()   // refills the boost gauge
            }
            if collected > 0 {
                QuestTracker.shared.record(.starsCollected(collected))
            }
        }
        itemSystem?.updateStarAnimations(deltaTime: deltaTime)
        itemSystem?.updateProjectiles(deltaTime: deltaTime)

        // Ground-clearance collision check. Runs BEFORE the mission update
        // so the registered collision is already counted when the engine
        // tallies stars on the same frame the final ring is passed. Only
        // active during Step Goal — Free Flight has no collision metric.
        if let pos = characterNode?.position {
            checkGroundCollision(at: pos)
        }

        // Update mission
        if let pos = characterNode?.position {
            missionEngine?.update(deltaTime: deltaTime, playerPosition: pos)
        }
        observeRingCrossings()

        // Ghost: record this run, replay the stored one, both keyed on
        // the mission clock so a pause freezes both.
        if let engine = missionEngine, case .inProgress = engine.state,
           let pos = characterNode?.position {
            let t = Float(engine.elapsedTime)
            ghostRecorder.record(time: t, position: pos)
            if let track = ghostTrack, let node = ghostNode, let ghostPos = track.position(at: t) {
                node.position = ghostPos
            }
        }

        // Edge-detect mission terminal-state transitions and emit exactly one
        // event per transition. Without this bridge the MissionViewModel
        // stays at .playing forever — StageResultView never appears, star
        // scores never persist, and Stage 2+ never unlocks. The same key
        // shape feeds the cosmetic ExpressionLatch above; we keep a separate
        // copy here because the lifecycle concerns (UI flow, persistence)
        // are independent of the facial cue.
        observeMissionTerminalTransition()

        // Audio: timer countdown beep buckets (5s / 3s / 1s) and star
        // respawn for endless Free Flight runs.
        emitTimerCountdownBeepIfNeeded()
        respawnStarsIfDepleted()

        // Collect every per-frame published value into one frame and
        // publish it (coalesced, display-granular — see `publish`).
        let frame = HUDFrame(
            speed: flightState.speed,
            altitude: flightState.altitude,
            heading: flightState.heading,
            flightTime: flightState.flightTime,
            isBoosting: flightState.isBoosting,
            starsCollected: simStarsCollected,
            boostProgress: computeBoostProgress(flightState: flightState),
            directionToObjective: computeObjectiveDirection(flightState: flightState),
            currentRegion: computeRegionName(),
            score: missionEngine?.score.points ?? 0,
            combo: missionEngine?.score.combo ?? 0,
            isStalled: flightState.isStalled,
            judgementEvent: simJudgementEvent
        )
        publish(frame)
    }

    /// Edge-detect ring plane crossings from the mission engine and turn
    /// them into audio + analytics. The engine keeps a monotonic
    /// `crossingCount`; we react once per increment.
    private func observeRingCrossings() {
        guard let engine = missionEngine,
              engine.crossingCount != lastSeenCrossingCount,
              let crossing = engine.lastCrossing
        else { return }
        lastSeenCrossingCount = engine.crossingCount
        let judgement = engine.lastJudgement ?? GateScoring.judge(accuracy: crossing.accuracy)
        simJudgementEvent = JudgementEvent(id: engine.crossingCount,
                                           judgement: judgement,
                                           points: engine.lastPointsEarned)
        if crossing.isPass {
            QuestTracker.shared.record(.gatePassed)
            if judgement == .bullseye { QuestTracker.shared.record(.bullseye) }
            runGatePasses += 1
            if judgement == .bullseye { runBullseyes += 1 }
            simMaxComboSeen = max(simMaxComboSeen, engine.score.combo)
            onMain {
                AudioManager.shared.playRingPass()
                if judgement == .bullseye {
                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                    generator.impactOccurred()
                }
            }
            Analytics.shared.track(.ringPassed, [
                "ring": crossing.ringIndex,
                "accuracy": Double(crossing.accuracy),
                "judgement": judgement.rawValue,
                "combo": engine.score.combo
            ])
        } else {
            onMain {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }
            Analytics.shared.track(.ringMissed, [
                "ring": crossing.ringIndex,
                "accuracy": Double(crossing.accuracy)
            ])
        }
    }

    /// Direction to the active mission's current ring, relative to the
    /// heading. Nil when there's no in-progress mission, so the HUD can
    /// hide the arrow during Free Flight.
    private func computeObjectiveDirection(flightState: FlightEngine.FlightState) -> Double? {
        guard let engine = missionEngine,
              case .inProgress = engine.state,
              let ringPos = engine.currentRingPosition
        else {
            return nil
        }
        let pos = flightState.position
        let dx = ringPos.x - pos.x
        let dz = ringPos.z - pos.z
        // heading 0 = facing -Z (north). atan2(dx, -dz) maps that to 0.
        let angleToRing = atan2(dx, -dz)
        let headingRad = Double(flightState.heading).rad
        var relative = Double(angleToRing) - headingRad
        // Normalise to [-π, π] so the SwiftUI rotationEffect always picks
        // the short way around.
        while relative > .pi  { relative -= 2 * .pi }
        while relative < -.pi { relative += 2 * .pi }
        return relative
    }

    /// Boost ring value (0…1). While boosting it is the remaining
    /// fraction of the burst; otherwise it is the gauge charge, so the
    /// ring visibly refills from stars and reads "ready" when full.
    private func computeBoostProgress(flightState: FlightEngine.FlightState) -> Float {
        if flightState.isBoosting {
            let dur = Float(Constants.Flight.boostDuration)
            guard dur > 0 else { return 0 }
            return max(0, min(1, flightState.boostTimeRemaining / dur))
        }
        return max(0, min(1, flightState.boostCharge))
    }

    /// Fire a one-shot countdown chirp on the integer-second boundary
    /// when there are 5, 3, or 1 seconds left. Idempotent across frames
    /// thanks to `lastTimerBeepBucket` — the same second never beeps twice.
    private func emitTimerCountdownBeepIfNeeded() {
        guard let remaining = missionEngine?.remainingTime, remaining > 0 else {
            return
        }
        let bucket = Int(ceil(remaining))
        let triggers: Set<Int> = [5, 3, 1]
        guard triggers.contains(bucket), bucket != lastTimerBeepBucket else {
            return
        }
        lastTimerBeepBucket = bucket
        onMain { AudioManager.shared.playTimerTick() }
    }

    /// Refill the star pool when only a handful of uncollected stars
    /// remain. Without this, Free Flight runs become star-deserts after
    /// the player picks up the initial 10. Debounced via
    /// `Constants.Items.starRespawnCooldown`.
    private func respawnStarsIfDepleted() {
        guard let items = itemSystem,
              let pos = characterNode?.position,
              items.uncollectedStarCount < Constants.Items.starRespawnThreshold
        else { return }
        let now = CACurrentMediaTime()
        guard now - lastStarSpawnTime > Constants.Items.starRespawnCooldown else {
            return
        }
        lastStarSpawnTime = now
        items.spawnStars(around: pos)
    }

    /// Edge-detect MissionEngine state transitions; fire `onMissionTerminalState`
    /// exactly once when the engine flips into `.completed` or `.failed`.
    /// Idempotent across frames: repeated frames in the same terminal state
    /// don't re-fire because the key only updates on transition.
    private func observeMissionTerminalTransition() {
        let key = Self.missionStateKey(missionEngine?.state)
        guard Self.shouldEmitMissionTerminalEvent(currentKey: key,
                                                   lastKey: lastObservedMissionStateKey) else {
            // Always advance the stored key — even on a non-terminal change
            // (e.g. inProgress→inProgress is the common case, but we also
            // need to drop the latch when leaving a terminal back to
            // notStarted/inProgress so a Retry re-arms.)
            lastObservedMissionStateKey = key
            return
        }
        lastObservedMissionStateKey = key
        guard let state = missionEngine?.state else { return }
        switch state {
        case .completed(let result):
            commitGhost(result: result)
            // MissionViewModel mutates @Published state in response, so
            // the callback must land on main. Synchronous when already
            // there (tests), async from the render thread.
            onMain { [weak self] in self?.onMissionTerminalState?(state) }
        case .failed:
            onMain { [weak self] in self?.onMissionTerminalState?(state) }
        case .notStarted, .inProgress:
            break
        }
    }

    /// Pure decision: given the engine's current state-key and the key we
    /// last observed, should we fire `onMissionTerminalState` this frame?
    /// Extracted as a static helper so unit tests can pin the edge-
    /// detection without spinning up a full SceneKit scene + gyro stack.
    static func shouldEmitMissionTerminalEvent(currentKey: String,
                                                lastKey: String) -> Bool {
        guard currentKey != lastKey else { return false }
        return currentKey == "completed" || currentKey == "failed"
    }

    /// Register a collision when the character flies dangerously close to
    /// the terrain mesh. Debounced via `Constants.Collision.cooldown` so a
    /// flat hilltop doesn't tally 60 hits/sec. Only counts during an active
    /// mission — Free Flight has no collision metric to feed.
    ///
    /// Why ground-clearance and not full physics? FlightEngine clamps
    /// altitude at the profile's `minAltitude` (50/20/5m), but terrain can
    /// rise to 300m. The intuitive failure mode "I just clipped a mountain"
    /// is exactly what this function tracks. A future PR can layer NPC /
    /// ring-rim brush detection on top.
    private func checkGroundCollision(at pos: SCNVector3) {
        guard let engine = missionEngine,
              case .inProgress = engine.state,
              let terrain = terrainGenerator
        else { return }
        let groundHeight = terrain.heightAt(x: pos.x, z: pos.z)
        let clearance = pos.y - groundHeight
        let now = CACurrentMediaTime()
        guard Self.shouldRegisterCollision(clearance: clearance,
                                            now: now,
                                            lastCollisionTime: lastCollisionTime) else {
            return
        }
        lastCollisionTime = now
        engine.registerCollision()
        onMain { [weak self] in
            guard let self else { return }
            // Heavy haptic + dedicated collision thump so the player feels
            // the brush. Synth-generated, so no asset cost.
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            AudioManager.shared.playCollision()
            // Tick the visible-flash counter so the HUD overlay can flash
            // a red rim. Pairs the haptic+sound with a visual cue so
            // players on silent or hard-of-hearing still see it.
            self.collisionFlashTrigger &+= 1
        }
    }

    /// Pure decision: should a collision be registered given the current
    /// clearance and the wall-clock gap since the last collision? Used by
    /// `checkGroundCollision` and exercised directly by tests so the
    /// debounce + threshold logic is pinned without needing a SCNScene.
    static func shouldRegisterCollision(clearance: Float,
                                         now: TimeInterval,
                                         lastCollisionTime: TimeInterval) -> Bool {
        guard clearance < Constants.Collision.groundClearance else { return false }
        return now - lastCollisionTime > Constants.Collision.cooldown
    }

    // MARK: - Actions

    func activateBoost() {
        // The engine only honours the request with a full gauge; don't
        // play the whoosh (or flip the mirror) for a tap that can't fire.
        guard flightEngine.canBoost else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        boostRequested = true
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

        // Read the simulation state directly — the published `heading` /
        // `boostProgress` mirrors are display-granular and main-thread
        // only, so they may lag the render thread by a frame.
        let flightState = flightEngine.state
        let headingRad = flightState.heading.rad
        // Boost-modulated follow distance + FOV. Pulling the camera back
        // 3m and widening the FOV 8° while the speed is doubled keeps
        // the character's apparent on-screen size roughly constant and
        // gives the acceleration a perspective punch that "speed = 2x
        // bigger number" alone never delivers. Reduce-Motion users
        // get the resting frame instead — the punch is exactly the
        // kind of camera oscillation that's vestibular-uncomfortable.
        let boost: Float = reduceMotionEnabled ? 0 : computeBoostProgress(flightState: flightState)
        let dist = Constants.Camera.followDistance
            + Constants.Camera.boostFollowDistanceDelta * boost
        let height = Constants.Camera.followHeight
        let targetFOV = Constants.Camera.fieldOfView
            + Constants.Camera.boostFOVDelta * CGFloat(boost)
        // SCNCamera.fieldOfView is animated implicitly by SCNTransaction
        // when assigned each frame, so the change reads as a smooth
        // lerp instead of a snap.
        camNode.camera?.fieldOfView = targetFOV

        // Target camera position: behind and above character
        let targetX = charNode.position.x - sin(headingRad) * dist
        let targetY = charNode.position.y + height
        let targetZ = charNode.position.z + cos(headingRad) * dist

        let targetPos = SCNVector3(targetX, targetY, targetZ)

        // Camera lerp speed. With Reduce Motion enabled, slow the lerp
        // so the chase camera glides instead of snapping — small reduces
        // visual swing during turns, which the spec calls out as a
        // motion-sickness mitigation. The factor (0.45×) was picked so
        // rapid-fire turns still feel responsive but oscillation is
        // damped.
        let baseSpeed = Constants.Camera.lerpSpeed
        let t = reduceMotionEnabled ? baseSpeed * 0.45 : baseSpeed
        camNode.position = SCNVector3.lerp(camNode.position, targetPos, t: t)

        // Look at character. The constraint is created once in
        // startFlight and reused; only its influence changes with the
        // Reduce Motion setting (slackened so the camera doesn't jerk
        // toward the character during sharp banks).
        if lookAtConstraint == nil {
            let lookAt = SCNLookAtConstraint(target: charNode)
            lookAt.isGimbalLockEnabled = true
            camNode.constraints = [lookAt]
            lookAtConstraint = lookAt
        }
        let influence: CGFloat = reduceMotionEnabled ? 0.5 : 0.9
        if lookAtConstraint?.influenceFactor != influence {
            lookAtConstraint?.influenceFactor = influence
        }
    }

    private func computeRegionName() -> String {
        guard let pos = characterNode?.position else { return currentRegion }
        let names = currentMapTheme.regionNames
        guard !names.isEmpty else { return "" }
        let regionIndex = abs(Int(pos.x / 500) + Int(pos.z / 500) * 7) % names.count
        return names[regionIndex]
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
