//
//  UserProximityComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import Foundation
import RealityKit

/// Configuration for fleeing when the headset (user) is too close.
struct UserProximityComponent: Component, Sendable {
    var safeDistance: Float = 1.00 // m
    var fleeSpeed: Float = 0.50 // m/s
    var fleeDuration: TimeInterval = 2.0 // s
}
