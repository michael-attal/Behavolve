//
//  CalmMotionSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 01/07/2025.
//

import ARKit
import Foundation
import QuartzCore
import RealityKit
import simd

@MainActor
final class CalmMotionSystem: @MainActor System {
    static var dependencies: [SystemDependency] { [] } // runs ASAP

    private static let query = EntityQuery(where: .has(CalmMotionComponent.self))

    // Use the shared, global WorldTrackingProvider instance from AppState
    private let worldTrackingProvider = AppState.worldTracking
    private let session = AppState.arkitSession

    // Store previous device position & time to compute velocity
    private var lastDevicePosition: SIMD3<Float>?
    private var lastTimestamp: TimeInterval?

    required init(scene: Scene) {
        Task.detached { [session, worldTrackingProvider] in
            guard WorldTrackingProvider.isSupported else { return }
            try? await session.run([worldTrackingProvider])
        }
    }

    func update(context: SceneUpdateContext) {
        // Query device anchor (headset pose)
        guard case .running = worldTrackingProvider.state,
              let devAnchor = worldTrackingProvider
              .queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        else { return }

        // Extract current headset position
        let currentPosition = SIMD3<Float>(
            devAnchor.originFromAnchorTransform.columns.3.x,
            devAnchor.originFromAnchorTransform.columns.3.y,
            devAnchor.originFromAnchorTransform.columns.3.z
        )
        let now = CACurrentMediaTime()

        // Compute velocity based on last position and timestamp
        var speed: Float = 0
        if let lastPos = lastDevicePosition, let lastTime = lastTimestamp {
            let dt = Float(max(now - lastTime, 0.0001))
            speed = simd_distance(currentPosition, lastPos) / dt
        }

        // Update history for next frame
        lastDevicePosition = currentPosition
        lastTimestamp = now

        // Iterate over all entities with CalmMotionComponent
        for e in context.scene.performQuery(Self.query) {
            guard var comp = e.components[CalmMotionComponent.self] else { continue }

            // Low-pass filter (EMA)
            comp.smoothedSpeed = ema(prev: comp.smoothedSpeed, new: speed, alpha: comp.smoothing)

            // Check if movement is too abrupt
            if comp.smoothedSpeed > comp.maxHeadSpeed {
                NotificationCenter.default.post(
                    name: .abruptHeadMotionDetected,
                    object: nil
                )
                comp.smoothedSpeed = 0 // Prevent notification spam
            }

            e.components.set(comp)
        }
    }
}

extension Notification.Name {
    static let abruptHeadMotionDetected = Notification.Name("AbruptHeadMotionDetected")
}
