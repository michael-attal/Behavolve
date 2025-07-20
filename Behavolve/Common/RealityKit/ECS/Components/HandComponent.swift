//
//  HandComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import Foundation
import RealityKit

/// Links a RealityKit entity to an ARKit HandAnchor (by UUID).
struct HandComponent: Component, Sendable {
    var handID: UUID?
    var isCurrentlyTracked: Bool = false
    var trackedPosition: SIMD3<Float>? = nil
}
