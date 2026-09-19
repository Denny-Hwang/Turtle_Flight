import Foundation
import SceneKit

final class MissionEngine {
    // MARK: - State
    enum MissionState {
        case notStarted
        case inProgress
        case completed(StageResult)
        case failed(reason: String)
    }

    // MARK: - Ring
    struct Ring {
        let node: SCNNode
        /// Rest position. For `.moving` gates the live centre oscillates
        /// around this; use `center(at:)` for the hit test.
        let position: SCNVector3
        /// Nominal radius. `effectiveRadius(at:comboFactor:)` applies the
        /// shrink dynamics.
        let radius: Float
        /// Unit vector the player is expected to travel along when
        /// flying through this ring. The ring's plane is perpendicular
        /// to it. Horizontal by construction (see `CourseGenerator.normals`).
        let normal: SCNVector3
        var kind: GateKind = .standard
        var isPassed: Bool = false
        /// Stage time at which this ring became the target. Drives the
        /// shrinking gate's countdown. Nil until targeted.
        var targetedAt: TimeInterval? = nil

        /// Horizontal unit vector across the ring's plane (to the
        /// player's right when flying through).
        var sideAxis: SCNVector3 { SCNVector3(-normal.z, 0, normal.x) }

        /// Live centre at stage time `t`.
        func center(at t: TimeInterval) -> SCNVector3 {
            guard case .moving(let axis, let amplitude, let period) = kind,
                  period > 0 else { return position }
            let phase = Float(t) * (2 * Float.pi) / period
            let offset = sin(phase) * amplitude
            switch axis {
            case .lateral:  return position + sideAxis * offset
            case .vertical: return SCNVector3(position.x, position.y + offset, position.z)
            }
        }

        /// Scale factor from the shrinking dynamics at stage time `t`
        /// (1 = nominal). Multiplied by the combo factor by the engine.
        func shrinkScale(at t: TimeInterval) -> Float {
            guard case .shrinking(let minScale, let duration) = kind,
                  let since = targetedAt, duration > 0 else { return 1 }
            let progress = Float(max(0, t - since)) / duration
            return max(minScale, 1 - (1 - minScale) * min(progress, 1))
        }

        /// Radius the hit test uses at stage time `t`.
        func effectiveRadius(at t: TimeInterval, comboFactor: Float) -> Float {
            radius * shrinkScale(at: t) * comboFactor
        }
    }

    /// Emitted when the player's path crosses a ring's plane. `accuracy`
    /// is the radial distance from the ring centre at the crossing point,
    /// normalised by the ring radius: 0 = dead centre, 1 = the rim,
    /// > 1 = crossed the plane *outside* the ring (a miss).
    struct RingCrossing: Equatable {
        let ringIndex: Int
        let accuracy: Float
        let hitPoint: SCNVector3
        var isPass: Bool { accuracy <= 1 }

        static func == (lhs: RingCrossing, rhs: RingCrossing) -> Bool {
            lhs.ringIndex == rhs.ringIndex
                && lhs.accuracy == rhs.accuracy
                && lhs.hitPoint.x == rhs.hitPoint.x
                && lhs.hitPoint.y == rhs.hitPoint.y
                && lhs.hitPoint.z == rhs.hitPoint.z
        }
    }

    /// A crossing outside the ring only counts as a *miss* (rather than
    /// "flew somewhere else entirely") when it lands within this many
    /// radii of the centre. Beyond that the player wasn't attempting the
    /// ring and shouldn't be penalised for it.
    static let missAttemptRadiusMultiplier: Float = 3

    // MARK: - Properties
    private(set) var state: MissionState = .notStarted
    private(set) var currentStage: StageDefinition?
    private(set) var rings: [Ring] = []
    private(set) var currentRingIndex: Int = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var collisions: Int = 0
    private(set) var starsCollected: Int = 0
    /// Decoration nodes attached to the scene during a stage (Stage 4
    /// mountain pillars, etc.). Tracked separately so `clearRings()` can
    /// tear them down without scanning the scene graph.
    private(set) var decorations: [SCNNode] = []
    private let parentNode: SCNNode

