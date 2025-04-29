//
//  MovementSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import ARKit
import RealityKit
import SwiftUI

@MainActor
final class MovementSystem: System {
    private static let query =
        EntityQuery(where: .has(MoveToComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard var move = entity.components[MoveToComponent.self],
                  let model = entity.findModelEntity()
            else { continue }

            // determine current sub-goal
            let nextTarget = currentGoal(for: &move,
                                         current: model.position(relativeTo: nil))
            // no target → arrived
            guard let goal = nextTarget else {
                model.components.set(PhysicsMotionComponent())
                entity.components.remove(MoveToComponent.self)
                continue
            }

            // move toward goal
            let here = model.position(relativeTo: nil)
            let distance = simd_distance(here, goal)

            if distance <= move.epsilon {
                // Arrived
                model.components.set(PhysicsMotionComponent())

                snapParentToModel(entity, to: model)

                switch move.strategy {
                case .direct:
                    // Path completed -> component removed
                    entity.components.remove(MoveToComponent.self)
                    continue

                case .pathfinding:
                    // For path-finding: remove the way-point reached
                    if !move.path.isEmpty { move.path.removeFirst() }
                    if move.path.isEmpty { // no way-points -> terminated
                        entity.components.remove(MoveToComponent.self)
                        continue
                    }
                }
            } else {
                let dir = normalize(goal - here)
                model.ensurePhysicsSupport()
                model.components.set(
                    PhysicsMotionComponent(linearVelocity: dir * move.speed)
                )
                snapParentToModel(entity, to: model)
            }
            entity.components.set(move) // persist any path edits
        }
    }

    /// Pop way-points for path-following.
    private func currentGoal(for move: inout MoveToComponent,
                             current: SIMD3<Float>) -> SIMD3<Float>?
    {
        switch move.strategy {
        case .direct:
            return move.destination

        case .pathfinding:
            // remove reached way-points
            while let first = move.path.first,
                  simd_distance(first, current) <= move.epsilon
            {
                move.path.removeFirst()
            }
            return move.path.first ?? nil
        }
    }

    func snapParentToModel(_ entity: Entity, to model: Entity) {
        // Snap parent so we don’t teleport on next flight
        entity.transform.translation = model.position(relativeTo: nil) // copy position
        entity.transform.rotation = model.orientation(relativeTo: nil)

        // Reset model local transform (keep scale so the bee size is constant)
        let scale = model.transform.scale
        model.transform = Transform(scale: scale,
                                    rotation: .init(),
                                    translation: .zero)
    }
}
