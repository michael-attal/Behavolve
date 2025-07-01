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
        let provider = AppState.handTracking

        for hand in context.scene.performQuery(Self.query) {
            guard var comp = hand.components[PalmOpenGestureComponent.self] else { continue }

            let isPalmOpen = HandPoseCache.shared.isPalmOpen(for: hand)
            comp.holdTime = isPalmOpen ? comp.holdTime + context.deltaTime : .zero

            if comp.holdTime >= comp.requiredDuration {
                let palmPos = Self.palmCenterPosition(for: hand, provider: provider)
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

    static func palmCenterPosition(for hand: Entity, provider: HandTrackingProvider) -> SIMD3<Float>? {
        guard
            let comp = hand.components[HandComponent.self],
            let handID = comp.handID,
            let anchor = provider.latestAnchors.0?.id == handID ? provider.latestAnchors.0 : provider.latestAnchors.1,
            let skeleton = anchor.handSkeleton
        else { return nil }

        let wrist = skeleton.joint(.wrist)
        let base = skeleton.joint(.middleFingerKnuckle)
        guard wrist.isTracked, base.isTracked else { return nil }

        let wristPos = wrist.anchorFromJointTransform.columns.3.xyz
        let basePos = base.anchorFromJointTransform.columns.3.xyz

        let localPalm = (wristPos + basePos) * 0.5
        let worldPalm = anchor.originFromAnchorTransform * SIMD4<Float>(localPalm, 1)
        return SIMD3<Float>(worldPalm.x, worldPalm.y, worldPalm.z)
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