    /// Player position from the previous `update` call. Plane-crossing
    /// needs a segment, not a point; nil until the first frame of a stage.
    private var prevPlayerPosition: SCNVector3?
    /// Most recent plane crossing of the *target* ring (pass or miss).
    /// Consumers edge-detect on this (compare to what they last saw).
    private(set) var lastCrossing: RingCrossing?
    /// Monotonic counter of crossings so a consumer can cheaply detect a
    /// new event even when two crossings produce identical payloads.
    private(set) var crossingCount: Int = 0
    /// Number of near-misses (plane crossed inside the attempt window but
    /// outside the ring) during the current stage.
    private(set) var ringMisses: Int = 0
    /// Precision score for the current attempt (Phase 2).
    private(set) var score = RunScore()
    /// Judgement of the most recent crossing; pairs with `crossingCount`.
    private(set) var lastJudgement: GateJudgement?
    /// Points the most recent crossing earned.
    private(set) var lastPointsEarned: Int = 0

    /// Per-step radius reduction while `comboShrink` is on, and its floor.
    static let comboShrinkPerStep: Float = 0.04
    static let comboShrinkFloor: Float = 0.6

    /// Radius factor from the current combo when the stage's course has
    /// `comboShrink` enabled; 1 otherwise.
    var comboRadiusFactor: Float {
        guard currentStage?.course.comboShrink == true else { return 1 }
        return max(Self.comboShrinkFloor, 1 - Float(score.combo) * Self.comboShrinkPerStep)
    }

    /// Radius the target ring is currently judged against, or nil when no
    /// ring is targeted. HUD / tests read this.
    var currentEffectiveRadius: Float? {
        guard currentRingIndex < rings.count else { return nil }
        return rings[currentRingIndex].effectiveRadius(at: elapsedTime, comboFactor: comboRadiusFactor)
    }

    /// World-space position of the ring the player is currently chasing,
    /// or nil when the stage is over (or hasn't started). Drives the
    /// objective compass arrow on `MissionHUD`.
    var currentRingPosition: SCNVector3? {
        guard currentRingIndex < rings.count else { return nil }
        return rings[currentRingIndex].center(at: elapsedTime)
    }

    init(parentNode: SCNNode) {
        self.parentNode = parentNode
    }

    // MARK: - Public Methods

    /// Start a stage. If `terrainHeightAt` is supplied, ring positions are
    /// clamped to be at least `ringRadius + 20m` above the terrain mesh
    /// at their (x, z) — fixes the Valley Run regression where the
    /// procedural y of 100-200m could spawn rings inside hills (terrain
    /// max height is 300m). Stage 4 ("Mountain Cross") additionally gets
    /// procedural mountain-pillar decorations rooted at the terrain
    /// surface and rising up to the ring — closes the spec gap where
    /// the named "산봉우리" had no actual peaks.
    func startStage(_ stage: StageDefinition,
                    terrainHeightAt: ((Float, Float) -> Float)? = nil) {
        currentStage = stage
        currentRingIndex = 0
        elapsedTime = 0
        collisions = 0
        starsCollected = 0
        prevPlayerPosition = nil
        lastCrossing = nil
        crossingCount = 0
        ringMisses = 0
        score = RunScore()
        lastJudgement = nil
        lastPointsEarned = 0
        state = .inProgress

        // Clear previous rings + decorations
        clearRings()

        // Generate rings, clamping each above the terrain when we have
        // a height query function. The clearance buffer (ringRadius + 20)
        // is intentional: a bare radius would let the player skim the
        // terrain *as they pass through* — we want the ring to read as
        // air-suspended, not embedded.
        let positions = stage.generateRings()
        let normals = CourseGenerator.normals(for: positions)
        let kinds = stage.course.gateKinds
        for (i, pos) in positions.enumerated() {
            let safePos: SCNVector3 = {
                guard let heightFn = terrainHeightAt else { return pos }
                let groundY = heightFn(pos.x, pos.z)
                let minRingY = groundY + stage.ringRadius + 20
                return SCNVector3(pos.x, max(pos.y, minRingY), pos.z)
            }()
            let normal = normals[i]
            let kind = i < kinds.count ? kinds[i] : .standard
            let ringNode = createRingNode(radius: stage.ringRadius, index: i, kind: kind)
            ringNode.position = safePos
            // Face the torus along the course direction so the plane the
            // player has to cross visually matches the plane we test.
            ringNode.eulerAngles.y = atan2(normal.x, normal.z)
            parentNode.addChildNode(ringNode)
            rings.append(Ring(node: ringNode, position: safePos,
                              radius: stage.ringRadius, normal: normal, kind: kind))

            // Stage 4 ("Mountain Cross"): drop a low-poly mountain pillar
            // anchored to the terrain rising up to the ring's underside.
            // The peak floor is the terrain (so even when no height fn
            // was supplied, the pillar starts at y=0 and is harmless).
            if stage.index == 3 {
                let groundY = terrainHeightAt?(safePos.x, safePos.z) ?? 0
                let mountain = Self.makeMountainPillar(
                    base: SCNVector3(safePos.x, groundY, safePos.z),
                    peakY: safePos.y - stage.ringRadius
                )
                parentNode.addChildNode(mountain)
                decorations.append(mountain)
            }
        }

        // Highlight first ring
        highlightRing(at: 0)
    }

