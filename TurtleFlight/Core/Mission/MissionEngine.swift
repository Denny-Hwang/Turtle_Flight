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
    private let parentNode: SCNNode

    init(parentNode: SCNNode) {
        self.parentNode = parentNode
    }

    // MARK: - Public Methods

    func startStage(_ stage: StageDefinition) {
        currentStage = stage
        currentRingIndex = 0
        elapsedTime = 0
        collisions = 0
        starsCollected = 0
        state = .inProgress

        // Clear previous rings
        clearRings()

        // Generate rings
        let positions = stage.generateRings()
        for (i, pos) in positions.enumerated() {
            let ringNode = createRingNode(radius: stage.ringRadius, index: i)
            ringNode.position = pos
            parentNode.addChildNode(ringNode)
            rings.append(Ring(node: ringNode, position: pos, radius: stage.ringRadius))
        }

        // Highlight first ring
        highlightRing(at: 0)
    }

    func update(deltaTime: Float, playerPosition: SCNVector3) {
        guard case .inProgress = state, let stage = currentStage else { return }

        elapsedTime += Double(deltaTime)

        // Check time limit
        if let timeLimit = stage.timeLimit, elapsedTime >= timeLimit {
            state = .failed(reason: "시간 초과!")
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
            if elapsedTime <= star3Time && collisions == 0 {
                stars = 3
            }
        } else {
            // Stages without time requirement
            if collisions == 0 {
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
        return "링 \(currentRingIndex)/\(stage.ringCount)"
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
