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

    // Shared hold time for both hands
    private var holdTime: TimeInterval = 0

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let hands = context.scene.performQuery(Self.query)
        // We want both hand to detect the exit gesture
        guard hands.count(where: { _ in true }) == 2,
              hands.count(where: { HandPoseCache.shared.isFistClosed(for: $0) }) == 2
        else {
            holdTime = 0
            return
        }

        let requiredDuration = hands.compactMap { $0.components[ExitGestureComponent.self]?.requiredDuration }.min() ?? 1.0

        holdTime += context.deltaTime
        if holdTime >= requiredDuration {
            print("Exit Gesture Detected by both hands! Sending notification now!")
            NotificationCenter.default.post(name: .exitGestureDetected, object: nil)
            holdTime = 0 // Prevent re-trigger spam
        }

        for hand in hands {
            if var comp = hand.components[ExitGestureComponent.self] {
                comp.holdTime = holdTime
                hand.components.set(comp)
            }
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