    func update(deltaTime: Float, playerPosition: SCNVector3) {
        guard case .inProgress = state, let stage = currentStage else { return }

        elapsedTime += Double(deltaTime)

        // Check time limit
        if let timeLimit = stage.timeLimit, elapsedTime >= timeLimit {
            state = .failed(reason: L10n.t("mission.fail.timeout"))
            return
        }

        // Check ring passage
        guard currentRingIndex < rings.count else { return }

        // Plane-crossing test against the segment prev → current. The
        // old sphere-distance check counted a pass whenever the player
        // came within `radius` of the centre, which let a fly-by 49m to
        // the *side* of a 50m ring succeed. Now the player's path has to
        // actually pierce the disc.
        let previous = prevPlayerPosition
        prevPlayerPosition = playerPosition
        guard let prev = previous else {
            animateTargetRing()
            return
        }

        let ring = rings[currentRingIndex]
        if let crossing = Self.crossing(of: ring, index: currentRingIndex,
                                        from: prev, to: playerPosition,
                                        at: elapsedTime,
                                        comboFactor: comboRadiusFactor) {
            lastCrossing = crossing
            crossingCount += 1
            let judgement = GateScoring.judge(accuracy: crossing.accuracy)
            lastJudgement = judgement
            lastPointsEarned = score.register(judgement)
            if crossing.isPass {
                passCurrentRing()
            } else {
                ringMisses += 1
            }
        }

        // Animate current target ring
        animateTargetRing()
    }

    /// Advance past the current target ring: play the pass animation,
    /// highlight the next ring, and complete the stage if it was the last.
    private func passCurrentRing() {
        let ring = rings[currentRingIndex]
        rings[currentRingIndex].isPassed = true

        // Ring pass animation
        let scaleUp = SCNAction.scale(to: 1.5, duration: 0.2)
        let fadeOut = SCNAction.fadeOut(duration: 0.3)
        ring.node.runAction(.sequence([scaleUp, fadeOut]))

        currentRingIndex += 1

        // Highlight next ring
        if currentRingIndex < rings.count {
            highlightRing(at: currentRingIndex)
        }

        // Check completion
        if currentRingIndex >= rings.count {
            completeStage()
        }
    }

    /// Pure geometry: does the segment `from → to` cross the ring's plane
    /// in the forward direction, and where? Returns nil when the segment
    /// doesn't cross, crosses backwards, or crosses so far from the
    /// centre that it can't be read as an attempt.
    static func crossing(of ring: Ring, index: Int,
                         from: SCNVector3, to: SCNVector3,
                         at time: TimeInterval = 0,
                         comboFactor: Float = 1) -> RingCrossing? {
        let n = ring.normal
        let c = ring.center(at: time)
        let d0 = (from.x - c.x) * n.x + (from.y - c.y) * n.y + (from.z - c.z) * n.z
        let d1 = (to.x - c.x) * n.x + (to.y - c.y) * n.y + (to.z - c.z) * n.z
        // Forward crossing: start on the near side (d0 < 0), end on or
        // past the plane (d1 >= 0). A point exactly on the plane at the
        // start is treated as "already through".
        guard d0 < 0, d1 >= 0 else { return nil }
        let span = d1 - d0
        let t: Float = span > 0 ? (-d0 / span) : 0
        let hit = SCNVector3(from.x + (to.x - from.x) * t,
                             from.y + (to.y - from.y) * t,
                             from.z + (to.z - from.z) * t)
        let offset = hit - c
        let along = offset.x * n.x + offset.y * n.y + offset.z * n.z
        let radialVec = SCNVector3(offset.x - n.x * along,
                                   offset.y - n.y * along,
                                   offset.z - n.z * along)
        let radius = ring.effectiveRadius(at: time, comboFactor: comboFactor)
        guard radius > 0 else { return nil }

        let accuracy: Float
        if case .tilt(let angleDegrees, let slitRatio) = ring.kind {
            // Project the radial offset onto the ring plane's basis
            // (side, up), rotate into the slit's frame, and measure
            // against an ellipse with semi-axes (radius, radius × ratio).
            let side = ring.sideAxis
            let u = radialVec.x * side.x + radialVec.y * side.y + radialVec.z * side.z
            let v = radialVec.y
            let theta = angleDegrees * Float.pi / 180
            let uR =  u * cos(theta) + v * sin(theta)
            let vR = -u * sin(theta) + v * cos(theta)
            let minor = max(radius * slitRatio, 0.001)
            accuracy = sqrt((uR / radius) * (uR / radius) + (vR / minor) * (vR / minor))
        } else {
            accuracy = radialVec.length / radius
        }
        guard accuracy <= missAttemptRadiusMultiplier else { return nil }
        return RingCrossing(ringIndex: index, accuracy: accuracy, hitPoint: hit)
    }

