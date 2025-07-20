//
//  PalmOpenGestureComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 01/07/2025.
//

import Foundation
import RealityKit

struct PalmOpenGestureComponent: Component, Sendable {
    var requiredDuration: TimeInterval = 2.0
    var holdTime: TimeInterval = 0.0
}
