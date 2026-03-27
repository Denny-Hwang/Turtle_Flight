import Foundation
import SceneKit

final class CharacterAnimator {
    private var animationTime: Float = 0

    /// Apply flight pose animations based on character + vehicle combination
    func applyFlightPose(
        to characterNode: SCNNode,
        vehicleNode: SCNNode,
        rollInput: Double,
        pitchInput: Double,
        speed: Float,
        isBoosting: Bool,
        character: CharacterType,
        vehicle: VehicleType,
        deltaTime: Float
    ) {
        animationTime += deltaTime

        // Common: Banking angle based on roll
        characterNode.eulerAngles.z = Float(-rollInput * 0.3)
        characterNode.eulerAngles.x = Float(pitchInput * 0.2)

        // Vehicle-specific animations
        switch vehicle {
        case .shellJet:
            animateShellJet(vehicleNode, isBoosting: isBoosting, speed: speed)

        case .bellyGlider:
            animateBellyGlider(characterNode, vehicleNode,
                               pitchInput: pitchInput, speed: speed)

        case .hamsterCopter:
            animateHamsterCopter(vehicleNode, speed: speed, deltaTime: deltaTime)

        case .magicBroom:
            animateMagicBroom(characterNode, vehicleNode,
                              rollInput: rollInput, speed: speed)

        case .balloonBody:
            animateBalloonBody(characterNode, vehicleNode,
                               altitude: characterNode.position.y,
                               isBoosting: isBoosting)

        case .earCopter:
            animateEarCopter(characterNode, vehicleNode,
                             pitchInput: pitchInput, speed: speed, deltaTime: deltaTime)

        case .cloudSurf:
            animateCloudSurf(characterNode, vehicleNode,
                             rollInput: rollInput, speed: speed)
        }
    }

    // MARK: - Vehicle-Specific Animations

    private func animateShellJet(_ vehicleNode: SCNNode, isBoosting: Bool, speed: Float) {
        // Flame particle intensity based on boost
        if let flameEmitter = vehicleNode.childNode(withName: "flameEmitter", recursively: true) {
            let scale = isBoosting ? Float(1.5) : Float(0.8)
            flameEmitter.scale = SCNVector3(scale, scale, scale)
        }

        // Shell vibration when boosting (SET, not +=, to avoid drift)
        if isBoosting {
            let wobble = sin(animationTime * 30) * 0.01
            vehicleNode.position.y = -0.3 + wobble
        } else {
            vehicleNode.position.y = -0.3
        }
    }

    private func animateBellyGlider(
        _ characterNode: SCNNode,
        _ vehicleNode: SCNNode,
        pitchInput: Double,
        speed: Float
    ) {
        // Wing flapping frequency based on speed
        let flapSpeed = speed / 200.0 * 3.0
        let flapAngle = sin(animationTime * flapSpeed) * 0.15

        vehicleNode.enumerateChildNodes { node, _ in
            if node.geometry is SCNBox {
                node.eulerAngles.z = flapAngle
            }
        }

        // Tilt body up when climbing
        characterNode.eulerAngles.x += Float(pitchInput * 0.1)
    }

    private func animateHamsterCopter(_ vehicleNode: SCNNode, speed: Float, deltaTime: Float) {
        // Propeller rotation proportional to speed (use actual deltaTime, not hardcoded)
        if let propeller = vehicleNode.childNode(withName: "propeller", recursively: true) {
            let rotationSpeed = speed / 100.0 * 10.0
            propeller.eulerAngles.y += rotationSpeed * deltaTime
        }

        // Ball rotation
        if let ball = vehicleNode.childNode(withName: "hamsterBall", recursively: true) {
            ball.eulerAngles.x += speed / 200.0 * deltaTime * 3.0
        }
    }

    private func animateMagicBroom(
        _ characterNode: SCNNode,
        _ vehicleNode: SCNNode,
        rollInput: Double,
        speed: Float
    ) {
        // Tail/scarf wind physics - sway with speed
        let swayAmount = sin(animationTime * 4) * 0.05 * (speed / 200.0)
        vehicleNode.eulerAngles.z = swayAmount

        // Cat ears flatten on sharp turns
        if abs(rollInput) > 0.7 {
            characterNode.childNodes.filter { $0.geometry is SCNCone }.forEach { ear in
                ear.eulerAngles.x = Float(rollInput) * 0.3
            }
        }
    }

    private func animateBalloonBody(
        _ characterNode: SCNNode,
        _ vehicleNode: SCNNode,
        altitude: Float,
        isBoosting: Bool
    ) {
        // Body size changes with altitude
        if let frogBody = characterNode.childNode(withName: "frogBody", recursively: true) {
            let scale = 1.0 + (altitude / 5000.0) * 0.3
            frogBody.scale = SCNVector3(scale, scale, scale)
        }

        // Boost = air deflating (shrink briefly, then propel)
        if isBoosting {
            let deflate = 1.0 - sin(animationTime * 10) * 0.1
            characterNode.scale = SCNVector3(deflate, deflate, deflate)
        } else {
            characterNode.scale = SCNVector3(1, 1, 1)
        }
    }

    private func animateEarCopter(
        _ characterNode: SCNNode,
        _ vehicleNode: SCNNode,
        pitchInput: Double,
        speed: Float,
        deltaTime: Float
    ) {
        // Ears rotate like propellers (use actual deltaTime, not hardcoded)
        let earRotationSpeed = speed / 100.0 * 15.0
        characterNode.enumerateChildNodes { node, _ in
            if node.name == "ear" {
                node.eulerAngles.y += earRotationSpeed * deltaTime
            }
        }

        // Jump pose when ascending, ears fold when descending
        if pitchInput > 0.3 {
            // Ascending - jump pose
            characterNode.position.y += sin(animationTime * 5) * 0.02
        }
    }

    private func animateCloudSurf(
        _ characterNode: SCNNode,
        _ vehicleNode: SCNNode,
        rollInput: Double,
        speed: Float
    ) {
        // Cloud bobbing (SET, not +=, to avoid drift)
        let bob = sin(animationTime * 2) * 0.03
        vehicleNode.position.y = -0.3 + bob

        // Surfing stance lean during turns
        characterNode.eulerAngles.z = Float(-rollInput * 0.2)

        // Cloud trail particles intensity with speed
        let trailScale = speed / 200.0
        vehicleNode.childNodes.forEach { puff in
            if puff.geometry is SCNSphere {
                let s = 1.0 + trailScale * 0.2
                puff.scale = SCNVector3(s, s, s)
            }
        }
    }
}
