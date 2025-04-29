//
//  ExitGestureComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import Foundation
import RealityKit

/// Tracks how long a fist has been held.
/// `requiredDuration` – seconds needed to trigger the exit gesture.
struct ExitGestureComponent: Component, Sendable {
    var requiredDuration: TimeInterval = 2.0
    var holdTime: TimeInterval = 0.0
}
