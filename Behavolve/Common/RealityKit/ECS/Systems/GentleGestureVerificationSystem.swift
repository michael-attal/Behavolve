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
    
    required init(scene: RealityKit.Scene) {}
    
    func update(context: SceneUpdateContext) {
        for hand in context.scene.performQuery(Self.query) {
            guard var comp = hand.components[GentleGestureComponent.self] else { continue }
            
            // Compute instantaneous speed.
            let current = hand.position(relativeTo: nil)
            let delta = current - comp.lastPosition
            let dt = Float(max(context.deltaTime, 0.0001))
            let speed = length(delta) / dt
            
            // Low-pass filter (EMA).
            comp.smoothedSpeed = ema(prev: comp.smoothedSpeed, new: speed, alpha: comp.smoothing)
            
            // Check against threshold.
            if comp.smoothedSpeed > comp.maxSpeed {
                // Broadcast once per frame
                NotificationCenter.default.post(
                    name: .abruptGestureDetected,
                    object: hand
                )
                
                comp.smoothedSpeed = 0
            }
            
            comp.lastPosition = current
            hand.components.set(comp)
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
