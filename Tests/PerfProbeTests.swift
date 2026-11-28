import XCTest
import SceneKit
@testable import TurtleFlight

/// B0 (benchmark/PLAN.md): the probe's per-second window and scene
/// snapshot, without a renderer.
final class PerfProbeTests: XCTestCase {

    func testHeaderMatchesLineColumns() {
        let line = PerfWindow().line(seconds: 1, elapsed: 1, memoryMB: 100, thermal: 0)
        XCTAssertEqual(PerfWindow.header.split(separator: ",").count,
                       line.trimmingCharacters(in: .newlines).split(separator: ",").count)
    }

    func testWindowTracksWorstFrameAndTerrainWork() {
        var w = PerfWindow()
        for _ in 0..<59 { w.frame(interval: 1.0 / 60) }
        w.frame(interval: 0.05)
        w.add(.chunk, ms: 4)
        w.add(.chunk, ms: 9)
        w.add(.farTerrain, ms: 6)
        XCTAssertEqual(w.frames, 60)
        XCTAssertEqual(w.worstFrame, 0.05, accuracy: 1e-9)
        XCTAssertEqual(w.chunkBuilds, 2)
        XCTAssertEqual(w.chunkWorstMs, 9)
        XCTAssertEqual(w.farWorstMs, 6)

        let fields = w.line(seconds: 12, elapsed: 1, memoryMB: 126, thermal: 1)
            .trimmingCharacters(in: .newlines).split(separator: ",").map(String.init)
        XCTAssertEqual(Array(fields.prefix(8)), ["12", "60.0", "50.0", "126", "1", "2", "9.0", "6.0"])
    }

    func testResetKeepsSceneSnapshot() {
        var w = PerfWindow()
        w.scene = SceneStats(nodes: 5, triangles: 100, draws: 3, particles: 1)
        w.add(.chunk, ms: 3)
        w.frame(interval: 0.02)
        w.reset()
        XCTAssertEqual(w, PerfWindow(scene: SceneStats(nodes: 5, triangles: 100, draws: 3, particles: 1)))
    }

    func testSceneStatsCountsVisibleContent() {
        let root = SCNNode()
        // Two triangles in one element.
        let vertices = [SCNVector3(0, 0, 0), SCNVector3(1, 0, 0), SCNVector3(0, 1, 0), SCNVector3(1, 1, 0)]
        let quad = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)],
                               elements: [SCNGeometryElement(indices: [Int32(0), 1, 2, 2, 1, 3], primitiveType: .triangles)])
        let a = SCNNode(geometry: quad)
        root.addChildNode(a)
        let child = SCNNode(geometry: quad)
        child.addParticleSystem(SCNParticleSystem())
        a.addChildNode(child)
        // Hidden subtree: not drawn, not counted.
        let hidden = SCNNode(geometry: quad)
        hidden.isHidden = true
        hidden.addChildNode(SCNNode(geometry: quad))
        root.addChildNode(hidden)

        let stats = SceneStats.collect(root)
        XCTAssertEqual(stats, SceneStats(nodes: 3, triangles: 4, draws: 2, particles: 1))
    }

    func testSceneStatsSeesBuiltInGeometry() {
        let root = SCNNode()
        root.addChildNode(SCNNode(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)))
        let stats = SceneStats.collect(root)
        XCTAssertGreaterThanOrEqual(stats.triangles, 12)
        XCTAssertGreaterThanOrEqual(stats.draws, 1)
    }

    func testMeasureReturnsBodyResultWhenOff() {
        // The probe is off in tests; measure must still run the body.
        XCTAssertFalse(PerfProbe.isEnabled)
        XCTAssertEqual(PerfProbe.shared.measure(.chunk) { 41 + 1 }, 42)
    }
}
