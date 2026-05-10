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
        let position: SCNVector3
        let radius: Float
        var isPassed: Bool = false
    }

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

    /// World-space position of the ring the player is currently chasing,
    /// or nil when the stage is over (or hasn't started). Drives the
    /// objective compass arrow on `MissionHUD`.
    var currentRingPosition: SCNVector3? {
        guard currentRingIndex < rings.count else { return nil }
        return rings[currentRingIndex].position
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
        state = .inProgress

        // Clear previous rings + decorations
        clearRings()

        // Generate rings, clamping each above the terrain when we have
        // a height query function. The clearance buffer (ringRadius + 20)
        // is intentional: a bare radius would let the player skim the
        // terrain *as they pass through* — we want the ring to read as
        // air-suspended, not embedded.
        let positions = stage.generateRings()
        for (i, pos) in positions.enumerated() {
            let safePos: SCNVector3 = {
                guard let heightFn = terrainHeightAt else { return pos }
                let groundY = heightFn(pos.x, pos.z)
                let minRingY = groundY + stage.ringRadius + 20
                return SCNVector3(pos.x, max(pos.y, minRingY), pos.z)
            }()
            let ringNode = createRingNode(radius: stage.ringRadius, index: i)
            ringNode.position = safePos
            parentNode.addChildNode(ringNode)
            rings.append(Ring(node: ringNode, position: safePos, radius: stage.ringRadius))

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

        let ring = rings[currentRingIndex]
        let distance = (ring.position - playerPosition).length

        if distance < ring.radius {
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

        // Animate current target ring
        animateTargetRing()
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
            date: Date()
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

    private func createRingNode(radius: Float, index: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "ring_\(index)"

        let torus = SCNTorus(ringRadius: CGFloat(radius), pipeRadius: CGFloat(radius * 0.05))
        let torusNode = SCNNode(geometry: torus)
        torusNode.eulerAngles.x = .pi / 2  // Face forward
        torus.firstMaterial?.diffuse.contents = UIColor(
            red: 0.5, green: 0.86, blue: 1.0, alpha: 0.8
        )
        torus.firstMaterial?.emission.contents = UIColor(
            red: 0.3, green: 0.6, blue: 1.0, alpha: 0.5
        )
        node.addChildNode(torusNode)

        return node
    }

    private func highlightRing(at index: Int) {
        guard index < rings.count else { return }

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
        let ring = rings[currentRingIndex].node
        let pulse = 1.0 + sin(Float(CACurrentMediaTime()) * 3) * 0.1
        ring.scale = SCNVector3(pulse, pulse, pulse)
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
