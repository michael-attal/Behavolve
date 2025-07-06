
//
//  UserProximitySystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import Foundation
import RealityKit

@MainActor
final class EntityProximitySystem: System {
    private static let entityWithProximityQuery = EntityQuery(where: .has(EntityProximityComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        // Headset position maintained by LookAtTargetSystem.
        let userPos = LookAtTargetSystem.shared.devicePoseSafe.value.translation

        for entity in context.scene.performQuery(Self.entityWithProximityQuery) {
            guard let model = entity.findModelEntity(),
                  var comp = entity.components[EntityProximityComponent.self] else { continue }

            let modelPos = model.position(relativeTo: nil)
            let dist = simd_distance(modelPos, userPos)
            comp.distanceToUser = dist

            // print(dist)
            if dist > comp.targetDistanceToUser {
                let entityInfo: [String: Any] = [
                    EntityDistanceToUserReachedNotificationKeys.entityPosition: modelPos as Any,
                    EntityDistanceToUserReachedNotificationKeys.entityName: entity.name as Any,
                    EntityDistanceToUserReachedNotificationKeys.targetDistanceToUser: comp.targetDistanceToUser as Any
                ]
                NotificationCenter.default.post(
                    name: .entityTargetDistanceToUserReached,
                    object: nil,
                    userInfo: entityInfo
                )
                entity.components.remove(EntityProximityComponent.self)
                print(entityInfo)
            } else {
                entity.components.set(EntityProximityComponent(distanceToUser: comp.distanceToUser, targetDistanceToUser: comp.targetDistanceToUser))
            }
        }
    }
}

extension Notification.Name {
    static let entityTargetDistanceToUserReached = Notification.Name("EntityTargetDistanceToUserReached")
}

enum EntityDistanceToUserReachedNotificationKeys {
    static let entityPosition = "entityPosition"
    static let entityName = "entityName"
    static let targetDistanceToUser = "targetDistanceToUser"
}

extension Notification {
    var entityPosition: SIMD3<Float>? {
        userInfo?[EntityDistanceToUserReachedNotificationKeys.entityPosition] as? SIMD3<Float>
    }

    var entityName: String? {
        userInfo?[EntityDistanceToUserReachedNotificationKeys.entityName] as? String
    }

    var targetDistanceToUser: Float? {
        userInfo?[EntityDistanceToUserReachedNotificationKeys.targetDistanceToUser] as? Float
    }
}
