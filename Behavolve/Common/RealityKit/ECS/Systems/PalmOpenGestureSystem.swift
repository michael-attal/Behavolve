//
//  PalmOpenGestureSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 01/07/2025.
//

import ARKit
import Foundation
import RealityKit
import simd

@MainActor
final class PalmOpenGestureSystem: @MainActor System {
    static var dependencies: [SystemDependency] { [.after(HandInputSystem.self)] }

    private static let query = EntityQuery(where: .has(PalmOpenGestureComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        for hand in context.scene.performQuery(Self.query) {
            guard var comp = hand.components[PalmOpenGestureComponent.self] else { continue }

            let isPalmOpen = HandPoseCache.shared.isPalmOpen(for: hand)
            comp.holdTime = isPalmOpen ? comp.holdTime + context.deltaTime : .zero

            if isPalmOpen {
                let palmPos = HandPoseCache.shared.palmCenter(for: hand)
                let userInfo: [String: Any] = [
                    PalmOpenNotificationKeys.palmCenterPosition: palmPos as Any
                ]
                NotificationCenter.default.post(
                    name: .palmOpenGestureDetected,
                    object: nil,
                    userInfo: userInfo
                )
                print("🖐️ Palm Open detected! Notifying with palm center position: \(String(describing: palmPos))")
                comp.holdTime = 0
            }
            hand.components.set(comp)
        }
    }
}

extension Notification.Name {
    static let palmOpenGestureDetected = Notification.Name("PalmOpenGestureDetected")
}

enum PalmOpenNotificationKeys {
    static let palmCenterPosition = "palmCenterPosition"
}

extension Notification {
    var palmOpenPalmCenterPosition: SIMD3<Float>? {
        userInfo?[PalmOpenNotificationKeys.palmCenterPosition] as? SIMD3<Float>
    }
}
