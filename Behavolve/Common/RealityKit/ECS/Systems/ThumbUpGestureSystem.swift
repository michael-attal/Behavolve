//
//  ThumbUpGestureSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 01/07/2025.
//

import ARKit
import Foundation
import RealityKit
import simd

@MainActor
final class ThumbUpGestureSystem: @MainActor System {
    static var dependencies: [SystemDependency] { [.after(HandInputSystem.self)] }

    private static let query = EntityQuery(where: .has(ThumbUpGestureComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let provider = AppState.handTracking

        for hand in context.scene.performQuery(Self.query) {
            guard var comp = hand.components[ThumbUpGestureComponent.self] else { continue }

            // Is thumbs up currently held?
            let isThumbsUp = HandPoseCache.shared.isThumbsUp(for: hand)

            // Accumulate or reset hold time.
            comp.holdTime = isThumbsUp ? comp.holdTime + context.deltaTime : .zero

            if comp.holdTime >= comp.requiredDuration {
                // Fetch thumb tip position from latest ARKit data
                let thumbTipPos = Self.thumbTipPosition(for: hand, provider: provider)

                // Send notification with position
                let userInfo: [String: Any] = [
                    ThumbUpNotificationKeys.thumbTipPosition: thumbTipPos as Any
                ]
                NotificationCenter.default.post(
                    name: .thumbUpGestureDetected,
                    object: nil,
                    userInfo: userInfo
                )

                print("Thumb Up Gesture Detected! Notifying with thumb tip position: \(String(describing: thumbTipPos))")
                comp.holdTime = 0
            }
            hand.components.set(comp)
        }
    }

    /// Utility to fetch thumb tip world position from a hand entity, if tracked
    static func thumbTipPosition(for hand: Entity, provider: HandTrackingProvider) -> SIMD3<Float>? {
        guard
            let comp = hand.components[HandComponent.self],
            let handID = comp.handID,
            let anchor = provider.latestAnchors.0?.id == handID ? provider.latestAnchors.0 : provider.latestAnchors.1,
            let skeleton = anchor.handSkeleton
        else { return nil }

        let joint = skeleton.joint(.thumbTip)
        guard joint.isTracked else { return nil }
        // thumbTip in anchor-local, transform to world
        let localThumbTip = joint.anchorFromJointTransform.columns.3.xyz
        let worldThumbTip = (anchor.originFromAnchorTransform) * SIMD4<Float>(localThumbTip, 1)
        return SIMD3<Float>(worldThumbTip.x, worldThumbTip.y, worldThumbTip.z)
    }
}

extension Notification.Name {
    static let thumbUpGestureDetected = Notification.Name("ThumbUpGestureDetected")
}

enum ThumbUpNotificationKeys {
    static let thumbTipPosition = "thumbTipPosition"
}

extension Notification {
    var thumbUpThumbTipPosition: SIMD3<Float>? {
        userInfo?[ThumbUpNotificationKeys.thumbTipPosition] as? SIMD3<Float>
    }
}
