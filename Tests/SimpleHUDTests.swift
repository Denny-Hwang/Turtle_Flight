import XCTest
import SwiftUI
@testable import TurtleFlight

/// V9 of docs/VISUAL_AUDIO_PLAN.md: quiet speed / altitude gauges in
/// free flight.
final class SimpleHUDTests: XCTestCase {

    func testOnlyFreeFlightUsesTheSimpleHUD() {
        XCTAssertTrue(SimpleHUD.isOn(mode: .freePlay, setting: true))
        XCTAssertFalse(SimpleHUD.isOn(mode: .freePlay, setting: false))
        // Missions always keep the full HUD, whatever the setting.
        XCTAssertFalse(SimpleHUD.isOn(mode: .stepGoal, setting: true))
    }

    func testDefaultsOnWhenNeverSet() {
        let defaults = UserDefaults(suiteName: "SimpleHUDTests")!
        defaults.removePersistentDomain(forName: "SimpleHUDTests")
        XCTAssertNil(defaults.object(forKey: SimpleHUD.settingKey))
        XCTAssertTrue(SimpleHUD.defaultOn)
    }

    func testSteadyFlightDoesNotWakeTheGauges() {
        // Small wobbles stay in one band; crossing a band wakes them.
        // Cruise speed and start altitude sit mid-band, not on an edge.
        XCTAssertEqual(SimpleHUD.speedBand(199), SimpleHUD.speedBand(201))
        XCTAssertEqual(SimpleHUD.speedBand(180), SimpleHUD.speedBand(220))
        XCTAssertNotEqual(SimpleHUD.speedBand(224), SimpleHUD.speedBand(226))
        XCTAssertEqual(SimpleHUD.altitudeBand(499), SimpleHUD.altitudeBand(501))
        XCTAssertEqual(SimpleHUD.altitudeBand(460), SimpleHUD.altitudeBand(540))
        XCTAssertNotEqual(SimpleHUD.altitudeBand(549), SimpleHUD.altitudeBand(551))
    }

    func testWokenGaugesFadeBackAfterAMoment() {
        let woke = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(SimpleHUD.isAwake(now: woke.addingTimeInterval(1), wokeAt: woke))
        XCTAssertFalse(SimpleHUD.isAwake(now: woke.addingTimeInterval(SimpleHUD.wakeDuration + 0.1), wokeAt: woke))
        XCTAssertFalse(SimpleHUD.isAwake(now: woke, wokeAt: .distantPast))
    }

    func testStallBoostAndLowAltitudeAlwaysShowInFull() {
        XCTAssertTrue(SimpleHUD.isUrgent(stalled: true, boosting: false, altitude: 500))
        XCTAssertTrue(SimpleHUD.isUrgent(stalled: false, boosting: true, altitude: 500))
        XCTAssertTrue(SimpleHUD.isUrgent(stalled: false, boosting: false, altitude: 10))
        XCTAssertFalse(SimpleHUD.isUrgent(stalled: false, boosting: false, altitude: 500))
    }

    func testRestingGaugesStayReadable() {
        // Faint, not invisible: a child can still find them.
        XCTAssertGreaterThanOrEqual(SimpleHUD.restingOpacity, 0.35)
        XCTAssertGreaterThanOrEqual(SimpleHUD.restingScale, 0.75)
    }
}
