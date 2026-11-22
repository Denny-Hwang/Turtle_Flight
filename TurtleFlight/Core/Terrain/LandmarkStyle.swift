import Foundation
import SceneKit
import UIKit

/// V6 (docs/VISUAL_AUDIO_PLAN.md): one material language for all 25
/// landmarks, so the primitive shapes read as painted toys instead of
/// flat-coloured blocks. Applied once per landmark after it is built:
///
/// - **Gradient** — each piece is a little darker and cooler at its foot
///   and a little brighter at its top (in the landmark's own space, so it
///   works whatever height the landmark stands at).
/// - **Soft toon light** — the sun falls off in two soft bands instead of
///   a smooth lambert slope, which gives the shapes clean light/shade
///   sides without hard cel edges.
/// - **Rim light** — a thin glow on the edges facing away from the
///   camera, tinted per world, that pulls the silhouette off the terrain.
///
/// Everything is a SceneKit shader modifier (no Metal pipeline, no
/// textures). Glowing parts (`.constant`) keep their flat look.
enum LandmarkStyle {

    /// Range of the gradient, in the node's local y.
    static let bottomKey = "lmBottom"
    static let topKey = "lmTop"
    static let rimKey = "lmRim"

    static let surfaceModifier = """
    #pragma arguments
    float lmBottom;
    float lmTop;
    float3 lmRim;
    #pragma body
    float3 lmLocal = (scn_node.inverseModelViewTransform * float4(_surface.position, 1.0)).xyz;
    float lmT = clamp((lmLocal.y - lmBottom) / max(lmTop - lmBottom, 1.0), 0.0, 1.0);
    _surface.diffuse.rgb *= mix(float3(0.66, 0.70, 0.82), float3(1.0, 1.0, 0.98), lmT);
    float lmFacing = 1.0 - clamp(dot(_surface.normal, _surface.view), 0.0, 1.0);
    _surface.emission.rgb += lmRim * (lmFacing * lmFacing * lmFacing) * (0.3 + 0.5 * lmT);
    """

    /// Two soft bands (shade ~0.25, lit ~0.6) over a gentle lambert slope
    /// (up to +0.3), so faces keep their form; peaks at 0.9 so whites
    /// do not blow out.
    static let lightingModifier = """
    #pragma body
    float lmNdotL = dot(_surface.normal, _light.direction);
    float lmBand = 0.25 * smoothstep(-0.3, 0.0, lmNdotL) + 0.35 * smoothstep(0.15, 0.3, lmNdotL) + 0.3 * clamp(lmNdotL, 0.0, 1.0);
    _lightingContribution.diffuse += lmBand * _light.intensity.rgb;
    """

    /// Rim colour per world: warm in the day worlds, cool at sea and in space.
    static func rimColor(for world: MapTheme) -> SIMD3<Float> {
        switch world {
        case .sky:    return SIMD3(0.42, 0.40, 0.34)
        case .desert: return SIMD3(0.45, 0.32, 0.20)
        case .city:   return SIMD3(0.36, 0.38, 0.44)
        case .seoul:  return SIMD3(0.42, 0.34, 0.38)
        case .wild:   return SIMD3(0.40, 0.36, 0.26)
        case .space:  return SIMD3(0.24, 0.22, 0.40)
        case .ocean:  return SIMD3(0.20, 0.40, 0.45)
        }
    }

    /// Restyle every lit material under `root`, with one gradient over
    /// the whole subtree measured in `root`'s space (the space the
    /// flattened mesh is drawn in).
    static func apply(to root: SCNNode, world: MapTheme) {
        let rim = rimColor(for: world)
        let (lo, hi) = root.boundingBox
        for m in litMaterials(under: root) {
            style(m, bottom: lo.y, top: hi.y, rim: rim)
        }
    }

    static func litMaterials(under root: SCNNode) -> [SCNMaterial] {
        var out: [SCNMaterial] = []
        func walk(_ node: SCNNode) {
            out += (node.geometry?.materials ?? []).filter { $0.lightingModel != .constant }
            node.childNodes.forEach(walk)
        }
        walk(root)
        return out
    }

    static func style(_ m: SCNMaterial, bottom: Float, top: Float, rim: SIMD3<Float>) {
        m.lightingModel = .lambert
        m.shaderModifiers = [.surface: surfaceModifier, .lightingModel: lightingModifier]
        m.setValue(NSNumber(value: bottom), forKey: bottomKey)
        m.setValue(NSNumber(value: top), forKey: topKey)
        m.setValue(NSValue(scnVector3: SCNVector3(rim.x, rim.y, rim.z)), forKey: rimKey)
    }
}
