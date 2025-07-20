//
//  CalmMotionComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 01/07/2025.
//

import RealityKit
import simd

/// Tracks smoothed head linear speed to detect abrupt user movement.
struct CalmMotionComponent: Component, Sendable {
    var maxHeadSpeed: Float = 1.2 // m/s
    var smoothing: Float = 0.9

    /// Last smoothed speed value.
    var smoothedSpeed: Float = 0
}
