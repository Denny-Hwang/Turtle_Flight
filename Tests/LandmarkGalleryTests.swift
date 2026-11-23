import XCTest
import SceneKit
@testable import TurtleFlight

/// Not a check: renders every landmark from two angles under its world's
/// lights into one PNG per landmark, for before/after reviews of
/// landmark art (docs/VISUAL_AUDIO_PLAN.md V6–V7). Skipped unless run with
/// `TEST_RUNNER_TF_GALLERY=<output dir>`:
///
///   TEST_RUNNER_TF_GALLERY=$PWD/build/gallery xcodebuild test … \
///     -only-testing:TurtleFlightTests/LandmarkGalleryTests
final class LandmarkGalleryTests: XCTestCase {

    func testRenderGallery() throws {
        guard let dir = ProcessInfo.processInfo.environment["TF_GALLERY"], !dir.isEmpty else {
            throw XCTSkip("set TEST_RUNNER_TF_GALLERY to render the landmark gallery")
        }
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("no Metal device") }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let only = ProcessInfo.processInfo.environment["TF_GALLERY_KINDS"].flatMap { $0.isEmpty ? nil : $0.split(separator: " ").map(String.init) }

        for kind in LandmarkKind.allCases where only?.contains(kind.rawValue) ?? true {
            let shots = [render(kind, yaw: 0.6, device: device), render(kind, yaw: -2.2, device: device)]
            let size = shots[0].size
            let sheet = UIGraphicsImageRenderer(size: CGSize(width: size.width * 2, height: size.height)).image { _ in
                shots[0].draw(at: .zero)
                shots[1].draw(at: CGPoint(x: size.width, y: 0))
            }
            try sheet.pngData()!.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(kind.rawValue).png"))
        }
    }

    private func render(_ kind: LandmarkKind, yaw: Float, device: MTLDevice) -> UIImage {
        let world = kind.world
        let scene = SCNScene()
        scene.background.contents = world.backgroundColor
        let node: SCNNode
        if ProcessInfo.processInfo.environment["TF_GALLERY_RAW", default: ""].isEmpty == false {
            let parts = LandmarkFactory.styledParts(kind)
            parts.moving.forEach { parts.root.addChildNode($0) }
            node = parts.root
        } else {
            node = LandmarkFactory.build(kind)
        }
        scene.rootNode.addChildNode(node)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = world.ambientLightIntensity
        ambient.light?.color = world.ambientLightColor
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = world.sunLightIntensity
        sun.light?.color = world.sunLightColor
        sun.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sun)

        // Frame the whole landmark from a 3/4 view, a little above.
        // (A flattened clone has no bounds until it is drawn: measure the parts.)
        let (lo, hi) = LandmarkFactory.styledParts(kind).root.boundingBox
        let centre = SCNVector3((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2)
        let radius = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z) * 0.5
        let distance = radius * 2.6
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zFar = Double(distance * 4)
        camera.camera?.fieldOfView = 45
        camera.position = SCNVector3(centre.x + sin(yaw) * distance, centre.y + distance * 0.35,
                                     centre.z + cos(yaw) * distance)
        camera.look(at: centre)
        scene.rootNode.addChildNode(camera)

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        return renderer.snapshot(atTime: 1, with: CGSize(width: 640, height: 480), antialiasingMode: .multisampling4X)
    }
}
