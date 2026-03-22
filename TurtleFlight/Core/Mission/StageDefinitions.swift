import Foundation
import SceneKit

struct StageDefinition {
    let index: Int
    let name: String
    let koreanName: String
    let difficulty: Int        // 1-5 stars
    let description: String
    let ringCount: Int
    let ringRadius: Float
    let timeLimit: TimeInterval?  // nil = no limit
    let star3Time: TimeInterval?  // complete within this for 3 stars
    let star3Condition: String
    let star2Condition: String
    let learningGoal: String

    /// Generate ring positions for this stage
    func generateRings() -> [SCNVector3] {
        switch index {
        case 0: return generateSkyWalkRings()
        case 1: return generateCloudMazeRings()
        case 2: return generateValleyRunRings()
        case 3: return generateMountainCrossRings()
        case 4: return generateSkyRaceRings()
        default: return []
        }
    }

    // MARK: - Ring Generators

    private func generateSkyWalkRings() -> [SCNVector3] {
        // Stage 1: Simple straight-ish path, 10 rings
        var rings: [SCNVector3] = []
        for i in 0..<10 {
            let angle = Float(i) * 0.3
            let x = sin(angle) * 100
            let z = Float(i) * -150
            let y = Float(400 + i * 20)
            rings.append(SCNVector3(x, y, z))
        }
        return rings
    }

    private func generateCloudMazeRings() -> [SCNVector3] {
        // Stage 2: Weaving path, 5 checkpoints
        var rings: [SCNVector3] = []
        for i in 0..<5 {
            let x = Float(i % 2 == 0 ? -80 : 80)
            let z = Float(i) * -200
            let y: Float = 500
            rings.append(SCNVector3(x, y, z))
        }
        return rings
    }

    private func generateValleyRunRings() -> [SCNVector3] {
        // Stage 3: S-curve low flight
        var rings: [SCNVector3] = []
        for i in 0..<8 {
            let angle = Float(i) * 0.8
            let x = sin(angle) * 120
            let z = Float(i) * -180
            let y: Float = 150 + sin(angle * 0.5) * 50
            rings.append(SCNVector3(x, y, z))
        }
        return rings
    }

    private func generateMountainCrossRings() -> [SCNVector3] {
        // Stage 4: Mountain peaks, 7 rings at varying heights
        var rings: [SCNVector3] = []
        for i in 0..<7 {
            let angle = Float(i) * 0.9
            let x = sin(angle) * 80
            let z = Float(i) * -200
            let y = Float(600 + (i % 3) * 200) // Alternating heights
            rings.append(SCNVector3(x, y, z))
        }
        return rings
    }

    private func generateSkyRaceRings() -> [SCNVector3] {
        // Stage 5: Tight race course, 20 rings
        var rings: [SCNVector3] = []
        for i in 0..<20 {
            let angle = Float(i) * 0.5
            let x = sin(angle) * 60 + cos(angle * 0.7) * 40
            let z = Float(i) * -120
            let y = Float(400) + sin(angle * 1.5) * 100
            rings.append(SCNVector3(x, y, z))
        }
        return rings
    }
}

// MARK: - Stage Presets

extension StageDefinition {
    static let allStages: [StageDefinition] = [
        StageDefinition(
            index: 0,
            name: "Sky Walk",
            koreanName: "하늘 산책",
            difficulty: 1,
            description: "링 10개 순서대로 통과",
            ringCount: 10,
            ringRadius: 50,
            timeLimit: nil,
            star3Time: 60,
            star3Condition: "60초 이내 완료",
            star2Condition: "완료",
            learningGoal: "기본 좌우/상하 조종"
        ),
        StageDefinition(
            index: 1,
            name: "Cloud Maze",
            koreanName: "구름 미로",
            difficulty: 2,
            description: "구름 기둥 사이 경로 비행, 체크포인트 5개",
            ringCount: 5,
            ringRadius: 40,
            timeLimit: 180,
            star3Time: 90,
            star3Condition: "접촉 0회 + 90초 이내",
            star2Condition: "완료",
            learningGoal: "고도 유지 + 좌우 미세 조정"
        ),
        StageDefinition(
            index: 2,
            name: "Valley Run",
            koreanName: "계곡 비행",
            difficulty: 3,
            description: "구불구불한 계곡 저공비행",
            ringCount: 8,
            ringRadius: 35,
            timeLimit: 180,
            star3Time: nil,
            star3Condition: "접촉 0회 + 별 5개 전체 수집",
            star2Condition: "완료",
            learningGoal: "연속 S자 비행"
        ),
        StageDefinition(
            index: 3,
            name: "Mountain Cross",
            koreanName: "산맥 넘기",
            difficulty: 4,
            description: "산봉우리 7개의 정상 링 통과",
            ringCount: 7,
            ringRadius: 25,
            timeLimit: 150,
            star3Time: 120,
            star3Condition: "전체 통과 + 120초 이내",
            star2Condition: "완료",
            learningGoal: "급격한 피치 전환 + 부스터 타이밍"
        ),
        StageDefinition(
            index: 4,
            name: "Sky Race",
            koreanName: "스카이 레이스",
            difficulty: 5,
            description: "에어 레이스 코스 완주 (링 20개 + S자 + 급선회)",
            ringCount: 20,
            ringRadius: 15,
            timeLimit: 120,
            star3Time: 80,
            star3Condition: "전체 통과 + 80초 이내 + 접촉 0회",
            star2Condition: "완료",
            learningGoal: "종합 기동"
        )
    ]
}
