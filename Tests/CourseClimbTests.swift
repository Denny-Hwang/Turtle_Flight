import XCTest
import SceneKit
@testable import TurtleFlight

/// No course asks for a climb or dive steeper than `maxClimbSlope`
/// between consecutive rings (2026-11-26 audit: Mountain Cross was ~2.0,
/// some Daily Run days ~1.7 — the next ring sat far above the view).
final class CourseClimbTests: XCTestCase {

    private func steepest(_ rings: [SCNVector3]) -> Float {
        var worst: Float = 0
        // The character starts level with the first ring (placeAtCourseStart).
        var prev = SCNVector3(0, rings.first?.y ?? 0, 0)
        for r in rings {
            let flat = ((r.x - prev.x) * (r.x - prev.x) + (r.z - prev.z) * (r.z - prev.z)).squareRoot()
            worst = max(worst, abs(r.y - prev.y) / max(flat, 1))
            prev = r
        }
        return worst
    }

    private let limit = CourseGenerator.maxClimbSlope + 0.001

    func testCampaignAndRouteCourses() {
        for stage in StageDefinition.allStages {
            XCTAssertLessThanOrEqual(steepest(stage.generateRings()), limit, "stage \(stage.index)")
            XCTAssertLessThanOrEqual(steepest(stage.kidsVariant().generateRings()), limit, "kids \(stage.index)")
        }
        for route in RouteID.allCases {
            for course in RouteCatalog.courses(in: route) {
                XCTAssertLessThanOrEqual(steepest(course.generateRings()), limit, "course \(course.index)")
            }
        }
    }

    func testAMonthOfDailyRuns() {
        for day in 0..<60 {
            let date = Date(timeIntervalSince1970: 1_790_000_000 + Double(day) * 86_400)
            XCTAssertLessThanOrEqual(steepest(DailyRun.stage(for: date).generateRings()), limit, "day \(day)")
        }
    }

    func testSkyRunAcrossChunks() {
        for seed: UInt64 in [1, 7, 99, 2026] {
            var rings: [SCNVector3] = []
            for c in 0..<6 {
                rings += EndlessCourse.chunk(seed: seed, startIndex: c * EndlessCourse.chunkSize,
                                             previousEnd: rings.last).map(\.position)
            }
            XCTAssertLessThanOrEqual(steepest(rings), limit, "seed \(seed)")
        }
    }

    func testLimitKeepsGentleCoursesUnchanged() {
        let gentle = [SCNVector3(0, 400, -150), SCNVector3(20, 430, -300), SCNVector3(0, 420, -450)]
        let out = CourseGenerator.limitClimb(gentle)
        XCTAssertEqual(out.map(\.y), gentle.map(\.y))
    }
}
