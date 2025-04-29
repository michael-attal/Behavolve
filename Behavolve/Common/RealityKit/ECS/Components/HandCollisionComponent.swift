//
//  HandCollisionComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import Foundation
import RealityKit

/// Immediate impulse when a hand collides with the entity.
struct HandCollisionComponent: Component, Sendable {
    var collisionDistance: Float = 0.20 // m
    var impulseStrength: Float = 1.00 // linear-impulse magnitude
    var recoverDuration: TimeInterval = 3.0 // panic time
}
