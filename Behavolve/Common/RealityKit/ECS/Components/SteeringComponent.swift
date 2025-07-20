//
//  SteeringComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import RealityKit

/// Optional behaviour to locally avoid obstacles or neighbors.
struct SteeringComponent: Component, Sendable {
    var avoidDistance: Float = 0.15 // meters
    var strength: Float = 1.0 // blend factor 0-1

    init(avoidDistance: Float = 0.15, strength: Float = 1.0) {
        self.avoidDistance = avoidDistance
        self.strength = strength
    }
}
