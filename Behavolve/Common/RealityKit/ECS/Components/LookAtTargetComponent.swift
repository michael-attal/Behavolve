//
//  LookAtTargetComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 30/01/2025.
//

import RealityKit

struct LookAtTargetComponent: Component {
    enum Target {
        case device
        case world(SIMD3<Float>)
    }

    let target: Target
    let targetCorrection: ((SIMD3<Float>, SIMD3<Float>) -> SIMD3<Float>)?

    init(target: Target, targetCorrection: ((_ entityPosition: SIMD3<Float>, _ actualTargetPosition: SIMD3<Float>) -> SIMD3<Float>)? = nil) {
        self.target = target
        self.targetCorrection = targetCorrection
    }
}