    func registerCollision() {
        collisions += 1
    }

    func registerStarCollected() {
        starsCollected += 1
    }

    func reset() {
        clearRings()
        state = .notStarted
        currentStage = nil
        prevPlayerPosition = nil
        lastCrossing = nil
        crossingCount = 0
        ringMisses = 0
        score = RunScore()
        lastJudgement = nil
        lastPointsEarned = 0
    }

    // MARK: - Private Methods

    private func completeStage() {
        guard let stage = currentStage else { return }

        let stars = calculateStars(stage: stage)

        let result = StageResult(
            stageIndex: stage.index,
            stars: stars,
            completionTime: elapsedTime,
            collisions: collisions,
            starsCollected: starsCollected,
            ringsCompleted: currentRingIndex,
            totalRings: rings.count,
            date: Date(),
            score: score.points,
            maxCombo: score.maxCombo,
            bullseyes: score.bullseyes
        )

        state = .completed(result)
    }

    private func calculateStars(stage: StageDefinition) -> Int {
        // Base: 1 star for completion
        var stars = 1

        // 2 stars: completed within reasonable time and low collisions
        if collisions <= 2 {
            stars = 2
        }

        // 3 stars: perfect run
        if let star3Time = stage.star3Time {
            // Has time requirement: complete within time limit with no collisions
            if elapsedTime <= star3Time && collisions == 0 {
                stars = 3
            }
        } else {
            // No time requirement: check collision-free + all stars collected (Stage 2 condition)
            let allStarsCollected = stage.starCountForPerfect == nil
                || starsCollected >= (stage.starCountForPerfect ?? 0)
            if collisions == 0 && allStarsCollected {
                stars = 3
            }
        }

        return stars
    }

    private func clearRings() {
        for ring in rings {
            ring.node.removeFromParentNode()
        }
        rings.removeAll()
        for deco in decorations {
            deco.removeFromParentNode()
        }
        decorations.removeAll()
    }

    /// Build a brown-grey mountain-shaped node that rises from `base.y` up
    /// to `peakY`. Static helper so it's testable without an engine
    /// instance. Uses 4 stacked cones to give a chunky stylized silhouette
    /// rather than a single sharp pyramid; matches the chibi art direction.
    static func makeMountainPillar(base: SCNVector3, peakY: Float) -> SCNNode {
        let totalHeight = max(peakY - base.y, 30)  // floor to keep visible
        let node = SCNNode()
        node.position = base

        // Lower wider cone (the "bulk" of the mountain).
        let lowerHeight = totalHeight * 0.7
        let lower = SCNNode(geometry: SCNCone(
            topRadius: CGFloat(totalHeight * 0.18),
            bottomRadius: CGFloat(totalHeight * 0.45),
            height: CGFloat(lowerHeight)
        ))
        lower.position = SCNVector3(0, lowerHeight / 2, 0)
        lower.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.42, green: 0.32, blue: 0.24, alpha: 1.0)
        node.addChildNode(lower)

        // Upper steeper cone (the "peak"). Caps off the silhouette and
        // gives the rings a clear underline of "I am at the summit".
        let upperHeight = totalHeight * 0.32
        let upper = SCNNode(geometry: SCNCone(
            topRadius: 0,
            bottomRadius: CGFloat(totalHeight * 0.18),
            height: CGFloat(upperHeight)
        ))
        upper.position = SCNVector3(0, lowerHeight + upperHeight / 2, 0)
        upper.geometry?.firstMaterial?.diffuse.contents =
            UIColor(red: 0.55, green: 0.46, blue: 0.40, alpha: 1.0)
        node.addChildNode(upper)

