//
//  HandCollisionSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import ARKit
import RealityKit

@MainActor
final class HandCollisionSystem: System {
    static var dependencies: [SystemDependency] { [.before(HandProximitySystem.self)] }

    private static let handQuery = EntityQuery(where: .has(HandComponent.self))
    private static let entityWithHandCollisionQuery = EntityQuery(where: .has(HandCollisionComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let hands = context.scene.performQuery(Self.handQuery)

        for entity in context.scene.performQuery(Self.entityWithHandCollisionQuery) {
            guard let model = entity.findModelEntity(),
                  let cfg = entity.components[HandCollisionComponent.self] else { continue }

            for hand in hands {
                let dist = simd_distance(model.position(relativeTo: nil),
                                         hand.position(relativeTo: nil))
                if dist < cfg.collisionDistance {
                    // Ensure physical components exist.
                    model.ensurePhysicsSupport()

                    // Cancel any scripted move already in progress.
                    entity.components.remove(MoveToComponent.self)

                    // Apply an instantaneous impulse away from the hand.
                    let dir = normalize(model.position(relativeTo: nil) -
                        hand.position(relativeTo: nil))
                    model.applyLinearImpulse(dir * cfg.impulseStrength, relativeTo: nil)

                    // Add a flee state so other systems know the bee is panicking.
                    entity.components.set(FleeStateComponent(timeRemaining: cfg.recoverDuration))
                    break // one collision per frame is enough
                }
            }
        }
    }
}
