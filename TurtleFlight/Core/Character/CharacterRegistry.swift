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
        case .cushionBalloon:
            rootNode.addChildNode(buildCushionBalloon())
        case .balloonBody:
            rootNode.addChildNode(buildBalloonBody())
        case .carrotJet:
            rootNode.addChildNode(buildCarrotJet())
        case .cloudSurf:
            rootNode.addChildNode(buildCloudSurf())
        }

        return rootNode
    }

    // MARK: - Character Builders (Low-Poly Geometric)

    // Palette references trace back to docs/CHARACTER_DESIGN_PROMPT.md.

    private func buildTurtle() -> SCNNode {
        let node = SCNNode()

        // Body (flattened sphere) — Turbo primary mint
        let body = SCNNode(geometry: SCNSphere(radius: 0.5))
        body.scale = SCNVector3(1.2, 0.6, 1.0)
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x5DCAA5)
        node.addChildNode(body)

        // Head
        let head = SCNNode(geometry: SCNSphere(radius: 0.2))
        head.position = SCNVector3(0, 0.15, -0.6)
        head.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x1D9E75)
        node.addChildNode(head)

        // Aviator goggles (brass frame)
        let goggle = SCNNode(geometry: SCNTorus(ringRadius: 0.12, pipeRadius: 0.03))
        goggle.position = SCNVector3(0, 0.25, -0.65)
        goggle.eulerAngles.x = .pi / 2
        goggle.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xBA7517)
        node.addChildNode(goggle)

        // Red aviator scarf (Turbo signature)
        let scarf = SCNNode(geometry: SCNTorus(ringRadius: 0.22, pipeRadius: 0.04))
        scarf.position = SCNVector3(0, 0.05, -0.45)
        scarf.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xE24B4A)
        node.addChildNode(scarf)

        // Legs (4 small cylinders)
        for (x, z) in [(-0.3, -0.2), (0.3, -0.2), (-0.3, 0.2), (0.3, 0.2)] as [(Float, Float)] {
            let leg = SCNNode(geometry: SCNCylinder(radius: 0.08, height: 0.2))
            leg.position = SCNVector3(x, -0.3, z)
            leg.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x1D9E75)
            node.addChildNode(leg)
        }

        return node
    }

    private func buildPenguin() -> SCNNode {
        let node = SCNNode()

        // Body — sky-blue tuxedo (NOT black, per design spec)
        let body = SCNNode(geometry: SCNCapsule(capRadius: 0.3, height: 0.8))
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x378ADD)
        node.addChildNode(body)

        // White belly (classic tuxedo shape)
        let belly = SCNNode(geometry: SCNSphere(radius: 0.25))
        belly.position = SCNVector3(0, -0.05, -0.15)
        belly.scale = SCNVector3(0.8, 1.0, 0.5)
        belly.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xFFFFFF)
        node.addChildNode(belly)

        // Mohawk tuft (darker feathers)
        let mohawk = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.05, height: 0.1))
        mohawk.position = SCNVector3(0, 0.5, -0.05)
        mohawk.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x185FA5)
        node.addChildNode(mohawk)

        // Beak — orange
        let beak = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.06, height: 0.12))
        beak.position = SCNVector3(0, 0.25, -0.3)
        beak.eulerAngles.x = -.pi / 2
        beak.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xEF9F27)
        node.addChildNode(beak)

        return node
    }

    private func buildHamster() -> SCNNode {
        let node = SCNNode()

        // Body — Nutty primary orange fur
        let body = SCNNode(geometry: SCNSphere(radius: 0.35))
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xEF9F27)
        node.addChildNode(body)

        // ASYMMETRIC cheeks: right cheek noticeably bigger (more stuffed)
        let cheekL = SCNNode(geometry: SCNSphere(radius: 0.13))
        cheekL.position = SCNVector3(-0.2, 0.05, -0.25)
        cheekL.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xFAC775)
        node.addChildNode(cheekL)

        let cheekR = SCNNode(geometry: SCNSphere(radius: 0.17))
        cheekR.position = SCNVector3(0.22, 0.04, -0.25)
        cheekR.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xFAC775)
        node.addChildNode(cheekR)

        // Ears with pink inner
        for x: Float in [-0.2, 0.2] {
            let ear = SCNNode(geometry: SCNSphere(radius: 0.08))
            ear.position = SCNVector3(x, 0.35, 0)
            ear.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xBA7517)
            node.addChildNode(ear)
        }

        return node
    }

    private func buildCat() -> SCNNode {
        let node = SCNNode()

        // Body — Mochi lavender fur (NOT gray)
        let body = SCNNode(geometry: SCNCapsule(capRadius: 0.25, height: 0.7))
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xCECBF6)
        node.addChildNode(body)

        // Pointed ears with dark purple tips
        for x: Float in [-0.15, 0.15] {
            let ear = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.06, height: 0.15))
            ear.position = SCNVector3(x, 0.4, 0)
            ear.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x534AB7)
            node.addChildNode(ear)
        }

        // Bell collar — red ribbon + gold bell (Mochi signature)
        let collar = SCNNode(geometry: SCNTorus(ringRadius: 0.22, pipeRadius: 0.025))
        collar.position = SCNVector3(0, 0.18, 0)
        collar.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xE24B4A)
        node.addChildNode(collar)

        let bell = SCNNode(geometry: SCNSphere(radius: 0.04))
        bell.position = SCNVector3(0, 0.13, -0.22)
        bell.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xEF9F27)
        node.addChildNode(bell)

        // Long S-curve tail with darker tip
        let tail = SCNNode(geometry: SCNCapsule(capRadius: 0.03, height: 0.45))
        tail.position = SCNVector3(0, -0.1, 0.35)
        tail.eulerAngles.x = .pi / 4
        tail.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xCECBF6)
        node.addChildNode(tail)

        let tailTip = SCNNode(geometry: SCNSphere(radius: 0.04))
        tailTip.position = SCNVector3(0, 0.08, 0.55)
        tailTip.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x534AB7)
        node.addChildNode(tailTip)

        return node
    }

    private func buildFrog() -> SCNNode {
        let node = SCNNode()

        // Body — Bounce primary lime (distinct from Turbo's mint)
        let body = SCNNode(geometry: SCNSphere(radius: 0.4))
        body.name = "frogBody"
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x97C459)
        node.addChildNode(body)

        // Bulging eyes (largest of all 6 characters per spec)
        for x: Float in [-0.18, 0.18] {
            let eye = SCNNode(geometry: SCNSphere(radius: 0.13))
            eye.position = SCNVector3(x, 0.36, -0.15)
            eye.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xFFFFFF)
            node.addChildNode(eye)

            let pupil = SCNNode(geometry: SCNSphere(radius: 0.06))
            pupil.position = SCNVector3(x, 0.36, -0.26)
            pupil.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x27500A)
            node.addChildNode(pupil)
        }

        // Legs — darker green spots
        for (x, z) in [(-0.25, 0.15), (0.25, 0.15)] as [(Float, Float)] {
            let leg = SCNNode(geometry: SCNCapsule(capRadius: 0.06, height: 0.25))
            leg.position = SCNVector3(x, -0.3, z)
            leg.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x639922)
            node.addChildNode(leg)
        }

        return node
    }

    private func buildBunny() -> SCNNode {
        let node = SCNNode()

        // Body — Hoppy primary peach fur (NOT white)
        let body = SCNNode(geometry: SCNCapsule(capRadius: 0.25, height: 0.6))
        body.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xF0997B)
        node.addChildNode(body)

        // ASYMMETRIC ears: left upright, right droops (Hoppy signature)
        let earL = SCNNode(geometry: SCNCapsule(capRadius: 0.04, height: 0.5))
        earL.name = "ear"
        earL.position = SCNVector3(-0.1, 0.55, 0)
        earL.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xF0997B)
        node.addChildNode(earL)

        let earR = SCNNode(geometry: SCNCapsule(capRadius: 0.04, height: 0.5))
        earR.name = "ear"
        earR.position = SCNVector3(0.12, 0.5, 0.05)
        earR.eulerAngles.z = -0.35     // droop
        earR.eulerAngles.x = 0.15      // tilt forward
        earR.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xF0997B)
        node.addChildNode(earR)

        // White heart-shaped chest patch
        let chest = SCNNode(geometry: SCNSphere(radius: 0.12))
        chest.position = SCNVector3(0, 0.05, -0.2)
        chest.scale = SCNVector3(1.0, 1.1, 0.4)
        chest.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xF5C4B3)
        node.addChildNode(chest)

        // Flower behind left ear (Hoppy signature accessory)
        let flower = SCNNode(geometry: SCNSphere(radius: 0.045))
        flower.position = SCNVector3(-0.16, 0.78, 0.02)
        flower.scale = SCNVector3(1.0, 0.4, 1.0)
        flower.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xED93B1)
        node.addChildNode(flower)

        // Cotton ball tail
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

    private func buildCushionBalloon() -> SCNNode {
        let node = SCNNode()

        // Cushion-basket (cat-bed-shaped, plush lavender)
        let basket = SCNNode(geometry: SCNCylinder(radius: 0.45, height: 0.18))
        basket.position = SCNVector3(0, -0.4, 0)
        basket.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xAFA9EC)
        node.addChildNode(basket)

        // Plush cushion edge (slightly larger torus)
        let cushion = SCNNode(geometry: SCNTorus(ringRadius: 0.45, pipeRadius: 0.06))
        cushion.position = SCNVector3(0, -0.32, 0)
        cushion.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xCECBF6)
        node.addChildNode(cushion)

        // Hot air balloon envelope (smooth lavender)
        let balloon = SCNNode(geometry: SCNSphere(radius: 0.5))
        balloon.scale = SCNVector3(1.0, 1.2, 1.0)
        balloon.position = SCNVector3(0, 0.45, 0)
        balloon.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xCECBF6)
        node.addChildNode(balloon)

        // 4 thin ropes from basket to balloon
        for (x, z) in [(-0.35, -0.35), (0.35, -0.35), (-0.35, 0.35), (0.35, 0.35)] as [(Float, Float)] {
            let rope = SCNNode(geometry: SCNCylinder(radius: 0.005, height: 0.7))
            rope.position = SCNVector3(x * 0.7, 0, z * 0.7)
            rope.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x7F77DD)
            node.addChildNode(rope)
        }

        // Lavender flame emitter marker (heating the balloon)
        let flameMarker = SCNNode()
        flameMarker.name = "flameEmitter"
        flameMarker.position = SCNVector3(0, -0.05, 0)
        node.addChildNode(flameMarker)

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

    private func buildCarrotJet() -> SCNNode {
        let node = SCNNode()

        // Streamlined carrot body (long capsule, orange)
        let carrot = SCNNode(geometry: SCNCapsule(capRadius: 0.18, height: 1.1))
        carrot.eulerAngles.x = .pi / 2          // lay along Z (forward)
        carrot.position = SCNVector3(0, -0.25, 0)
        carrot.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xEF9F27)
        node.addChildNode(carrot)

        // Pointed nose (carrot tip — darker orange)
        let nose = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.18, height: 0.28))
        nose.eulerAngles.x = -.pi / 2
        nose.position = SCNVector3(0, -0.25, -0.7)
        nose.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0xBA7517)
        node.addChildNode(nose)

        // Leafy tail fins (3 layered cones at the back)
        for (x, y, scaleY) in [(0.0, 0.05, 1.2), (-0.1, -0.05, 1.0), (0.1, -0.05, 1.0)] as [(Float, Float, Float)] {
            let leaf = SCNNode(geometry: SCNCone(topRadius: 0.0, bottomRadius: 0.07, height: 0.25))
            leaf.position = SCNVector3(x, -0.25 + y, 0.6)
            leaf.eulerAngles.x = .pi / 2
            leaf.scale = SCNVector3(1, scaleY, 1)
            leaf.geometry?.firstMaterial?.diffuse.contents = colorFromHex(0x97C459)
            node.addChildNode(leaf)
        }

        // Heart-shaped exhaust marker (used by particle system later)
        let heartTrail = SCNNode()
        heartTrail.name = "flameEmitter"
        heartTrail.position = SCNVector3(0, -0.25, 0.7)
        node.addChildNode(heartTrail)

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
