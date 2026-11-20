import Foundation
import SceneKit

/// Free Flight sightseeing: landmarks to discover (→ postcards) and
/// friendly creatures to greet. None of it runs during missions, so
/// scores and leaderboards are untouched.
extension FlightViewModel {

    /// Where the nearest landmark this character has not visited is.
    struct LandmarkHint: Equatable {
        let kind: LandmarkKind
        /// Metres, rounded to 10 so the chip is not redrawn every frame.
        let distance: Int
        /// Radians, relative to the nose: 0 = ahead, + = to the right.
        let bearing: Double

        static func make(kind: LandmarkKind, from position: SCNVector3, heading: Float,
                         to focus: SCNVector3) -> LandmarkHint {
            let dx = focus.x - position.x
            let dy = focus.y - position.y
            let dz = focus.z - position.z
            let distance = sqrt(dx * dx + dy * dy + dz * dz)
            // Heading 0 = -Z (north), clockwise positive — same
            // convention as the compass and the autopilot.
            var target = atan2(dx, -dz) * 180 / .pi
            if target < 0 { target += 360 }
            var relative = Double(target - heading)
            while relative > 180 { relative -= 360 }
            while relative < -180 { relative += 360 }
            // 15° buckets: enough for an arrow, quiet for SwiftUI.
            let bucketed = (relative / 15).rounded() * 15
            return LandmarkHint(kind: kind,
                                distance: Int((distance / 10).rounded()) * 10,
                                bearing: bucketed * .pi / 180)
        }
    }

    /// One-shot banner over the flight view.
    struct FlightToast: Equatable {
        enum Kind: Equatable {
            case postcard(LandmarkKind, isNew: Bool)
            case hello
        }
        let id: Int
        let kind: Kind
    }

    /// How close counts as "flying by" a friend.
    static let helloRadius: Float = 30
    /// Sightseeing checks run at 5 Hz — plenty for 150-unit spheres.
    static let sightseeingInterval: Float = 0.2

    /// Called every frame from `update`; throttled internally.
    func updateSightseeing(deltaTime: Float, position: SCNVector3, heading: Float) {
        // `startStage` drops the field, so this is Free Flight only.
        guard let field = landmarkField else { return }
        sightseeingAccumulator += deltaTime
        guard sightseeingAccumulator >= Self.sightseeingInterval else { return }
        sightseeingAccumulator = 0

        field.update(playerPosition: position)

        // Landmarks → postcards.
        let character = currentCharacter
        let album = PostcardAlbum.shared
        let visited = Set(field.placements.map(\.kind).filter { album.hasStamp($0, by: character) })
        var hint: LandmarkHint?
        if let nearest = field.nearest(to: position, excluding: visited) {
            if nearest.distance < LandmarkField.discoveryRadius {
                let visit = album.recordVisit(nearest.placement.kind, by: character)
                if visit != .alreadyStamped {
                    emitToast(.postcard(nearest.placement.kind, isNew: visit == .newPostcard))
                    Analytics.shared.track(.landmarkDiscovered, ["landmark": nearest.placement.kind.rawValue])
                    onMain {
                        AudioManager.shared.playStageClear()
                        Haptics.shared.play(.discovery)
                    }
                }
            } else {
                hint = LandmarkHint.make(kind: nearest.placement.kind, from: position,
                                         heading: heading, to: nearest.placement.focus)
            }
        }
        if hint != lastSimLandmarkHint {
            lastSimLandmarkHint = hint
            onMain { [weak self] in self?.landmarkHint = hint }
        }

        // Friends → hello.
        for friend in terrainGenerator?.ungreetedFriends() ?? [] {
            let p = friend.worldPosition
            let d2 = pow(p.x - position.x, 2) + pow(p.y - position.y, 2) + pow(p.z - position.z, 2)
            guard d2 < Self.helloRadius * Self.helloRadius else { continue }
            friend.name = "greeted"
            // A happy little hop back.
            friend.runAction(.sequence([.scale(by: 1.3, duration: 0.15), .scale(by: 1 / 1.3, duration: 0.25)]))
            awardHelloStar()
            emitToast(.hello)
            onMain {
                AudioManager.shared.playStarCollect()
                Haptics.shared.play(.pickup)
            }
        }
    }

    private func emitToast(_ kind: FlightToast.Kind) {
        toastCounter += 1
        let toast = FlightToast(id: toastCounter, kind: kind)
        onMain { [weak self] in self?.flightToast = toast }
    }
}
