//
//  SteeringSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import RealityKit

@MainActor
final class SteeringSystem: System {
    private static let query =
        EntityQuery(where: .has(SteeringComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard let steer = entity.components[SteeringComponent.self],
                  var move = entity.components[MoveToComponent.self],
                  let model = entity.findModelEntity()
            else { continue }

            // minimal avoidance: shift first way-point if too close to obstacle
            if var first = move.path.first {
                if simd_distance(first, entity.position(relativeTo: nil)) < steer.avoidDistance {
                    first += SIMD3<Float>(x: .random(in: -0.1...0.1),
                                          y: 0,
                                          z: .random(in: -0.1...0.1)) * steer.strength
                    move.path[0] = first
                    entity.components.set(move)
                }
            }
        }
    }
}
