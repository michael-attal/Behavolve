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
    var amplitude: Float // metres (world)
    var frequency: Float // hertz
    var axis: SIMD3<Float> // world direction
    var phase: Float // radians
    var elapsedTime: TimeInterval // s
    var offset: SIMD3<Float> = .zero // current world offset
    var lastLocalOffset: SIMD3<Float> = .zero // previous LOCAL offset
    var basePosition: SIMD3<Float>? // idle reference (optional)

    init(amplitude: Float = 0.03,
         frequency: Float = 4.0,
         axis: SIMD3<Float> = .init(0, 1, 0),
         phase: Float = 0)
    {
        self.amplitude = amplitude
        self.frequency = frequency
        self.axis = axis
        self.phase = phase
        self.elapsedTime = 0
    }
}
