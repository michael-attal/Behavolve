//
//  Entity+Extensions.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 30/01/2025.
//

import Combine
import Foundation
import RealityKit

extension Entity {
    func addSkybox(for named: String) async {
        do {
            let texture = try await TextureResource(named: named)
            var material = UnlitMaterial()
            material.color = .init(texture: .init(texture))
            self.components.set(ModelComponent(
                mesh: .generateSphere(radius: 1E3),
                materials: [material]
            ))
            self.scale *= .init(x: -1, y: 1, z: 1)
            self.transform.translation += SIMD3<Float>(0.0, 1.0, 0.0)
        } catch {
            assertionFailure("\(error)")
        }
    }

    static func rotateEntityAroundYAxis(entity: Entity, angle: Float) {
        var currentTransform = entity.transform

        // Create a quaternion representing a rotation around the Y-axis
        let rotation = simd_quatf(angle: angle, axis: [0, 1, 0])

        // Combine the rotation with the current transform
        currentTransform.rotation = rotation * currentTransform.rotation

        entity.transform = currentTransform
    }
}

extension Entity {
    /// Executes a closure for each of the entity's child and descendant
    /// entities, as well as for the entity itself.
    ///
    /// Set `stop` to true in the closure to abort further processing of the child entity subtree.
    func enumerateDescendants(_ body: (Entity, UnsafeMutablePointer<Bool>) -> Void) {
        var stop = false

        func enumerate(_ body: (Entity, UnsafeMutablePointer<Bool>) -> Void) {
            guard !stop else {
                return
            }

            body(self, &stop)

            for child in children {
                guard !stop else {
                    break
                }
                child.enumerateDescendants(body)
            }
        }

        enumerate(body)
    }
}

extension Entity {
    /// If true, the entity will cast a shadow
    func setGroundingShadow(castsShadow shouldCastsShadow: Bool) {
        self.enumerateDescendants { descendant, _ in
            descendant.trySetGroundingShadowComponent(castsShadow: shouldCastsShadow)
        }

        self.trySetGroundingShadowComponent(castsShadow: shouldCastsShadow)
    }

    private func trySetGroundingShadowComponent(castsShadow shouldCastsShadow: Bool) {
        self.components.set(GroundingShadowComponent(castsShadow: shouldCastsShadow))
    }
}

extension Entity {
    /// Returns the orientation of the entity specified in the app's coordinate system. On
    /// iOS and macOS, which don't have a device native coordinate system, scene
    /// space is often referred to as "world space".
    var sceneOrientation: simd_quatf {
        get { orientation(relativeTo: nil) }
        set { setOrientation(newValue, relativeTo: nil) }
    }

    /// Returns the position of the entity specified in the app's coordinate system. On
    /// iOS and macOS, which don't have a device native coordinate system, scene
    /// space is often referred to as "world space".
    var scenePosition: SIMD3<Float> {
        get { position(relativeTo: nil) }
        set { setPosition(newValue, relativeTo: nil) }
    }
}

extension Entity {
    func rotateEntity(angle: Float, axis: SIMD3<Float>) {
        var rotation = transform.rotation
        let angleRadians = angle * (Float.pi / 180.0) // Convert degree to radians
        rotation = simd_mul(rotation, simd_quatf(angle: angleRadians, axis: axis))
        transform.rotation = rotation
    }
}

extension Entity {
    /// Recursively searches the entity and its children for a `ModelEntity` which can have physics applied to it.
    /// - Returns: The first `ModelEntity` discovered from descedents of an `Entity` instance.
    func findModelEntity() -> ModelEntity? {
        if let modelEntity = self as? ModelEntity {
            return modelEntity
        }

        // Recursively search in the children
        for child in self.children {
            if let found = child.findModelEntity() {
                return found
            }
        }

        // Return nil if no ModelEntity with a collision component is found in the hierarchy
        print("Could not find collisionable entity for \(self)")
        return nil
    }

    /// Recursively searches the entity and its children for all entities with a given component type. **Don't use this in systems; instead, query the scene update context.** This is provided for convenience at the UI level.
    /// - Parameter componentType: A component type.
    /// - Returns: All entities which have the component.
    func findEntitiesWithComponent<T: Component>(_ componentType: T.Type) -> [Entity] {
        var entitiesWithComponent: [Entity] = []

        // Check if the current entity has the component and add it to the array
        if self.components[componentType] != nil {
            entitiesWithComponent.append(self)
        }

        // Recursively search in the child entities
        for child in self.children {
            entitiesWithComponent.append(contentsOf: child.findEntitiesWithComponent(componentType))
        }

        return entitiesWithComponent
    }
}

extension ModelEntity {
    /// Ensure the entity has the required physics and collision components
    /// to be driven by a `PhysicsMotionComponent`.
    @MainActor
    func ensurePhysicsSupport() {
        // Adding force requires a collision component
        if collision == nil {
            collision = CollisionComponent(
                shapes: [.generateBox(size: .init(repeating: 0.1))]
            )
        }

        // Adding force requires a physics body
        // https://developer.apple.com/documentation/realitykit/physicsbodycomponent
        if physicsBody == nil {
            var body = PhysicsBodyComponent()
            body.isAffectedByGravity = false
            body.massProperties.mass = 0.001
            physicsBody = body
        }
    }
}
