import Foundation
import SceneKit
import UIKit

/// A big, named place the player can discover in Free Flight. All of
/// them are original designs: "inspired by the kind of place" (a
/// pyramid field, an iron lattice tower, a hilltop broadcast tower…),
/// never a model of a specific real monument, and the names are our own.
/// Raw values are persisted in the postcard album — never rename a case.
enum LandmarkKind: String, CaseIterable, Codable {
    // sky
    case floatingCastle, rainbowGate, windmillHill
    // desert
    case greatPyramids, sandGuardian, palmOasis, sunObelisk
    // city
    case ironLaceTower, grandArch, riverBridge, skyWheel
    // seoul
    case hilltopTower, palaceGate, hanokVillage, moonBridge
    // wild
    case greatFalls, canyonArch, auroraPeak, giantTree
    // space
    case ringPlanet, spaceStation, moonBase
    // ocean
    case shipwreck, seaVolcano, shellPalace

    var displayName: String { L10n.t("landmark.\(rawValue).name") }

    var world: MapTheme {
        switch self {
        case .floatingCastle, .rainbowGate, .windmillHill:              return .sky
        case .greatPyramids, .sandGuardian, .palmOasis, .sunObelisk:    return .desert
        case .ironLaceTower, .grandArch, .riverBridge, .skyWheel:       return .city
        case .hilltopTower, .palaceGate, .hanokVillage, .moonBridge:    return .seoul
        case .greatFalls, .canyonArch, .auroraPeak, .giantTree:         return .wild
        case .ringPlanet, .spaceStation, .moonBase:                     return .space
        case .shipwreck, .seaVolcano, .shellPalace:                     return .ocean
        }
    }

    /// SF Symbol used on the postcard and the HUD compass chip.
    var symbol: String {
        switch self {
        case .floatingCastle: return "building.columns.fill"
        case .rainbowGate:    return "rainbow"
        case .windmillHill:   return "fanblades.fill"
        case .greatPyramids:  return "triangle.fill"
        case .sandGuardian:   return "pawprint.fill"
        case .palmOasis:      return "drop.fill"
        case .sunObelisk:     return "sun.max.fill"
        case .ironLaceTower:  return "antenna.radiowaves.left.and.right"
        case .grandArch:      return "door.left.hand.open"
        case .riverBridge:    return "road.lanes"
        case .skyWheel:       return "circle.dashed"
        case .hilltopTower:   return "dot.radiowaves.up.forward"
        case .palaceGate:     return "house.lodge.fill"
        case .hanokVillage:   return "house.fill"
        case .moonBridge:     return "moon.fill"
        case .greatFalls:     return "drop.triangle.fill"
        case .canyonArch:     return "mountain.2.fill"
        case .auroraPeak:     return "sparkles"
        case .giantTree:      return "tree.fill"
        case .ringPlanet:     return "circle.circle.fill"
        case .spaceStation:   return "dot.radiowaves.left.and.right"
        case .moonBase:       return "moon.stars.fill"
        case .shipwreck:      return "sailboat.fill"
        case .seaVolcano:     return "flame.fill"
        case .shellPalace:    return "crown.fill"
        }
    }

    /// Where the landmark sits: on the terrain, or hanging at a fixed
    /// altitude (castles in the air, planets, stations).
    var fixedAltitude: Float? {
        switch self {
        case .floatingCastle: return 430
        case .rainbowGate:    return 380
        case .ringPlanet:     return 520
        case .spaceStation:   return 480
        default:              return nil
        }
    }

    /// Height above the landmark's base that the player aims for; the
    /// discovery sphere is centred there.
    var focusHeight: Float {
        switch self {
        case .ironLaceTower, .hilltopTower, .auroraPeak, .giantTree: return 150
        case .greatPyramids, .greatFalls, .skyWheel:                 return 100
        case .floatingCastle, .rainbowGate, .ringPlanet, .spaceStation: return 0
        default:                                                     return 60
        }
    }

    static func kinds(in world: MapTheme) -> [LandmarkKind] {
        WorldProfile.profile(for: world).landmarks
    }
}

/// Keeps the landmarks near the player in the scene. The world is cut
/// into square cells; each cell holds exactly one landmark, picked and
/// placed by a hash of the cell so the map is the same on every flight
/// and a place found once can be found again.
/// `@unchecked Sendable`: everything is render-thread only except
/// `pool`, which background builders fill and is only touched under
/// `poolLock`.
final class LandmarkField: @unchecked Sendable {
    struct Placement: Equatable {
        let kind: LandmarkKind
        let cell: SIMD2<Int32>
        /// Base position (terrain height or fixed altitude).
        let position: SCNVector3
        /// Point the discovery sphere is centred on.
        var focus: SCNVector3 {
            SCNVector3(position.x, position.y + kind.focusHeight, position.z)
        }

        static func == (a: Placement, b: Placement) -> Bool { a.kind == b.kind && a.cell == b.cell }
    }

    /// Side of one cell. 1200 units ≈ 20 s of level flight between places.
    static let cellSize: Float = 1200
    /// Fly within this distance of the focus point to discover it.
    static let discoveryRadius: Float = 150

    private let parentNode: SCNNode
    private let kinds: [LandmarkKind]
    private let seed: Int
    private let heightAt: (Float, Float) -> Float
    private var loaded: [SIMD2<Int32>: (placement: Placement, node: SCNNode)] = [:]

