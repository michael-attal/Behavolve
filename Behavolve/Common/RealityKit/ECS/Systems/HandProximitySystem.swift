//
//  HandProximitySystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import RealityKit

@MainActor
final class HandProximitySystem: @MainActor System {
    static var dependencies: [SystemDependency] { [.before(UserProximitySystem.self)] }

    private static let handQuery = EntityQuery(
        where: .has(HandComponent.self)
    )

    private static let entityWithHandProximityQuery = EntityQuery(
        where: .has(HandProximityComponent.self) && !.has(FleeStateComponent.self)
    )

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let hands = context.scene.performQuery(Self.handQuery)

        for entity in context.scene.performQuery(Self.entityWithHandProximityQuery) {
            guard let model = entity.findModelEntity(),
                  let cfg = entity.components[HandProximityComponent.self] else { continue }

            // Find the nearest hand.
            guard let nearest = hands.min(by: { a, b in
                simd_distance(a.position(relativeTo: nil), model.position(relativeTo: nil)) <
                    simd_distance(b.position(relativeTo: nil), model.position(relativeTo: nil))
            }) else { continue }

            let dist = simd_distance(model.position(relativeTo: nil),
                                     nearest.position(relativeTo: nil))

            if dist < cfg.safeDistance {
                // Compute an escape target 1.5× farther in the opposite direction.
                let dir = normalize(model.position(relativeTo: nil) -
                    nearest.position(relativeTo: nil))
                var target = model.position(relativeTo: nil) + dir * cfg.safeDistance * 1.5

                if cfg.fleeDuration == .infinity {
                    // target *= Float(cfg.fleeDuration)
                    target *= 20
                }

                // Replace ongoing MoveTo if any.
                entity.components.remove(MoveToComponent.self)
                entity.components.set(
                    MoveToComponent(destination: target,
                                    speed: cfg.fleeSpeed,
                                    epsilon: 0.02)
                )
                entity.components.set(LookAtTargetComponent(target: .world(target)))
                entity.components.set(FleeStateComponent(timeRemaining: cfg.fleeDuration))
            }
        }
    }
}
