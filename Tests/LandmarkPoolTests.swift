import XCTest
import SceneKit
@testable import TurtleFlight

/// Landmarks are built ahead of time off the render thread (2026-11-27:
/// a 67–100 ms hitch every 1.2 km in the Free Flight device soak).
final class LandmarkPoolTests: XCTestCase {

    private func waitForPool(_ field: LandmarkField, atLeast n: Int) {
        let deadline = Date().addingTimeInterval(10)
        while field.pooledCount < n && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    func testPoolFillsInTheBackgroundAndRefillsAfterUse() {
        let scene = SCNScene()
        let field = LandmarkField(parentNode: scene.rootNode, world: .sky) { _, _ in 0 }
        let kinds = Set(LandmarkKind.kinds(in: .sky)).count
        waitForPool(field, atLeast: kinds * LandmarkField.poolDepth)
        XCTAssertEqual(field.pooledCount, kinds * LandmarkField.poolDepth)

        // Fly into a row of new cells: they come from the pool.
        field.update(playerPosition: SCNVector3(0, 500, -LandmarkField.cellSize * 3))
        XCTAssertFalse(field.placements.isEmpty)
        XCTAssertLessThan(field.pooledCount, kinds * LandmarkField.poolDepth)
        for placement in field.placements {
            XCTAssertNotNil(scene.rootNode.childNode(withName: "landmark_\(placement.kind.rawValue)", recursively: false))
        }

        // And it tops itself back up.
        waitForPool(field, atLeast: kinds * LandmarkField.poolDepth)
        XCTAssertEqual(field.pooledCount, kinds * LandmarkField.poolDepth)
        field.clear()
    }
}
