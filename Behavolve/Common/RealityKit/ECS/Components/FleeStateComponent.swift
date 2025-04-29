//
//  FleeStateComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import Foundation
import RealityKit

/// Temporary marker: entity is currently fleeing.
struct FleeStateComponent: Component, Sendable {
    var timeRemaining: TimeInterval
}