        // Snow cap if the mountain is tall enough to read as alpine.
        if totalHeight > 120 {
            let cap = SCNNode(geometry: SCNCone(
                topRadius: 0,
                bottomRadius: CGFloat(totalHeight * 0.10),
                height: CGFloat(upperHeight * 0.35)
            ))
            cap.position = SCNVector3(0, lowerHeight + upperHeight - upperHeight * 0.18, 0)
            cap.geometry?.firstMaterial?.diffuse.contents =
                UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
            node.addChildNode(cap)
        }

        return node
    }

    private func createRingNode(radius: Float, index: Int, kind: GateKind = .standard) -> SCNNode {
        let node = SCNNode()
        node.name = "ring_\(index)"

        // Inner "geometry" node carries the per-kind shape (slit
        // squash / roll); the outer node carries position, yaw and the
        // live scale animation so the two never fight.
        let shape = SCNNode()
        shape.name = "ring_shape"
        let torus = SCNTorus(ringRadius: CGFloat(radius), pipeRadius: CGFloat(radius * 0.05))
        let torusNode = SCNNode(geometry: torus)
        torusNode.eulerAngles.x = .pi / 2  // Face forward
        torus.firstMaterial?.diffuse.contents = Self.idleColor(for: kind)
        torus.firstMaterial?.emission.contents = Self.idleEmission(for: kind)
        shape.addChildNode(torusNode)

        if case .tilt(let angleDegrees, let slitRatio) = kind {
            // Squash into a slit, then roll about the course axis (local
            // Z, since the torus faces +Z after the X rotation above).
            shape.scale = SCNVector3(1, slitRatio, 1)
            let roll = SCNNode()
            roll.eulerAngles.z = -angleDegrees * Float.pi / 180
            roll.addChildNode(shape)
            node.addChildNode(roll)
        } else {
            node.addChildNode(shape)
        }
        return node
    }

    private static func idleColor(for kind: GateKind) -> UIColor {
        switch kind {
        case .standard:  return UIColor(red: 0.5, green: 0.86, blue: 1.0, alpha: 0.8)
        case .shrinking: return UIColor(red: 1.0, green: 0.55, blue: 0.75, alpha: 0.85)
        case .tilt:      return UIColor(red: 0.75, green: 0.6, blue: 1.0, alpha: 0.85)
        case .moving:    return UIColor(red: 0.55, green: 1.0, blue: 0.7, alpha: 0.85)
        }
    }

    private static func idleEmission(for kind: GateKind) -> UIColor {
        switch kind {
        case .standard:  return UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.5)
        case .shrinking: return UIColor(red: 0.9, green: 0.3, blue: 0.55, alpha: 0.5)
        case .tilt:      return UIColor(red: 0.55, green: 0.35, blue: 0.95, alpha: 0.5)
        case .moving:    return UIColor(red: 0.3, green: 0.85, blue: 0.5, alpha: 0.5)
        }
    }

    private func highlightRing(at index: Int) {
        guard index < rings.count else { return }
        rings[index].targetedAt = elapsedTime

        // Make target ring more visible
        rings[index].node.enumerateChildNodes { node, _ in
            if let torus = node.geometry as? SCNTorus {
                torus.firstMaterial?.diffuse.contents = UIColor(
                    red: 1.0, green: 0.84, blue: 0, alpha: 1.0
                )
                torus.firstMaterial?.emission.contents = UIColor(
                    red: 1.0, green: 0.84, blue: 0, alpha: 0.8
                )
            }
        }
    }

    private func animateTargetRing() {
        guard currentRingIndex < rings.count else { return }
        let ring = rings[currentRingIndex]
        let pulse = 1.0 + sin(Float(CACurrentMediaTime()) * 3) * 0.1
        // Visual scale tracks the *judged* radius so a shrinking gate or
        // a combo-tightened ring looks exactly as small as it is.
        let dynamic = ring.shrinkScale(at: elapsedTime) * comboRadiusFactor
        let s = pulse * dynamic
        ring.node.scale = SCNVector3(s, s, s)
        if case .moving = ring.kind {
            ring.node.position = ring.center(at: elapsedTime)
        }
    }

    // MARK: - Info

    var progressText: String {
        guard let stage = currentStage else { return "" }
        return L10n.format("mission.progress.ringFormat", currentRingIndex, stage.ringCount)
    }

    var remainingTime: TimeInterval? {
        guard let stage = currentStage, let timeLimit = stage.timeLimit else { return nil }
        return max(0, timeLimit - elapsedTime)
    }

    var isTimeCritical: Bool {
        guard let remaining = remainingTime else { return false }
        return remaining < 30
    }
}
