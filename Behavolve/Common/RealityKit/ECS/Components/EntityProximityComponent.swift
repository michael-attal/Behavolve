//
//  EntityProximityComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 06/07/2025.
//

import Foundation
import RealityKit

/// Track the distance between an entity and the user.
struct EntityProximityComponent: Component, Sendable {
    var distanceToUser: Float = 0.00 // m
    var targetDistanceToUser: Float = 10.00
}
