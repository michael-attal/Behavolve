//
//  TargetReachedSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 25/06/2025.
//

import Foundation
import RealityKit

// TODO: TargetReachedSystem
@MainActor
final class TargetReachedSystem: @MainActor System {
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
// TODO: Add datas (entity name and target name...)
extension Notification.Name {
    static let targetReached = Notification.Name("TargetReached")
}
