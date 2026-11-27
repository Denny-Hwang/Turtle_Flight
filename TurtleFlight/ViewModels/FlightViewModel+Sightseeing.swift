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
            /// A world's postcards reached half / all.
            case milestone(MapTheme, PostcardMilestone)
            case wonder(SkyWonder, isNew: Bool)
            case wonderBonus(SkyWonder, stars: Int)
            /// A set piece was flown through / touched. `stars` is what it
            /// paid (0 for lift / boost).
            case setPiece(SetPiece, isNew: Bool, stars: Int)
            /// Flew alongside a companion flock.
            case companion(Companion, stars: Int)
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
        let elapsed = sightseeingAccumulator
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
                    let world = nearest.placement.kind.world
                    if visit == .newPostcard,
                       let milestone = PostcardRewards.crossed(world: world, found: album.postcardCount(in: world)) {
                        // The bigger news wins the banner; it names the place too.
                        emitToast(.milestone(world, milestone))
                    } else {
                        emitToast(.postcard(nearest.placement.kind, isNew: visit == .newPostcard))
                    }
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
            let published = hint
            onMain { [weak self] in self?.landmarkHint = published }
        }

        updateWondersAndFestival(deltaTime: elapsed, position: position, heading: heading)
        updateSetPieces(deltaTime: elapsed, position: position, heading: heading)

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

    // MARK: - Festival + sky wonders

    func setUpFreeFlightExtras(scene: SCNScene, theme: MapTheme, mood: SkyMood, festival: Bool,
                               wonderSeed: Int?, around position: SCNVector3) {
        tearDownFreeFlightExtras()
        if festival {
            festivalLayer = FestivalLayer(parentNode: scene.rootNode, world: theme, around: position)
        }
        let seed = wonderSeed ?? Int.random(in: 0...Int(Int32.max))
        wonderPlan = SkyWonder.plan(world: theme, mood: mood, seed: seed)
        #if DEBUG
        // Screenshot / QA: `-TFWonder <name>` forces one, three seconds in.
        if let raw = UserDefaults.standard.string(forKey: "TFWonder"), let forced = SkyWonder(rawValue: raw) {
            wonderPlan = SkyWonder.Plan(wonder: forced, startTime: 3)
        }
        #endif
        wonderClock = 0
        wonderParent = scene.rootNode

        var forcedPiece: SetPiece?
        var piecesOn = true
        #if DEBUG
        // QA: `-TFSetPiece <name>` puts one three seconds in. Other
        // screenshot runs stay deterministic (no set pieces).
        forcedPiece = UserDefaults.standard.string(forKey: "TFSetPiece").flatMap(SetPiece.init(rawValue:))
        if ScreenshotDirector.isActive && forcedPiece == nil { piecesOn = false }
        #endif
        if piecesOn {
            setPieceScheduler = SetPieceScheduler(world: theme, seed: seed &+ 17, forced: forcedPiece)
        }
        var companionSoon = false
        var companionsOn = true
        #if DEBUG
        // QA: `-TFCompanion YES` brings the flock two seconds in.
        companionSoon = UserDefaults.standard.bool(forKey: "TFCompanion")
        if ScreenshotDirector.isActive && !companionSoon { companionsOn = false }
        #endif
        companionScheduler = companionsOn ? CompanionScheduler(seed: seed &+ 29, forcedSoon: companionSoon) : nil
        companionWorld = theme
        companionClock = 0
        setPieceClock = 0
        setPieceLastPosition = nil
    }

    func tearDownFreeFlightExtras() {
        festivalLayer?.remove()
        festivalLayer = nil
        activeWonder?.node.removeFromParentNode()
        activeWonder = nil
        wonderPlan = nil
        wonderClock = 0
        for active in activeSetPieces { active.node.removeFromParentNode() }
        activeSetPieces = []
        setPieceScheduler = nil
        setPieceLastPosition = nil
        flightEngine.externalLift = 0
        companionNode?.removeFromParentNode()
        companionNode = nil
        companionFlight = nil
        companionScheduler = nil
    }

    // MARK: - Companions (W4)

    /// Every frame in Free Flight: bring a flock in when one is due, fly
    /// it beside the character, pay the greeting star, see it off.
    func updateCompanions(deltaTime: Float, position: SCNVector3, heading: Float, speed: Float) {
        guard var scheduler = companionScheduler, let parent = wonderParent else { return }
        companionClock += deltaTime
        let p = SIMD3<Float>(position.x, position.y, position.z)
        if companionFlight == nil, scheduler.isDue(at: companionClock) {
            if activeWonder != nil {
                scheduler.postpone(from: companionClock)
            } else {
                let side = scheduler.take(at: companionClock)
                let companion = Companion.of(companionWorld)
                let flight = CompanionFlight(companion: companion, side: side, characterPosition: p, heading: heading)
                let node = CompanionFactory.build(companion)
                parent.addChildNode(node)
                companionFlight = flight
                companionNode = node
            }
            companionScheduler = scheduler
        }
        guard var flight = companionFlight, let node = companionNode else { return }
        let greeted = flight.step(deltaTime: deltaTime, characterPosition: p, heading: heading, speedMetresPerSecond: speed)
        node.position = SCNVector3(flight.position.x, flight.position.y, flight.position.z)
        node.eulerAngles.y = -flight.heading * .pi / 180
        node.opacity = CGFloat(flight.opacity)
        if greeted {
            awardWonderStars(Companion.greetStars)
            emitToast(.companion(flight.companion, stars: Companion.greetStars))
            onMain {
                AudioManager.shared.playStarCollect()
                Haptics.shared.play(.pickup)
            }
        }
        if flight.phase == .done {
            node.removeFromParentNode()
            companionFlight = nil
            companionNode = nil
        } else {
            companionFlight = flight
        }
    }

    // MARK: - Set pieces along the route

    /// Runs inside the throttled sightseeing tick: spawn the next piece
    /// ahead, pay out fly-throughs and touches, drive updrafts, and clear
    /// what has been left behind.
    func updateSetPieces(deltaTime: Float, position: SCNVector3, heading: Float) {
        guard var scheduler = setPieceScheduler, let parent = wonderParent else { return }
        setPieceClock += deltaTime
        let previous = setPieceLastPosition ?? position
        setPieceLastPosition = position

        var lift: Float = 0
        for i in activeSetPieces.indices {
            var active = activeSetPieces[i]
            let piece = active.piece
            switch piece.effect {
            case .passThrough:
                if !active.used, active.passes(from: previous, to: position) {
                    active.used = true
                    paySetPiece(piece, stars: SetPiece.passStars, alwaysToast: false)
                }
            case .lift:
                let inside = active.contains(position)
                if inside {
                    lift = SetPiece.liftRate
                    if !active.inLift { paySetPiece(piece, stars: 0, alwaysToast: !active.used) }
                    active.used = true
                }
                active.inLift = inside
            case .boost:
                if !active.used, active.contains(position) {
                    active.used = true
                    flightEngine.addBoostCharge(SetPiece.boostRefill)
                    paySetPiece(piece, stars: 0, alwaysToast: true)
                }
            case .stars:
                if !active.used, active.contains(position) {
                    active.used = true
                    active.node.childNode(withName: "live", recursively: false)?
                        .runAction(.fadeOut(duration: 0.4))
                    paySetPiece(piece, stars: SetPiece.bundleStars, alwaysToast: true)
                }
            }
            activeSetPieces[i] = active
        }
        flightEngine.externalLift = lift

        // Clear what is well behind or far off.
        activeSetPieces.removeAll { active in
            let dx = active.center.x - position.x, dz = active.center.z - position.z
            let gone = active.distancePast(position) > 450 || dx * dx + dz * dz > 1600 * 1600
            if gone { active.node.runAction(.sequence([.fadeOut(duration: 1), .removeFromParentNode()])) }
            return gone
        }

        if scheduler.isDue(at: setPieceClock), activeSetPieces.count < SetPieceScheduler.maxActive {
            let h = heading * .pi / 180
            let forward = SIMD2<Float>(sin(h), -cos(h))
            let mid = (SetPieceScheduler.spawnDistance.lowerBound + SetPieceScheduler.spawnDistance.upperBound) / 2
            let probe = SCNVector3(position.x + forward.x * mid, position.y, position.z + forward.y * mid)
            let nearLandmark = landmarkField?.nearest(to: probe).map { $0.distance < SetPieceScheduler.landmarkClearance } ?? false
            if activeWonder != nil || nearLandmark {
                scheduler.postpone(from: setPieceClock)
            } else {
                let next = scheduler.take(at: setPieceClock)
                let side = SIMD2<Float>(-forward.y, forward.x)
                let x = position.x + forward.x * next.distance + side.x * next.lateral
                let z = position.z + forward.y * next.distance + side.y * next.lateral
                let ground = Float(terrainGenerator?.heightAt(x: x, z: z) ?? 0)
                let floor = next.piece.effect == .lift ? ground + 60 : ground + next.piece.depthBelowCentre + 20
                let center = SCNVector3(x, max(position.y, floor), z)
                let node = SetPieceFactory.build(next.piece)
                node.position = center
                node.eulerAngles.y = -h
                parent.addChildNode(node)
                activeSetPieces.append(ActiveSetPiece(piece: next.piece, node: node, center: center, forward: forward))
            }
        }
        setPieceScheduler = scheduler
    }

    private func paySetPiece(_ piece: SetPiece, stars: Int, alwaysToast: Bool) {
        if stars > 0 { awardWonderStars(stars) }
        let isNew = SetPieceLog.shared.record(piece)
        if isNew || alwaysToast {
            emitToast(.setPiece(piece, isNew: isNew, stars: stars))
        }
        if isNew { Analytics.shared.track(.setPieceSeen, ["piece": piece.rawValue]) }
        let effect = piece.effect
        onMain {
            switch effect {
            case .passThrough:
                AudioManager.shared.playRingPass()
                Haptics.shared.play(.ringGreat)
            case .lift:
                Haptics.shared.play(.ringOk)
            case .boost:
                AudioManager.shared.playRingPass()
                Haptics.shared.play(.pickup)
            case .stars:
                AudioManager.shared.playStarCollect()
                Haptics.shared.play(.pickup)
            }
        }
    }

    /// Runs inside the throttled sightseeing tick.
    func updateWondersAndFestival(deltaTime: Float, position: SCNVector3, heading: Float) {
        festivalLayer?.update(deltaTime: deltaTime, playerPosition: position, heading: heading)
        wonderClock += deltaTime

        if let plan = wonderPlan, activeWonder == nil, wonderClock >= plan.startTime, let parent = wonderParent {
            wonderPlan = nil
            let node = WonderFactory.build(plan.wonder)
            let h = heading * .pi / 180
            let distance = SkyWonder.spawnDistance
            let y = max(position.y, Float(terrainGenerator?.heightAt(x: position.x, z: position.z) ?? 0) + 120)
            node.position = SCNVector3(position.x + sin(h) * distance, y, position.z - cos(h) * distance)
            node.eulerAngles.y = -h
            parent.addChildNode(node)
            activeWonder = (plan.wonder, node, wonderClock + SkyWonder.duration, false)
            let isNew = WonderLog.shared.record(plan.wonder)
            emitToast(.wonder(plan.wonder, isNew: isNew))
            Analytics.shared.track(.wonderSeen, ["wonder": plan.wonder.rawValue])
            onMain {
                AudioManager.shared.playRingPass()
                Haptics.shared.play(.discovery)
            }
        }

        guard var active = activeWonder else { return }
        if !active.bonusPaid {
            let a = WonderFactory.anchor(of: active.node)
            let d2 = pow(a.x - position.x, 2) + pow(a.y - position.y, 2) + pow(a.z - position.z, 2)
            if d2 < SkyWonder.bonusRadius * SkyWonder.bonusRadius {
                active.bonusPaid = true
                activeWonder = active
                awardWonderStars(SkyWonder.bonusStars)
                flashExpression(.joy, for: 1.5)
                emitToast(.wonderBonus(active.wonder, stars: SkyWonder.bonusStars))
                onMain {
                    AudioManager.shared.playStarCollect()
                    Haptics.shared.play(.pickup)
                }
            }
        }
        if wonderClock >= active.endsAt {
            let node = active.node
            node.runAction(.sequence([.fadeOut(duration: 2), .removeFromParentNode()]))
            activeWonder = nil
        }
    }

    /// Landmarks are solid in Free Flight: push the character back out
    /// and turn it away. No score, no penalty — just a bump.
    func bumpOffLandmarks() {
        guard let field = landmarkField,
              let hit = field.contact(at: flightEngine.state.position) else { return }
        flightEngine.resolveContact(normal: hit.normal, depth: hit.depth)
        let now = CACurrentMediaTime()
        guard now - lastLandmarkBumpTime > 0.6 else { return }
        lastLandmarkBumpTime = now
        flashExpression(.scared, for: 0.8)
        onMain {
            AudioManager.shared.playCollision()
            Haptics.shared.play(.landmarkBump)
        }
    }

    private func emitToast(_ kind: FlightToast.Kind) {
        toastCounter += 1
        let toast = FlightToast(id: toastCounter, kind: kind)
        onMain { [weak self] in self?.flightToast = toast }
    }
}
