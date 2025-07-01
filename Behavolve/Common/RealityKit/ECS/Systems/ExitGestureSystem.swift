//
//  ExitGestureSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import Foundation
import RealityKit

@MainActor
final class ExitGestureSystem: @MainActor System {
    static var dependencies: [SystemDependency] { [.after(HandInputSystem.self)] }

    private static let query = EntityQuery(where: .has(ExitGestureComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        for hand in context.scene.performQuery(Self.query) {
            guard var comp = hand.components[ExitGestureComponent.self] else { continue }

            let closed = HandPoseCache.shared.isFistClosed(for: hand)

            // Accumulate or reset hold time.
            comp.holdTime = closed ? comp.holdTime + context.deltaTime : .zero

            if comp.holdTime >= comp.requiredDuration {
                print("Exit Gesture Detected! Sending notification now!")
                NotificationCenter.default.post(name: .exitGestureDetected, object: nil)
                comp.holdTime = 0 // prevent re-trigger spam
            }
            hand.components.set(comp)
        }
    }
}

// Custom notification used by ImmersiveView.
extension Notification.Name {
    static let exitGestureDetected = Notification.Name("ExitGestureDetected")
}

extension Notification.Name {
    static let exitWordDetected = Notification.Name("ExitWordDetected")
}
