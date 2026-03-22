import Foundation
import SceneKit

final class CharacterRegistry {
    static let shared = CharacterRegistry()

    private init() {}

    /// Get all available characters
    var allCharacters: [CharacterConfig] {
        CharacterType.allCases.map { $0.config }
    }

    /// Build a low-poly 3D character node
    func buildCharacterNode(for character: CharacterType) -> SCNNode {
        let rootNode = SCNNode()
        rootNode.name = character.rawValue

        switch character {
        case .turtle:
            rootNode.addChildNode(buildTurtle())
        case .penguin:
            rootNode.addChildNode(buildPenguin())
        case .hamster:
            rootNode.addChildNode(buildHamster())
        case .cat:
            rootNode.addChildNode(buildCat())
        case .frog:
            rootNode.addChildNode(buildFrog())
        case .bunny:
            rootNode.addChildNode(buildBunny())
        }

        return rootNode
    }

    /// Build a vehicle node
    func buildVehicleNode(for vehicle: VehicleType) -> SCNNode {
        let rootNode = SCNNode()
        rootNode.name = vehicle.rawValue

        switch vehicle {
        case .shellJet:
            rootNode.addChildNode(buildShellJet())
        case .bellyGlider:
            rootNode.addChildNode(buildBellyGlider())
        case .hamsterCopter:
            rootNode.addChildNode(buildHamsterCopter())
        case .magicBroom:
            rootNode.addChildNode(buildMagicBroom())
        case .balloonBody:
            rootNode.addChildNode(buildBalloonBody())
        case .earCopter:
            rootNode.addChildNode(buildEarCopter())
        case .cloudSurf:
            rootNode.addChildNode(buildCloudSurf())
        }

        return rootNode
    }

    // MARK: - Character Builders (Low-Poly Geometric)

    private func buildTurtle() -> SCNNode {
        let node = SCNNode()

        // Body (flattened sphere)
        let body = SCNNode(geometry: SCNSphere(radius: 0.5))
        body.scale = SCNVector3(1.2, 0.6, 1.0)
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x2ECC71)
        node.addChildNode(body)

