// Benchmark example (benchmark/PLAN.md B6) — NOT part of the app target.
//
// Only if B0 measurement shows GPU pressure. meshoptimizer has a plain C
// API and no dependencies, so it can be vendored as a local SwiftPM
// package (see benchmark/notes/rendering-mesh.md for the Package.swift
// and module map). Guarded so this file type-checks without it.

#if canImport(MeshOpt)
import MeshOpt
import SceneKit

enum MeshOptBridge {
    /// Reorder triangles for the GPU's post-transform vertex cache.
    /// Same triangles, same look; fewer vertex shader runs.
    static func optimizeVertexCache(_ indices: [Int32], vertexCount: Int) -> [Int32] {
        let src = indices.map { UInt32(bitPattern: $0) }
        var dst = [UInt32](repeating: 0, count: src.count)
        meshopt_optimizeVertexCache(&dst, src, src.count, vertexCount)
        return dst.map { Int32(bitPattern: $0) }
    }

    /// A lower-detail index buffer over the same vertices, for
    /// `SCNLevelOfDetail`. `ratio` 0.5 = aim for half the triangles;
    /// `maxError` is relative to the mesh size (0.01 = 1%).
    static func simplify(_ indices: [Int32], positions: [SCNVector3],
                         ratio: Float, maxError: Float = 0.01) -> (indices: [Int32], error: Float) {
        let src = indices.map { UInt32(bitPattern: $0) }
        // The destination must hold index_count entries, not the target.
        var dst = [UInt32](repeating: 0, count: src.count)
        let target = max(3, Int(Float(src.count) * ratio) / 3 * 3)
        var error: Float = 0
        let count = positions.withUnsafeBytes { raw in
            meshopt_simplify(&dst, src, src.count,
                             raw.baseAddress!.assumingMemoryBound(to: Float.self),
                             positions.count, MemoryLayout<SCNVector3>.stride,
                             target, maxError, 0, &error)
        }
        return (dst.prefix(count).map { Int32(bitPattern: $0) }, error)
    }
}

// Use in a background prebuild (landmark pool), never on the render thread:
//
//   let lod1 = MeshOptBridge.simplify(element.indices, positions: verts, ratio: 0.4)
//   let far = SCNGeometry(sources: geometry.sources,
//                         elements: [SCNGeometryElement(indices: lod1.indices, primitiveType: .triangles)])
//   far.materials = geometry.materials
//   geometry.levelsOfDetail = [SCNLevelOfDetail(geometry: far, screenSpaceRadius: 60)]
#endif
