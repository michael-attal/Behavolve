//
//  SIMD+Extensions.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 30/01/2025.
//

import simd

extension SIMD3 where Scalar: ExpressibleByIntegerLiteral {
    static func dx(_ value: Scalar = 1) -> SIMD3<Scalar> {
        return SIMD3<Scalar>(value, 0, 0)
    }

    static func dy(_ value: Scalar = 1) -> SIMD3<Scalar> {
        return SIMD3<Scalar>(0, value, 0)
    }

    static func dz(_ value: Scalar = 1) -> SIMD3<Scalar> {
        return SIMD3<Scalar>(0, 0, value)
    }

    func with(_ keyPath: WritableKeyPath<Self, Scalar>, _ value: Scalar) -> Self {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}

extension simd_float4x4 {
    static let identity: simd_float4x4 = matrix_identity_float4x4

    func translated(by translation: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(columns: (SIMD4(.dx(), 0), SIMD4(.dy(), 0), SIMD4(.dz(), 0), SIMD4(translation, 1)))*self
    }

    func rotated(by rotation: simd_quatf) -> simd_float4x4 {
        simd_float4x4(rotation)*self
    }

    func scaled(by scale: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(diagonal: SIMD4(scale, 1))*self
    }

    func scaled(by scale: Float) -> simd_float4x4 {
        simd_float4x4(diagonal: SIMD4(SIMD3(repeating: scale), 1))*self
    }

    func transformed(by transform: simd_float4x4) -> simd_float4x4 {
        transform*self
    }

    func relative(to targetBaseInWorld: simd_float4x4, from originBaseInWorld: simd_float4x4 = .identity) -> simd_float4x4 {
        return if originBaseInWorld == .identity {
            targetBaseInWorld*self
        } else {
            targetBaseInWorld*originBaseInWorld.inverse*self
        }
    }
}

extension Double {
    @inline(__always) var degreesToRadians: Double { return self * .pi / 180 }
}

// matrix_float4x4 -> SIMD3 translation
extension simd_float4x4 {
    @inline(__always)
    var position: SIMD3<Float> { [columns.3.x, columns.3.y, columns.3.z] }
}

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3(x, y, z) }
}
