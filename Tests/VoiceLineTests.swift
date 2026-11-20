import XCTest
@testable import TurtleFlight

/// Spoken callouts: which line a gate earns, which line may cut in, and
/// that the generator manifest (`scripts/audio/voice-lines.json`) names
/// exactly the lines the app asks for.
final class VoiceLineTests: XCTestCase {

    // MARK: - Gate selection

    func testJudgementLines() {
        XCTAssertEqual(VoiceLine.forGatePass(judgement: .bullseye, comboAfterPass: 2), .bullseye)
        XCTAssertEqual(VoiceLine.forGatePass(judgement: .great, comboAfterPass: 2), .great)
        XCTAssertNil(VoiceLine.forGatePass(judgement: .ok, comboAfterPass: 2),
                     "OK passes stay silent so the voice stays special")
        XCTAssertNil(VoiceLine.forGatePass(judgement: .miss, comboAfterPass: 0))
    }

    func testComboMilestoneBeatsJudgement() {
        XCTAssertEqual(VoiceLine.forGatePass(judgement: .bullseye, comboAfterPass: 5), .combo5)
        XCTAssertEqual(VoiceLine.forGatePass(judgement: .ok, comboAfterPass: 10), .combo10)
        XCTAssertEqual(VoiceLine.forGatePass(judgement: .great, comboAfterPass: 20), .combo20)
        XCTAssertEqual(VoiceLine.forGatePass(judgement: .great, comboAfterPass: 6), .great)
    }

    // MARK: - Interruption

    func testOnlyStrictlyHigherPriorityInterrupts() {
        XCTAssertTrue(VoiceLine.shouldInterrupt(current: nil, with: .great))
        XCTAssertTrue(VoiceLine.shouldInterrupt(current: .great, with: .bullseye))
        XCTAssertTrue(VoiceLine.shouldInterrupt(current: .combo10, with: .stageClear))
        XCTAssertFalse(VoiceLine.shouldInterrupt(current: .bullseye, with: .bullseye),
                       "a burst of bullseyes must not stutter")
        XCTAssertFalse(VoiceLine.shouldInterrupt(current: .stageClear, with: .bullseye))
        XCTAssertFalse(VoiceLine.shouldInterrupt(current: .boost, with: .go))
    }

    func testAssetNames() {
        XCTAssertEqual(VoiceLine.combo10.assetName, "voice_combo_10")
        XCTAssertEqual(VoiceLine.stageClear.assetName, "voice_stage_clear")
    }

    // MARK: - Manifest parity

    private struct Manifest: Decodable {
        struct Voice: Decodable { let languageCode: String; let name: String }
        struct Line: Decodable { let key: String; let text: String }
        let voice: Voice
        let lines: [Line]
    }

    private func loadManifest() throws -> Manifest {
        let repoRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // repo root
        let url = repoRoot.appendingPathComponent("scripts/audio/voice-lines.json")
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }

    func testManifestMatchesEnum() throws {
        let manifest = try loadManifest()
        let keys = manifest.lines.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "duplicate key in voice-lines.json")
        XCTAssertEqual(Set(keys), Set(VoiceLine.allCases.map(\.rawValue)),
                       "voice-lines.json and VoiceLine must name the same lines")
        XCTAssertTrue(manifest.lines.allSatisfy { !$0.text.isEmpty })
    }

    func testManifestVoiceIsNonGenerative() throws {
        // Google's terms bar Generative AI Services (Chirp, Journey,
        // Studio, Gemini voices) from services likely used by under-18s;
        // the app is rated 4+.
        let voice = try loadManifest().voice.name
        XCTAssertNotNil(voice.range(of: #"^[a-z]{2}-[A-Z]{2}-(Neural2|Wavenet)-[A-Z]$"#,
                                    options: .regularExpression),
                        "\(voice) must be a Neural2 or WaveNet voice")
    }

    // MARK: - Runtime safety

    func testMissingClipIsSilentNoOp() {
        // Before the clips are generated every line is absent from the
        // bundle; playVoice must just return.
        for line in VoiceLine.allCases {
            AudioManager.shared.playVoice(line)
        }
    }
}
