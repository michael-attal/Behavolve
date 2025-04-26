//
//  OscillationSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import RealityKit
import SwiftUI

// TODO: Couple Oscillation + Moving
@MainActor
final class OscillationSystem: System {
    private static let query =
        EntityQuery(where: .has(OscillationComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = context.deltaTime // seconds since last frame

        for entity in context.scene.performQuery(Self.query) {
            guard var osc = entity.components[OscillationComponent.self],
                  let model = entity.findModelEntity()
            else { continue }

            // Capture the starting position only once
            if osc.basePosition == nil {
                osc.basePosition = model.position(relativeTo: nil)
            }

            // Advance internal clock
            osc.elapsedTime += dt

            // Compute sinusoidal offset
            let angle = Float(osc.elapsedTime) * osc.frequency * 2 * .pi + osc.phase
            let offset = osc.axis * (osc.amplitude * sin(angle))

            if let base = osc.basePosition {
                var t = model.transform
                t.translation = base + offset
                model.transform = t
            }

            // Persist updated component
            entity.components.set(osc)
        }
    }
}
