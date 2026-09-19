import Foundation
import SceneKit

struct StageDefinition {
    let index: Int
    let name: String
    let koreanName: String
    let difficulty: Int        // 1-5 stars
    let description: String
    let ringRadius: Float
    let timeLimit: TimeInterval?  // nil = no limit
    let star3Time: TimeInterval?  // complete within this for 3 stars
    let starCountForPerfect: Int? // nil = no star collection requirement
    let star3Condition: String
    let star2Condition: String
    let learningGoal: String
    /// Declarative ring layout. `generateRings()` is a pure function of
    /// this value, so the same spec always yields the same course.
    let course: CourseSpec

    /// Number of rings in the course. Derived from `course` so the two
    /// can never disagree.
    var ringCount: Int { course.count }

    /// Localized stage name shown in the HUD. Looks up `stage.<index>.name`
    /// in Localizable.strings; falls back to the legacy `koreanName` if a
    /// new stage is added without a matching entry.
    var displayName: String {
        let key = "stage.\(index).name"
        let localized = NSLocalizedString(key, comment: key)
        return localized == key ? koreanName : localized
    }

    /// Localized one-line description shown on `StageSelectView`. Looks up
    /// `stage.<index>.description`; falls back to the legacy `description`
    /// stored on the struct. The fallback exists so unit tests on bare
    /// `StageDefinition` values keep passing without a strings bundle.
    var displayDescription: String {
        let key = "stage.\(index).description"
        let localized = NSLocalizedString(key, comment: key)
        return localized == key ? description : localized
    }

    /// Localized "★★★ goal: …" copy on `StageSelectView`. Looks up
    /// `stage.<index>.star3Condition`; falls back to the static field.
    var displayStar3Condition: String {
        let key = "stage.\(index).star3Condition"
        let localized = NSLocalizedString(key, comment: key)
        return localized == key ? star3Condition : localized
    }

    /// Generate ring positions for this stage.
    func generateRings() -> [SCNVector3] {
        CourseGenerator.generate(course)
    }
}

// MARK: - Stage Presets

extension StageDefinition {
    /// The five campaign courses. Each `CourseSpec` reproduces the
    /// original hand-tuned formula, shifted one `spacing` ahead of the
    /// spawn point so the first ring is never behind (or on top of) the
    /// player on frame one — which matters now that ring passage is a
    /// plane-crossing test rather than a sphere-distance check.
    static let allStages: [StageDefinition] = [
        StageDefinition(
            index: 0,
            name: "Sky Walk",
            koreanName: "하늘 산책",
            difficulty: 1,
            description: "링 10개 순서대로 통과",
            ringRadius: 50,
            timeLimit: nil,
            star3Time: 60,
            starCountForPerfect: nil,
            star3Condition: "60초 이내 완료",
            star2Condition: "완료",
            learningGoal: "기본 좌우/상하 조종",
            course: CourseSpec(
                pattern: .weave, count: 10, spacing: 150, startZ: -150,
                lateralAmplitude: 100, angleStep: 0.3,
                baseAltitude: 400, altitudeAmplitude: 20
            )
        ),
        StageDefinition(
            index: 1,
            name: "Cloud Maze",
            koreanName: "구름 미로",
            difficulty: 2,
            description: "구름 기둥 사이 경로 비행, 체크포인트 5개",
            ringRadius: 40,
            timeLimit: 180,
            star3Time: 90,
            starCountForPerfect: nil,
            star3Condition: "접촉 0회 + 90초 이내",
            star2Condition: "완료",
            learningGoal: "고도 유지 + 좌우 미세 조정",
            course: CourseSpec(
                pattern: .zigzag, count: 5, spacing: 200, startZ: -200,
                lateralAmplitude: 80, angleStep: 0,
                baseAltitude: 500, altitudeAmplitude: 0
            )
        ),
        StageDefinition(
            index: 2,
            name: "Valley Run",
            koreanName: "계곡 비행",
            difficulty: 3,
            description: "구불구불한 계곡 저공비행",
            ringRadius: 35,
            timeLimit: 180,
            // Stage 3 introduces the new "collect every star" mechanic.
            // Adding an explicit star3Time (150s) gives players a second
            // legible path to the third star — they can earn ★★★ either
            // by sweeping the field clean OR by clearing in 150s.
            star3Time: 150,
            starCountForPerfect: 5,
            star3Condition: "접촉 0회 + 별 5개 전체 수집 또는 150초 이내",
            star2Condition: "완료",
            learningGoal: "연속 S자 비행",
            course: CourseSpec(
                pattern: .sCurve, count: 8, spacing: 180, startZ: -180,
                lateralAmplitude: 120, angleStep: 0.8,
                baseAltitude: 150, altitudeAmplitude: 50
            )
        ),
        StageDefinition(
            index: 3,
            name: "Mountain Cross",
            koreanName: "산맥 넘기",
            difficulty: 4,
            description: "산봉우리 7개의 정상 링 통과",
            ringRadius: 25,
            // 140s limit / 110s star3 keeps the Stage 4 → 5 ramp at
            // 110 → 90 rather than the old 120 → 80 wall.
            timeLimit: 140,
            star3Time: 110,
            starCountForPerfect: nil,
            star3Condition: "전체 통과 + 110초 이내",
            star2Condition: "완료",
            learningGoal: "급격한 피치 전환 + 부스터 타이밍",
            course: CourseSpec(
                pattern: .peaks, count: 7, spacing: 200, startZ: -200,
                lateralAmplitude: 80, angleStep: 0.9,
                baseAltitude: 600, altitudeAmplitude: 200
            )
        ),
        StageDefinition(
            index: 4,
            name: "Sky Race",
            koreanName: "스카이 레이스",
            difficulty: 5,
            description: "에어 레이스 코스 완주 (링 20개 + S자 + 급선회)",
            ringRadius: 15,
            // 90s star3 is tight (4.5s/ring) but leaves room for one
            // mid-course recovery. Time limit 120s.
            timeLimit: 120,
            star3Time: 90,
            starCountForPerfect: nil,
            star3Condition: "전체 통과 + 90초 이내 + 접촉 0회",
            star2Condition: "완료",
            learningGoal: "종합 기동",
            course: CourseSpec(
                pattern: .race, count: 20, spacing: 120, startZ: -120,
                lateralAmplitude: 60, angleStep: 0.5,
                baseAltitude: 400, altitudeAmplitude: 100
            )
        )
    ]
}
