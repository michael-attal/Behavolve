//
//  GentleGestureVerificationSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 26/06/2025.
//

import Foundation
import RealityKit

@MainActor
final class GentleGestureSystem: @MainActor System {
    /// Runs right after hand positions have been updated.
    static var dependencies: [SystemDependency] { [.after(HandInputSystem.self)] }

    private static let query = EntityQuery(where:
        .has(HandComponent.self) && .has(GentleGestureComponent.self)
    )
    private let graceDuration: Float = 0.3
    private let artefactSpeed: Float = 10.0
    private let consecutiveNeeded: Int = 2 // nb frames for throw notification

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(max(context.deltaTime, 0.0001))

        for handEntity in context.scene.performQuery(Self.query) {
            guard var gentleComponent = handEntity.components[GentleGestureComponent.self],
                  let handComponent = handEntity.components[HandComponent.self],
                  handComponent.isCurrentlyTracked,
                  let current = handComponent.trackedPosition
            else {
                // Tracking lost, reset total
                if var gg = handEntity.components[GentleGestureComponent.self] {
                    gg.lastPosition = nil
                    gg.smoothedSpeed = 0
                    gg.graceRemaining = 0
                    gg.overFrames = 0
                    handEntity.components.set(gg)
                }
                continue
            }

            // following frame after loss: Init
            guard let last = gentleComponent.lastPosition else {
                gentleComponent.lastPosition = current
                gentleComponent.graceRemaining = graceDuration
                gentleComponent.smoothedSpeed = 0
                gentleComponent.overFrames = 0
                handEntity.components.set(gentleComponent)
                continue
            }

            // Delta brut (before filter)
            let delta = current - last
            let instSpeed = length(delta) / dt

            // Is artefact tracking ?
            if instSpeed > artefactSpeed {
                gentleComponent.graceRemaining = graceDuration
                gentleComponent.lastPosition = current
                gentleComponent.smoothedSpeed = 0
                gentleComponent.overFrames = 0
                handEntity.components.set(gentleComponent)
                continue
            }

            if gentleComponent.graceRemaining > 0 {
                gentleComponent.graceRemaining -= dt
                gentleComponent.lastPosition = current
                handEntity.components.set(gentleComponent)
                continue
            }

            // Low-pass filter (EMA).
            gentleComponent.smoothedSpeed = ema(prev: gentleComponent.smoothedSpeed,
                                                new: instSpeed,
                                                alpha: gentleComponent.smoothing)

            // Check against threshold.
            if gentleComponent.smoothedSpeed > gentleComponent.maxSpeed {
                gentleComponent.overFrames += 1
                if gentleComponent.overFrames >= consecutiveNeeded {
                    // Broadcast once per frame
                    NotificationCenter.default.post(
                        name: .abruptGestureDetected,
                        object: handEntity
                    )
                    gentleComponent.overFrames = 0
                    gentleComponent.smoothedSpeed = 0
                }
            } else {
                gentleComponent.overFrames = 0
            }

            gentleComponent.lastPosition = current
            handEntity.components.set(gentleComponent)
        }
    }
}

extension Notification.Name {
    static let abruptGestureDetected = Notification.Name("AbruptGestureDetected")
}

/// Fast exponential moving average for velocity smoothing.
/// - Parameters:
///   - prev: Previous smoothed value
///   - new: New instant value
///   - alpha: Smoothing factor [0‒1]
@inline(__always)
func ema(prev: Float, new: Float, alpha: Float) -> Float {
    alpha * prev + (1 - alpha) * new
}
