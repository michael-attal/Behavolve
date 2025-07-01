//
//  OscillationSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import RealityKit
import SwiftUI

@MainActor
final class OscillationSystem: @MainActor System {
    private static let query = EntityQuery(where: .has(OscillationComponent.self))
    static var dependencies: [SystemDependency] { [.after(MovementSystem.self)] }

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = context.deltaTime

        for entity in context.scene.performQuery(Self.query) {
            guard var osc = entity.components[OscillationComponent.self],
                  let model = entity.findModelEntity()
            else { continue }

            osc.elapsedTime += dt
            // Compute sinusoidal offset
            let angle = Float(osc.elapsedTime) * osc.frequency * 2 * .pi + osc.phase
            let offsetWorld = osc.axis * (osc.amplitude * sin(angle))

            let worldScale = cumulativeScale(of: entity)
            let parentRot = entity.orientation(relativeTo: nil)
            let offsetLocal = simd_inverse(parentRot).act(offsetWorld) / worldScale

            var transform = model.transform
            transform.translation = offsetLocal
            model.transform = transform

            entity.components.set(osc)
        }
    }

    private func cumulativeScale(of entity: Entity) -> Float {
        var e: Entity? = entity
        var sx: Float = 1, sy: Float = 1, sz: Float = 1
        while let cur = e {
            let s = cur.transform.scale
            sx *= s.x; sy *= s.y; sz *= s.z
            e = cur.parent
        }
        return max(abs(sx), abs(sy), abs(sz))
    }
}
