//
//  TargetReachedSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 25/06/2025.
//

import Foundation
import RealityKit

@MainActor
final class TargetReachedSystem: @MainActor System {
    static var dependencies: [SystemDependency] { [.after(HandInputSystem.self)] }

    private static let query = EntityQuery(where: .has(TargetReachedComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard var targetComponent = entity.components[TargetReachedComponent.self] else { continue }

            let distance = distance(targetComponent.currentPosition, targetComponent.targetPosition)

            if distance <= targetComponent.precision {
                entity.components.remove(TargetReachedComponent.self)

                // Send notification with relevant data
                let userInfo: [String: Any] = [
                    TargetReachedNotificationKeys.entityName: entity.name,
                    TargetReachedNotificationKeys.targetPosition: targetComponent.targetPosition
                ]
                NotificationCenter.default.post(name: .targetReached, object: nil, userInfo: userInfo)

            } else {
                // Update current position
                targetComponent.currentPosition = entity.position(relativeTo: nil)
                entity.components[TargetReachedComponent.self] = targetComponent
            }
        }
    }
}

// Notification name used when a target is reached
extension Notification.Name {
    static let targetReached = Notification.Name("TargetReached")
}

// Keys for userInfo dictionary in targetReached notification
enum TargetReachedNotificationKeys {
    static let entityName = "entityName"
    static let targetPosition = "targetPosition"
}

// Convenience accessors for notification payload
extension Notification {
    var targetReachedEntityName: String? {
        userInfo?[TargetReachedNotificationKeys.entityName] as? String
    }

    var targetReachedTargetPosition: SIMD3<Float>? {
        userInfo?[TargetReachedNotificationKeys.targetPosition] as? SIMD3<Float>
    }
}
