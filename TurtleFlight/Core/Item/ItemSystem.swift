import Foundation
import SceneKit

final class ItemSystem {
    // MARK: - Star Item
    struct Star {
        let node: SCNNode
        let position: SCNVector3
        var isCollected: Bool = false
    }

    // MARK: - Projectile
    struct Projectile {
        let node: SCNNode
        var lifetime: TimeInterval
        let direction: SCNVector3
        let speed: Float
    }

    // MARK: - Properties
    private(set) var stars: [Star] = []
    private(set) var projectiles: [Projectile] = []
    private(set) var starsCollected: Int = 0
    private let parentNode: SCNNode

    init(parentNode: SCNNode) {
        self.parentNode = parentNode
    }

    // MARK: - Star Management

    /// Spawn stars around player position
    func spawnStars(around position: SCNVector3, count: Int = 10, radius: Float = 200) {
        for i in 0..<count {
            let angle = Float(i) / Float(count) * .pi * 2
            let distance = Float.random(in: 50...radius)
            let height = Float.random(in: 200...800)

            let x = position.x + cos(angle) * distance
            let z = position.z + sin(angle) * distance

            let starNode = createStarNode()
            starNode.position = SCNVector3(x, height, z)

            parentNode.addChildNode(starNode)
            stars.append(Star(node: starNode, position: starNode.position))
        }
    }

    /// Check for star collection near player
    func checkCollection(playerPosition: SCNVector3) -> Int {
        var collected = 0
        let collectionRadius = Constants.Items.starCollectionRadius

        for i in 0..<stars.count {
            guard !stars[i].isCollected else { continue }

            let dist = (stars[i].position - playerPosition).length
            if dist < collectionRadius {
                stars[i].isCollected = true
                starsCollected += 1
                collected += 1

                // Collection animation
                let scaleUp = SCNAction.scale(to: 2.0, duration: 0.2)
                let fadeOut = SCNAction.fadeOut(duration: 0.3)
                let remove = SCNAction.removeFromParentNode()
                stars[i].node.runAction(.sequence([scaleUp, fadeOut, remove]))
            }
        }

        return collected
    }

    /// Animate uncollected stars (rotation + bobbing)
    func updateStarAnimations(deltaTime: Float) {
        for star in stars where !star.isCollected {
            star.node.eulerAngles.y += deltaTime * 2.0
            let bob = sin(Float(CACurrentMediaTime()) * 2) * 0.3
            star.node.position.y = star.position.y + bob
        }
    }

    // MARK: - Projectile System

    /// Fire a star projectile from player position
    func fireProjectile(from position: SCNVector3, direction: SCNVector3) {
        let projectileNode = createProjectileNode()
        projectileNode.position = position

        parentNode.addChildNode(projectileNode)

        let projectile = Projectile(
            node: projectileNode,
            lifetime: Constants.Items.projectileLifetime,
            direction: direction.normalized,
            speed: Constants.Items.projectileSpeed
        )
        projectiles.append(projectile)
    }

    /// Update projectile positions and remove expired ones
    func updateProjectiles(deltaTime: Float) {
        var toRemove: [Int] = []

        for i in 0..<projectiles.count {
            projectiles[i].lifetime -= Double(deltaTime)

            if projectiles[i].lifetime <= 0 {
                toRemove.append(i)
                projectiles[i].node.removeFromParentNode()
            } else {
                let move = projectiles[i].direction * (projectiles[i].speed * deltaTime)
                projectiles[i].node.position = projectiles[i].node.position + move

                // Spin animation
                projectiles[i].node.eulerAngles.y += deltaTime * 10
                projectiles[i].node.eulerAngles.z += deltaTime * 5
            }
        }

        // Remove expired projectiles (reverse order)
        for index in toRemove.reversed() {
            projectiles.remove(at: index)
        }
    }

    /// Reset all items
    func reset() {
        for star in stars {
            star.node.removeFromParentNode()
        }
        for proj in projectiles {
            proj.node.removeFromParentNode()
        }
        stars.removeAll()
        projectiles.removeAll()
        starsCollected = 0
    }

    // MARK: - Node Creation

    private func createStarNode() -> SCNNode {
        let node = SCNNode()
        node.name = "star"

        // Star shape using two intersecting boxes
        let box1 = SCNNode(geometry: SCNBox(width: 2, height: 2, length: 0.5, chamferRadius: 0.1))
        box1.eulerAngles.z = .pi / 4
        box1.geometry?.firstMaterial?.diffuse.contents = UIColor(
            red: 1.0, green: 0.84, blue: 0, alpha: 1
        )
        box1.geometry?.firstMaterial?.emission.contents = UIColor(
            red: 1.0, green: 0.84, blue: 0, alpha: 0.5
        )
        node.addChildNode(box1)

        let box2 = SCNNode(geometry: SCNBox(width: 2, height: 2, length: 0.5, chamferRadius: 0.1))
        box2.geometry?.firstMaterial?.diffuse.contents = UIColor(
            red: 1.0, green: 0.84, blue: 0, alpha: 1
        )
        box2.geometry?.firstMaterial?.emission.contents = UIColor(
            red: 1.0, green: 0.84, blue: 0, alpha: 0.5
        )
        node.addChildNode(box2)

        return node
    }

    private func createProjectileNode() -> SCNNode {
        let node = SCNNode()
        node.name = "projectile"

        let sphere = SCNNode(geometry: SCNSphere(radius: 0.5))
        sphere.geometry?.firstMaterial?.diffuse.contents = UIColor(
            red: 1.0, green: 0.84, blue: 0, alpha: 1
        )
        sphere.geometry?.firstMaterial?.emission.contents = UIColor(
            red: 1.0, green: 0.6, blue: 0, alpha: 1
        )
        node.addChildNode(sphere)

        // Trail particles
        let trail = SCNNode(geometry: SCNSphere(radius: 0.3))
        trail.position = SCNVector3(0, 0, 0.5)
        trail.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
        trail.geometry?.firstMaterial?.transparency = 0.5
        node.addChildNode(trail)

        return node
    }
}
