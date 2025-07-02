//
//  HandCollisionSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import ARKit
import RealityKit

@MainActor
final class HandCollisionSystem: @MainActor System {
    static var dependencies: [SystemDependency] { [.after(HandProximitySystem.self)] }

    private static let handQuery = EntityQuery(where: .has(HandComponent.self))
    private static let entityWithHandCollisionQuery = EntityQuery(where: .has(HandCollisionComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let hands = context.scene.performQuery(Self.handQuery)

        for entity in context.scene.performQuery(Self.entityWithHandCollisionQuery) {
            guard let model = entity.findModelEntity(),
                  let cfg = entity.components[HandCollisionComponent.self] else { continue }

            if let fleeState = entity.components[FleeStateComponent.self] {
                let newTimeRemaining = fleeState.timeRemaining - context.deltaTime
                if newTimeRemaining <= 0 {
                    entity.components.remove(FleeStateComponent.self)
                } else {
                    entity.components.set(FleeStateComponent(timeRemaining: newTimeRemaining))
                }
                continue
            }

            for hand in hands {
                let dist = simd_distance(model.position(relativeTo: nil),
                                         hand.position(relativeTo: nil))
                // print("Collision distance between model and a hand: \(dist)")
                if dist < cfg.collisionDistance {
                    // Ensure physical components exist.
                    model.ensurePhysicsSupport()

                    // Cancel any scripted move already in progress.
                    entity.components.remove(MoveToComponent.self)

                    // Apply an instantaneous impulse away from the hand.
                    let dir = normalize(model.position(relativeTo: nil) -
                        hand.position(relativeTo: nil))
                    // model.applyLinearImpulse(dir * cfg.impulseStrength, relativeTo: nil)
                    entity.components.set(
                        MoveToComponent(destination: dir,
                                        speed: 1 * cfg.impulseStrength,
                                        epsilon: 0.02)
                    )
                    entity.components.set(LookAtTargetComponent(target: .world(dir)))

                    // Add a flee state so other systems know the bee is panicking.
                    entity.components.set(FleeStateComponent(timeRemaining: cfg.recoverDuration))
                    break // one collision per frame is enough
                }
            }
        }
    }
}
