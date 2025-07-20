//
//  FleeStateSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 20/07/2025.
//

import RealityKit

/// System responsible for decrementing FleeStateComponent timers and removing them when expired.
@MainActor
final class FleeStateSystem: @MainActor System {
    private static let fleeQuery = EntityQuery(where: .has(FleeStateComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.fleeQuery) {
            guard var flee = entity.components[FleeStateComponent.self] else { continue }
            flee.timeRemaining -= context.deltaTime
            if flee.timeRemaining <= 0 {
                // Timer expired: remove FleeStateComponent
                entity.components.remove(FleeStateComponent.self)
            } else {
                // Update the component with decremented time
                entity.components.set(flee)
            }
        }
    }
}
