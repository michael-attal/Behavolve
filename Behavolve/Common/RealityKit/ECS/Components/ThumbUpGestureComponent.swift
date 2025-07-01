//
//  ThumbUpGestureComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 01/07/2025.
//

import Foundation
import RealityKit

/// Tracks how long a thumbs up has been held.
/// `requiredDuration` – seconds needed to trigger the thumbs up gesture.
struct ThumbUpGestureComponent: Component, Sendable {
    var requiredDuration: TimeInterval = 2.0
    var holdTime: TimeInterval = 0.0
}
