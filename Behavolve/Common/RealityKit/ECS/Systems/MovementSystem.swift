//
// MovementSystem.swift
// Behavolve
//
// Final fix 29/04/2025 – Robust arrival detection
//

import ARKit
import RealityKit
import SwiftUI

@MainActor
final class MovementSystem: System {
    private static let query = EntityQuery(where: .has(MoveToComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)

        for entity in context.scene.performQuery(Self.query) {
            guard let move = entity.components[MoveToComponent.self],
                  let model = entity.findModelEntity()
            else { continue }

            let currentPos = entity.transform.translation

            guard let goal = currentGoal(for: move, current: currentPos) else {
                model.components.set(PhysicsMotionComponent())
                entity.components.remove(MoveToComponent.self)
                continue
            }

            let distance = simd_distance(currentPos, goal)

            let dirToGoal = normalize(goal - currentPos)
            let currentVelocity = dirToGoal * move.speed
            let nextPos = currentPos + currentVelocity * dt

            let hasPassedGoal = simd_dot(goal - currentPos, goal - nextPos) <= 0

            if distance <= move.epsilon || hasPassedGoal {
                // Arrived
                model.components.set(PhysicsMotionComponent())
                entity.components.remove(MoveToComponent.self)

                RealityKitHelper.snapParentToPositionWithPosition(entity, to: model, with: goal)
                continue
            }

            model.ensurePhysicsSupport()
            model.components.set(
                PhysicsMotionComponent(linearVelocity: currentVelocity)
            )

            entity.transform.translation += currentVelocity * dt
            entity.transform.rotation = model.orientation(relativeTo: nil)
            RealityKitHelper.snapParentToModel(entity, to: model)
        }
    }

    private func currentGoal(for move: MoveToComponent,
                             current: SIMD3<Float>) -> SIMD3<Float>?
    {
        switch move.strategy {
        case .direct:
            return move.destination
        case .pathfinding:
            var path = move.path
            while let first = path.first,
                  simd_distance(first, current) <= move.epsilon
            {
                path.removeFirst()
            }
            return path.first
        }
    }
}
