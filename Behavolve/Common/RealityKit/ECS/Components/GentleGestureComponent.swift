//
//  GentleGestureComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 01/07/2025.
//

import RealityKit
import simd

/// Stores motion statistics for abrupt-gesture detection.
struct GentleGestureComponent: Component, Sendable {
    /// Maximum allowed smoothed speed (m/s).
    var maxSpeed: Float = 5

    /// Exponential-moving-average factor (0‒1).
    /// Higher = more inertia, less jitter.
    var smoothing: Float = 0.9

    var lastPosition: SIMD3<Float> = .zero
    var smoothedSpeed: Float = .zero
}
