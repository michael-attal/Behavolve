//
//  TargetReachedComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 26/06/2025.
//

import Foundation
import RealityKit

/// Stores the target and current positions of an entity moving toward a destination.
/// This component is removed by the `TargetReachedSystem` once the target is reached.
/// `precision` is in meter
struct TargetReachedComponent: Component, Sendable {
    var targetPosition: SIMD3<Float> = .zero
    var currentPosition: SIMD3<Float> = .zero
    var precision: Float = 0.17
}
