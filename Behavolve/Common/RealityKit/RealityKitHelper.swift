//
//  RealityKitHelper.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 27/03/2025.
//

import RealityKit

class RealityKitHelper {
    @available(*, unavailable) private init() {}

    static func snapParentToModel(_ entity: Entity, to model: Entity) {
        entity.transform.translation = model.position(relativeTo: nil)
        entity.transform.rotation = model.orientation(relativeTo: nil)
        let scale = model.transform.scale
        model.transform = Transform(scale: scale,
                                    rotation: .init(),
                                    translation: .zero)
    }

    static func snapParentToPositionWithPosition(_ entity: Entity, to model: Entity, with position: SIMD3<Float>) {
        entity.transform.translation = position
        entity.transform.rotation = model.orientation(relativeTo: nil)

        let scale = model.transform.scale
        model.transform = Transform(scale: scale, rotation: .init(), translation: .zero)
    }

    static func findFirstCollisionComponent(in entity: Entity) -> CollisionComponent? {
        if let collision = entity.components[CollisionComponent.self] {
            return collision
        }
        for child in entity.children {
            if let collision = findFirstCollisionComponent(in: child) {
                return collision
            }
        }
        return nil
    }

    /// Recursively search for the first entity that contains a CollisionComponent.
    static func findFirstEntityWithCollisionComponent(in entity: Entity) -> Entity? {
        if entity.components.has(CollisionComponent.self) {
            return entity
        }
        for child in entity.children {
            if let found = findFirstEntityWithCollisionComponent(in: child) {
                return found
            }
        }
        return nil
    }
    
    static func getModelHeight(modelEntity: ModelEntity) -> Float {
        let bounds = modelEntity.visualBounds(relativeTo: nil)
        let height = bounds.extents.y
        return height
    }
}