        // Head
        let head = SCNNode(geometry: SCNSphere(radius: 0.2))
        head.position = SCNVector3(0, 0.15, -0.6)
        head.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x27AE60)
        node.addChildNode(head)

        // Goggles (small torus on head)
        let goggle = SCNNode(geometry: SCNTorus(ringRadius: 0.12, pipeRadius: 0.03))
        goggle.position = SCNVector3(0, 0.25, -0.65)
        goggle.eulerAngles.x = .pi / 2
        goggle.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xF39C12)
        node.addChildNode(goggle)

        // Legs (4 small cylinders)
        for (x, z) in [(-0.3, -0.2), (0.3, -0.2), (-0.3, 0.2), (0.3, 0.2)] as [(Float, Float)] {
            let leg = SCNNode(geometry: SCNCylinder(radius: 0.08, height: 0.2))
            leg.position = SCNVector3(x, -0.3, z)
            leg.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x27AE60)
            node.addChildNode(leg)
        }

        return node
    }

    private func buildPenguin() -> SCNNode {
        let node = SCNNode()

        // Body
        let body = SCNNode(geometry: SCNCapsule(capRadius: 0.3, height: 0.8))
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x2C3E50)
        node.addChildNode(body)

        // Belly (white front)
        let belly = SCNNode(geometry: SCNSphere(radius: 0.25))
        belly.position = SCNVector3(0, -0.05, -0.15)
        belly.scale = SCNVector3(0.8, 1.0, 0.5)
        belly.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xECF0F1)
        node.addChildNode(belly)

        // Scarf
        let scarf = SCNNode(geometry: SCNTorus(ringRadius: 0.25, pipeRadius: 0.04))
        scarf.position = SCNVector3(0, 0.2, 0)
        scarf.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xE74C3C)
        node.addChildNode(scarf)

        // Beak
        let beak = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.06, height: 0.12))
        beak.position = SCNVector3(0, 0.25, -0.3)
        beak.eulerAngles.x = -.pi / 2
        beak.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xF39C12)
        node.addChildNode(beak)

        return node
    }

    private func buildHamster() -> SCNNode {
        let node = SCNNode()

        // Body (round)
        let body = SCNNode(geometry: SCNSphere(radius: 0.35))
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xF0C27F)
        node.addChildNode(body)

        // Cheeks (puffed)
        for x: Float in [-0.2, 0.2] {
            let cheek = SCNNode(geometry: SCNSphere(radius: 0.15))
            cheek.position = SCNVector3(x, 0.05, -0.25)
            cheek.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xFFB88C)
            node.addChildNode(cheek)
        }

        // Ears
        for x: Float in [-0.2, 0.2] {
            let ear = SCNNode(geometry: SCNSphere(radius: 0.08))
            ear.position = SCNVector3(x, 0.35, 0)
            ear.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xFFB88C)
            node.addChildNode(ear)
        }

        return node
    }

    private func buildCat() -> SCNNode {
        let node = SCNNode()

        // Body
        let body = SCNNode(geometry: SCNCapsule(capRadius: 0.25, height: 0.7))
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x95A5A6)
        node.addChildNode(body)

        // Witch hat (cone)
        let hat = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.2, height: 0.4))
        hat.position = SCNVector3(0, 0.55, 0)
        hat.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x2C3E50)
        node.addChildNode(hat)

        // Hat brim
        let brim = SCNNode(geometry: SCNCylinder(radius: 0.25, height: 0.03))
        brim.position = SCNVector3(0, 0.38, 0)
        brim.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x2C3E50)
        node.addChildNode(brim)

        // Ears (triangular - use cones)
        for x: Float in [-0.15, 0.15] {
            let ear = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.06, height: 0.15))
            ear.position = SCNVector3(x, 0.4, 0)
            ear.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x95A5A6)
            node.addChildNode(ear)
        }

        // Tail
        let tail = SCNNode(geometry: SCNCapsule(capRadius: 0.03, height: 0.4))
        tail.position = SCNVector3(0, -0.1, 0.35)
        tail.eulerAngles.x = .pi / 4
        tail.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x95A5A6)
        node.addChildNode(tail)

        return node
    }

    private func buildFrog() -> SCNNode {
        let node = SCNNode()

        // Body (sphere, will inflate for balloon effect)
        let body = SCNNode(geometry: SCNSphere(radius: 0.4))
        body.name = "frogBody"
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x2ECC71)
        node.addChildNode(body)

        // Eyes (two big spheres on top)
        for x: Float in [-0.18, 0.18] {
            let eye = SCNNode(geometry: SCNSphere(radius: 0.12))
            eye.position = SCNVector3(x, 0.35, -0.15)
            eye.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xECF0F1)
            node.addChildNode(eye)

            let pupil = SCNNode(geometry: SCNSphere(radius: 0.06))
            pupil.position = SCNVector3(x, 0.35, -0.25)
            pupil.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x2C3E50)
            node.addChildNode(pupil)
        }

        // Legs (short, stubby)
        for (x, z) in [(-0.25, 0.15), (0.25, 0.15)] as [(Float, Float)] {
            let leg = SCNNode(geometry: SCNCapsule(capRadius: 0.06, height: 0.25))
            leg.position = SCNVector3(x, -0.3, z)
            leg.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x27AE60)
            node.addChildNode(leg)
        }

        return node
    }

    private func buildBunny() -> SCNNode {
        let node = SCNNode()

        // Body
        let body = SCNNode(geometry: SCNCapsule(capRadius: 0.25, height: 0.6))
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xECF0F1)
        node.addChildNode(body)

        // Long ears (will be propellers)
        for x: Float in [-0.1, 0.1] {
            let ear = SCNNode(geometry: SCNCapsule(capRadius: 0.04, height: 0.5))
            ear.name = "ear"
            ear.position = SCNVector3(x, 0.55, 0)
            ear.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xFFB8B8)
            node.addChildNode(ear)
        }

        // Flight goggles (red)
        let goggle = SCNNode(geometry: SCNTorus(ringRadius: 0.15, pipeRadius: 0.03))
        goggle.position = SCNVector3(0, 0.2, -0.15)
        goggle.eulerAngles.x = .pi / 2
        goggle.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xE74C3C)
        node.addChildNode(goggle)

        // Scarf (red)
        let scarf = SCNNode(geometry: SCNTorus(ringRadius: 0.2, pipeRadius: 0.035))
        scarf.position = SCNVector3(0, 0.1, 0)
        scarf.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xE74C3C)
        node.addChildNode(scarf)

        // Cotton tail
        let tail = SCNNode(geometry: SCNSphere(radius: 0.08))
        tail.position = SCNVector3(0, -0.15, 0.25)
        tail.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xFFFFFF)
        node.addChildNode(tail)

        return node
    }

    // MARK: - Vehicle Builders

    private func buildShellJet() -> SCNNode {
        let node = SCNNode()

        // Jet shell (flattened dome shape)
        let shell = SCNNode(geometry: SCNSphere(radius: 0.6))
        shell.scale = SCNVector3(1.2, 0.5, 1.0)
        shell.position = SCNVector3(0, 0.1, 0)
        shell.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x8B4513)
        node.addChildNode(shell)

        // Shell pattern lines
        let pattern = SCNNode(geometry: SCNTorus(ringRadius: 0.5, pipeRadius: 0.02))
        pattern.position = SCNVector3(0, 0.2, 0)
        pattern.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xA0522D)
        node.addChildNode(pattern)

        // Flame emitter position marker
        let flamePoint = SCNNode()
        flamePoint.name = "flameEmitter"
        flamePoint.position = SCNVector3(0, 0, 0.7)
        node.addChildNode(flamePoint)

        return node
    }

    private func buildBellyGlider() -> SCNNode {
        let node = SCNNode()
        // Invisible vehicle - penguin glides on belly
        // Just add wing-like fins
        for x: Float in [-0.5, 0.5] {
            let wing = SCNNode(geometry: SCNBox(width: 0.4, height: 0.03, length: 0.2, chamferRadius: 0.01))
            wing.position = SCNVector3(x, -0.1, 0)
            wing.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x2C3E50)
            node.addChildNode(wing)
        }
        return node
    }

    private func buildHamsterCopter() -> SCNNode {
        let node = SCNNode()

        // Hamster ball (transparent sphere)
        let ball = SCNNode(geometry: SCNSphere(radius: 0.5))
        ball.name = "hamsterBall"
        ball.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x3498DB)
        ball.geometry?.firstMaterial?.transparency = 0.4
        node.addChildNode(ball)

        // Propeller on top
        let prop = SCNNode(geometry: SCNBox(width: 0.8, height: 0.02, length: 0.1, chamferRadius: 0))
        prop.name = "propeller"
        prop.position = SCNVector3(0, 0.55, 0)
        prop.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x95A5A6)
        node.addChildNode(prop)

        return node
    }

    private func buildMagicBroom() -> SCNNode {
        let node = SCNNode()

        // Broomstick
        let stick = SCNNode(geometry: SCNCylinder(radius: 0.03, height: 1.5))
        stick.eulerAngles.z = .pi / 2
        stick.position = SCNVector3(0, -0.3, 0)
        stick.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x8B4513)
        node.addChildNode(stick)

        // Bristles (cone at back)
        let bristles = SCNNode(geometry: SCNCone(topRadius: 0.02, bottomRadius: 0.15, height: 0.3))
        bristles.position = SCNVector3(0, -0.3, 0.8)
        bristles.eulerAngles.x = .pi / 2
        bristles.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xF39C12)
        node.addChildNode(bristles)

        return node
    }

    private func buildBalloonBody() -> SCNNode {
        let node = SCNNode()
        // The frog itself becomes the balloon - minimal vehicle
        // Just add a string hanging below
        let string = SCNNode(geometry: SCNCylinder(radius: 0.01, height: 0.5))
        string.position = SCNVector3(0, -0.6, 0)
        string.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xECF0F1)
        node.addChildNode(string)
        return node
    }

    private func buildEarCopter() -> SCNNode {
        let node = SCNNode()
        // Ears act as propeller - minimal vehicle base
        // Small platform
        let platform = SCNNode(geometry: SCNCylinder(radius: 0.15, height: 0.03))
        platform.position = SCNVector3(0, -0.3, 0)
        platform.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xBDC3C7)
        node.addChildNode(platform)
        return node
    }

    private func buildCloudSurf() -> SCNNode {
        let node = SCNNode()

        // Cloud surfboard
        let cloud = SCNNode(geometry: SCNSphere(radius: 0.5))
        cloud.scale = SCNVector3(2.0, 0.4, 1.0)
        cloud.position = SCNVector3(0, -0.4, 0)
        cloud.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xECF0F1)
        cloud.geometry?.firstMaterial?.transparency = 0.85
        node.addChildNode(cloud)

        // Smaller cloud puffs
        for (x, z) in [(-0.3, 0.2), (0.4, -0.1), (-0.1, -0.3)] as [(Float, Float)] {
            let puff = SCNNode(geometry: SCNSphere(radius: 0.2))
            puff.position = SCNVector3(x, -0.35, z)
            puff.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xECF0F1)
            puff.geometry?.firstMaterial?.transparency = 0.8
            node.addChildNode(puff)
        }

        return node
    }

    // MARK: - Helpers

    private func colorFromHex(_ hex: Int) -> Any {
        #if canImport(UIKit)
        return UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
        #else
        return NSColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
        #endif
    }
}