    /// Landmarks built ahead of time off the render thread, by kind.
    /// Crossing into a new cell row used to build three landmarks on the
    /// render thread: a 67–100 ms hitch every 1.2 km on the iPhone XS
    /// Free Flight soak (2026-11-27). Behind `poolLock`.
    private var pool: [LandmarkKind: [SCNNode]] = [:]
    private let poolLock = NSLock()
    /// Built nodes kept ready per kind (a new row is three cells).
    static let poolDepth = 2

    init(parentNode: SCNNode, world: MapTheme, seed: Int = 42,
         heightAt: @escaping (Float, Float) -> Float) {
        self.parentNode = parentNode
        var kinds = LandmarkKind.kinds(in: world)
        #if DEBUG
        // Screenshot `tour` aimed at one landmark: every cell holds it.
        if let only = ScreenshotDirector.tourKind, only.world == world { kinds = [only] }
        #endif
        self.kinds = kinds
        self.seed = seed
        self.heightAt = heightAt
        for kind in Set(kinds) { for _ in 0..<Self.poolDepth { refill(kind) } }
    }

    /// Build one `kind` in the background into the pool.
    private func refill(_ kind: LandmarkKind) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let node = LandmarkFactory.build(kind)
            guard let self else { return }
            self.poolLock.lock()
            if self.pool[kind, default: []].count < Self.poolDepth { self.pool[kind, default: []].append(node) }
            self.poolLock.unlock()
        }
    }

    /// A ready-built landmark if one is waiting (and another queued),
    /// otherwise built here.
    private func take(_ kind: LandmarkKind) -> SCNNode {
        poolLock.lock()
        let ready = pool[kind]?.popLast()
        poolLock.unlock()
        refill(kind)
        return ready ?? LandmarkFactory.build(kind)
    }

    /// Nodes waiting in the pool (tests).
    var pooledCount: Int {
        poolLock.lock(); defer { poolLock.unlock() }
        return pool.values.reduce(0) { $0 + $1.count }
    }

    /// Deterministic placement for a cell. Pure, so tests can pin it.
    static func placement(cell: SIMD2<Int32>, kinds: [LandmarkKind], seed: Int,
                          heightAt: (Float, Float) -> Float) -> Placement? {
        guard !kinds.isEmpty else { return nil }
        // The spawn cell stays empty: the player starts there and the
        // first landmark should be something they fly *to*.
        if cell == SIMD2<Int32>(0, 0) { return nil }
        var rng = SeededRandom(seed: Int(cell.x) &* 73_856_093 ^ Int(cell.y) &* 19_349_663 ^ seed &* 83_492_791)
        // Walk the list by cell so neighbours differ, then jitter.
        // x + 2y steps through the list so that, for 3 or 4 kinds, the
        // east and south neighbours are always a different place.
        let index = ((Int(cell.x) &+ Int(cell.y) &* 2) % kinds.count + kinds.count) % kinds.count
        let kind = kinds[index]
        let jitter = cellSize * 0.28
        let x = (Float(cell.x) + 0.5) * cellSize + rng.nextFloat(in: -1...1) * jitter
        let z = (Float(cell.y) + 0.5) * cellSize + rng.nextFloat(in: -1...1) * jitter
        let y = kind.fixedAltitude ?? max(heightAt(x, z), 0)
        return Placement(kind: kind, cell: cell, position: SCNVector3(x, y, z))
    }

    static func cell(for position: SCNVector3) -> SIMD2<Int32> {
        SIMD2<Int32>(Int32(floor(position.x / cellSize)), Int32(floor(position.z / cellSize)))
    }

    /// Load the 3×3 cells around the player, drop the rest.
    func update(playerPosition: SCNVector3) {
        let centre = Self.cell(for: playerPosition)
        var needed = Set<SIMD2<Int32>>()
        for dx in -1...1 {
            for dz in -1...1 {
                needed.insert(SIMD2<Int32>(centre.x + Int32(dx), centre.y + Int32(dz)))
            }
        }
        for key in loaded.keys where !needed.contains(key) {
            loaded[key]?.node.removeFromParentNode()
            loaded.removeValue(forKey: key)
        }
        for key in needed where loaded[key] == nil {
            guard let placement = Self.placement(cell: key, kinds: kinds, seed: seed, heightAt: heightAt) else { continue }
            let node = take(placement.kind)
            node.position = placement.position
            node.name = "landmark_\(placement.kind.rawValue)"
            parentNode.addChildNode(node)
            loaded[key] = (placement, node)
        }
    }

    func clear() {
        loaded.values.forEach { $0.node.removeFromParentNode() }
        loaded.removeAll()
    }

    var placements: [Placement] { loaded.values.map(\.placement) }

    /// Nearest loaded landmark, optionally skipping kinds already found.
    func nearest(to position: SCNVector3, excluding found: Set<LandmarkKind> = []) -> (placement: Placement, distance: Float)? {
        var best: (Placement, Float)?
        for (placement, _) in loaded.values where !found.contains(placement.kind) {
            let f = placement.focus
            let d = sqrt(pow(f.x - position.x, 2) + pow(f.y - position.y, 2) + pow(f.z - position.z, 2))
            if best == nil || d < best!.1 { best = (placement, d) }
        }
        return best.map { (placement: $0.0, distance: $0.1) }
    }
}
