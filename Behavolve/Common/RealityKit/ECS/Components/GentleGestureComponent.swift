//
//  GentleGestureComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 01/07/2025.
//

import Foundation
import RealityKit
import simd

/// Stores motion statistics for abrupt-gesture detection.
struct GentleGestureComponent: Component, Sendable {
    /// Maximum allowed smoothed speed (m/s).
    var maxSpeed: Float = 1.4

    /// Exponential-moving-average factor (0‒1).
    /// Higher = more inertia, less jitter.
    var smoothing: Float = 0.75

    var lastPosition: SIMD3<Float>?
    var smoothedSpeed: Float = .zero

    var graceRemaining: Float = 0
    var overFrames: Int = 0
}
