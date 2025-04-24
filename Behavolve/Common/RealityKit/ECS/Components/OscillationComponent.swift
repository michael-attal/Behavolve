//
//  OscillationComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import Foundation
import RealityKit

/// Apply a sinusoidal offset to an entity’s position.
/// `elapsedTime` is updated par `OscillationSystem` with `deltaTime`.
struct OscillationComponent: Component, Sendable {
    var amplitude: Float // meters
    var frequency: Float // hertz
    var axis: SIMD3<Float> // direction
    var phase: Float // rad
    var basePosition: SIMD3<Float>? // captured first frame
    var elapsedTime: TimeInterval // internal clock

    init(amplitude: Float = 0.01,
         frequency: Float = 3.0,
         axis: SIMD3<Float> = .init(0, 1, 0),
         phase: Float = 0)
    {
        self.amplitude = amplitude
        self.frequency = frequency
        self.axis = axis
        self.phase = phase
        self.basePosition = nil
        self.elapsedTime = 0
    }
}
