import RealityKit
import simd

enum CylinderMeshFactory {
    @MainActor
    static func make(radius: Float, height: Float, segments: Int = 48) throws -> MeshResource {
        precondition(segments >= 12)
        let halfHeight = height * 0.5
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for index in 0..<segments {
            let angle = Float(index) / Float(segments) * 2 * .pi
            let x = cos(angle) * radius
            let z = sin(angle) * radius
            let normal = simd_normalize(SIMD3<Float>(x, 0, z))
            positions.append(SIMD3<Float>(x, -halfHeight, z))
            positions.append(SIMD3<Float>(x, halfHeight, z))
            normals.append(normal)
            normals.append(normal)
        }

        for index in 0..<segments {
            let next = (index + 1) % segments
            let bottom = UInt32(index * 2)
            let top = bottom + 1
            let nextBottom = UInt32(next * 2)
            let nextTop = nextBottom + 1
            indices.append(contentsOf: [bottom, nextBottom, top, top, nextBottom, nextTop])
        }

        let bottomCenter = UInt32(positions.count)
        positions.append(SIMD3<Float>(0, -halfHeight, 0))
        normals.append(SIMD3<Float>(0, -1, 0))
        let topCenter = UInt32(positions.count)
        positions.append(SIMD3<Float>(0, halfHeight, 0))
        normals.append(SIMD3<Float>(0, 1, 0))

        let bottomRingStart = UInt32(positions.count)
        for index in 0..<segments {
            let angle = Float(index) / Float(segments) * 2 * .pi
            positions.append(SIMD3<Float>(cos(angle) * radius, -halfHeight, sin(angle) * radius))
            normals.append(SIMD3<Float>(0, -1, 0))
        }
        let topRingStart = UInt32(positions.count)
        for index in 0..<segments {
            let angle = Float(index) / Float(segments) * 2 * .pi
            positions.append(SIMD3<Float>(cos(angle) * radius, halfHeight, sin(angle) * radius))
            normals.append(SIMD3<Float>(0, 1, 0))
        }

        for index in 0..<segments {
            let next = (index + 1) % segments
            indices.append(contentsOf: [
                bottomCenter,
                bottomRingStart + UInt32(next),
                bottomRingStart + UInt32(index),
                topCenter,
                topRingStart + UInt32(index),
                topRingStart + UInt32(next),
            ])
        }

        var descriptor = MeshDescriptor(name: "MeasuredCoinCylinder")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}
