import XCTest
import SceneKit
@testable import TurtleFlight

final class ItemSystemTests: XCTestCase {

    var scene: SCNScene!
    var itemSystem: ItemSystem!

    override func setUp() {
        super.setUp()
        scene = SCNScene()
        itemSystem = ItemSystem(parentNode: scene.rootNode)
    }

    override func tearDown() {
        itemSystem.reset()
        super.tearDown()
    }

    // MARK: - Star Spawning

    func testInitialState() {
        XCTAssertEqual(itemSystem.stars.count, 0)
        XCTAssertEqual(itemSystem.projectiles.count, 0)
        XCTAssertEqual(itemSystem.starsCollected, 0)
    }

    func testSpawnStarsCount() {
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 10)
        XCTAssertEqual(itemSystem.stars.count, 10)
    }

    func testSpawnStarsCustomCount() {
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 5)
        XCTAssertEqual(itemSystem.stars.count, 5)
    }

    func testSpawnedStarsAddedToScene() {
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 3)
        // Verify each star node is in the scene graph
        for star in itemSystem.stars {
            XCTAssertNotNil(star.node.parent, "Star node should be added to scene")
        }
    }

    func testSpawnedStarsNotCollected() {
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 5)
        for star in itemSystem.stars {
            XCTAssertFalse(star.isCollected)
        }
    }

    func testSpawnedStarsHavePositions() {
        let origin = SCNVector3(100, 500, 200)
        itemSystem.spawnStars(around: origin, count: 10, radius: 200)
        for star in itemSystem.stars {
            // Stars should have non-zero positions
            let dist = (star.position - origin).length
            XCTAssertLessThanOrEqual(dist, 300, "Star too far from origin: \(dist)")
        }
    }

    // MARK: - Star Collection

    func testCollectionReturnCount() {
        // Spawn a star right at the player position
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 1)
        // Override star position to be right at player
        let starPos = itemSystem.stars[0].position
        let collected = itemSystem.checkCollection(playerPosition: starPos)
        XCTAssertEqual(collected, 1)
    }

    func testCollectionIncrementsStarsCollected() {
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 1)
        let starPos = itemSystem.stars[0].position
        _ = itemSystem.checkCollection(playerPosition: starPos)
        XCTAssertEqual(itemSystem.starsCollected, 1)
    }

    func testNoCollectionWhenFarAway() {
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 5)
        // Player is very far away
        let collected = itemSystem.checkCollection(playerPosition: SCNVector3(99999, 99999, 99999))
        XCTAssertEqual(collected, 0)
        XCTAssertEqual(itemSystem.starsCollected, 0)
    }

    func testAlreadyCollectedStarNotCollectedAgain() {
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 1)
        let starPos = itemSystem.stars[0].position
        _ = itemSystem.checkCollection(playerPosition: starPos)
        // Try again
        let secondCollection = itemSystem.checkCollection(playerPosition: starPos)
        XCTAssertEqual(secondCollection, 0)
        XCTAssertEqual(itemSystem.starsCollected, 1)  // Still 1, not 2
    }

    func testCollectionRadius() {
        // Place a star at known position
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 1)
        let starPos = itemSystem.stars[0].position

        // Player just outside collection radius (10.0 + epsilon)
        let justOutside = SCNVector3(starPos.x + 11.0, starPos.y, starPos.z)
        let collected = itemSystem.checkCollection(playerPosition: justOutside)
        XCTAssertEqual(collected, 0, "Should not collect star just outside radius")
    }

    func testMultipleStarsCollected() {
        // Spawn multiple stars at origin so all can be collected
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 3)
        // Position player at each star's exact position and collect
        var total = 0
        for star in itemSystem.stars {
            total += itemSystem.checkCollection(playerPosition: star.position)
        }
        XCTAssertEqual(total, 3)
        XCTAssertEqual(itemSystem.starsCollected, 3)
    }

    // MARK: - Projectile System

    func testFireProjectileAddsToList() {
        let pos = SCNVector3(0, 500, 0)
        let dir = SCNVector3(0, 0, -1)
        itemSystem.fireProjectile(from: pos, direction: dir)
        XCTAssertEqual(itemSystem.projectiles.count, 1)
    }

    func testProjectileAddedToScene() {
        let pos = SCNVector3(0, 500, 0)
        let dir = SCNVector3(0, 0, -1)
        itemSystem.fireProjectile(from: pos, direction: dir)
        XCTAssertNotNil(itemSystem.projectiles[0].node.parent)
    }

    func testProjectileHasCorrectLifetime() {
        let pos = SCNVector3(0, 500, 0)
        let dir = SCNVector3(0, 0, -1)
        itemSystem.fireProjectile(from: pos, direction: dir)
        XCTAssertEqual(itemSystem.projectiles[0].lifetime,
                       Constants.Items.projectileLifetime,
                       accuracy: 0.001)
    }

    func testProjectileMovesForward() {
        let startPos = SCNVector3(0, 500, 0)
        let dir = SCNVector3(0, 0, -1)
        itemSystem.fireProjectile(from: startPos, direction: dir)

        let initialZ = itemSystem.projectiles[0].node.position.z
        itemSystem.updateProjectiles(deltaTime: 0.1)
        let newZ = itemSystem.projectiles[0].node.position.z

        XCTAssertLessThan(newZ, initialZ, "Projectile should move in -Z direction")
    }

    func testProjectileExpiresAfterLifetime() {
        let pos = SCNVector3(0, 500, 0)
        let dir = SCNVector3(0, 0, -1)
        itemSystem.fireProjectile(from: pos, direction: dir)

        // Update for longer than lifetime
        itemSystem.updateProjectiles(deltaTime: Float(Constants.Items.projectileLifetime) + 0.1)
        XCTAssertEqual(itemSystem.projectiles.count, 0, "Projectile should expire")
    }

    func testMultipleProjectiles() {
        for _ in 0..<5 {
            itemSystem.fireProjectile(from: SCNVector3(0, 500, 0), direction: SCNVector3(0, 0, -1))
        }
        XCTAssertEqual(itemSystem.projectiles.count, 5)
    }

    func testProjectileDirectionNormalized() {
        // Fire with non-normalized direction
        let dir = SCNVector3(3, 0, 4)  // length = 5
        itemSystem.fireProjectile(from: SCNVector3(0, 500, 0), direction: dir)

        let normalizedDir = itemSystem.projectiles[0].direction
        let length = normalizedDir.length
        XCTAssertEqual(length, 1.0, accuracy: 0.001, "Projectile direction should be normalized")
    }

    // MARK: - Reset

    func testResetClearsStars() {
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 5)
        itemSystem.reset()
        XCTAssertEqual(itemSystem.stars.count, 0)
    }

    func testResetClearsProjectiles() {
        itemSystem.fireProjectile(from: SCNVector3(0, 500, 0), direction: SCNVector3(0, 0, -1))
        itemSystem.reset()
        XCTAssertEqual(itemSystem.projectiles.count, 0)
    }

    func testResetClearsStarsCollectedCount() {
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 1)
        _ = itemSystem.checkCollection(playerPosition: itemSystem.stars[0].position)
        XCTAssertEqual(itemSystem.starsCollected, 1)
        itemSystem.reset()
        XCTAssertEqual(itemSystem.starsCollected, 0)
    }

    // MARK: - Star Animation (smoke test)

    func testUpdateStarAnimationsDoesNotCrash() {
        itemSystem.spawnStars(around: SCNVector3(0, 500, 0), count: 5)
        // Just verify no crash
        itemSystem.updateStarAnimations(deltaTime: 0.016)
    }
}
