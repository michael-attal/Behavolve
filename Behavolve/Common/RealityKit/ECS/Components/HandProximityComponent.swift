//
//  HandProximityComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import Foundation
import RealityKit

/// Configuration for gentle flee when a hand gets too close.
struct HandProximityComponent: Component, Sendable {
    var safeDistance: Float = 0.30 // m
    var fleeSpeed: Float = 0.50 // m/s
    var fleeDuration: TimeInterval = 2.0 // s
}
