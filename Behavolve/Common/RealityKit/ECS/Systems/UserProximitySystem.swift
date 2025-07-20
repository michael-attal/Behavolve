//
//  UserProximitySystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import RealityKit

@MainActor
final class UserProximitySystem: System {
    private static let entityWithUserProximityQuery = EntityQuery(
        where: .has(UserProximityComponent.self) && !.has(FleeStateComponent.self)
    )

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        // Headset position maintained by LookAtTargetSystem.
        let userPos = LookAtTargetSystem.shared.devicePoseSafe.value.translation

        for entity in context.scene.performQuery(Self.entityWithUserProximityQuery) {
            guard let model = entity.findModelEntity(),
                  let cfg = entity.components[UserProximityComponent.self] else { continue }

            let dist = simd_distance(model.position(relativeTo: nil), userPos)
            if dist < cfg.safeDistance {
                let dir = normalize(model.position(relativeTo: nil) - userPos)
                let target = model.position(relativeTo: nil) + dir * cfg.safeDistance * 1.2

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
