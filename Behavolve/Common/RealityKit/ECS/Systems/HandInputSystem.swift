//
//  HandPoseCache.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

// MARK: - Pose cache ----------------------------------------------------------

/// Thread-safe cache storing one frame of hand data (pose & fist state).
// @MainActor
// class HandPoseCache {
//     static let shared = HandPoseCache()
//
//     private var fistClosed: [UUID: Bool] = [:]
//
//     func setFistClosed(_ closed: Bool, for handID: UUID) {
//         fistClosed[handID] = closed
//     }
//
//     func isFistClosed(for entity: Entity) -> Bool {
//         guard let h = entity.components[HandComponent.self] else { return false }
//         return fistClosed[h.handID] ?? false
//     }
// }

// MARK: - HandInputSystem -----------------------------------------------------

//
//  HandInputSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29 / 04 / 2025.
//
//
//  HandInputSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import ARKit
import QuartzCore
import RealityKit
import simd

@MainActor
class HandPoseCache {
    static let shared = HandPoseCache()
    private var fistClosed: [UUID: Bool] = [:]

    func setFistClosed(_ v: Bool, for id: UUID) { fistClosed[id] = v }
    func isFistClosed(for entity: Entity) -> Bool {
        guard let c = entity.components[HandComponent.self] else { return false }
        return fistClosed[c.handID] ?? false
    }
}

@MainActor
final class HandInputSystem: System {
    private let session = ARKitSession()
    private let provider = HandTrackingProvider()
    private var hands: [UUID: AnchorEntity] = [:]

    required init(scene: Scene) {
        Task {
            guard HandTrackingProvider.isSupported else { return }
            try? await session.run([provider])
        }
    }

    func update(context: SceneUpdateContext) {
        guard case .running = provider.state else { return }

        // Poll the most recent anchors (left + right) – API stable depuis v1
        let (left, right) = provider.latestAnchors
        let anchors = [left, right].compactMap { $0 }

        var visible: Set<UUID> = []

        for anchor in anchors {
            visible.insert(anchor.id)

            // a) map anchor → entity
            let ent = hands[anchor.id] ?? {
                let a = AnchorEntity()
                a.components.set(HandComponent(handID: anchor.id))
                a.components.set(ExitGestureComponent())
                // context.scene.anchors.append(a) // FIXME
                hands[anchor.id] = a
                return a
            }()

            // b) update transform
            ent.transform.translation = anchor.originFromAnchorTransform.columns.3.xyz

            // c) detect fist
            let fistClosed = isFistClosed(anchor)
            Task { await HandPoseCache.shared.setFistClosed(fistClosed, for: anchor.id) }
        }

        // d) remove lost hands
        for (id, e) in hands where !visible.contains(id) {
            e.removeFromParent()
            hands.removeValue(forKey: id)
            Task { await HandPoseCache.shared.setFistClosed(false, for: id) }
        }
    }

    /// Heuristic thumb-pinch + fingers fold
    private func isFistClosed(_ anchor: HandAnchor) -> Bool {
        guard let skel = anchor.handSkeleton else { return false }

        func pos(_ n: HandSkeleton.JointName) -> SIMD3<Float>? {
            let j = skel.joint(n)
            return j.isTracked ? j.anchorFromJointTransform.columns.3.xyz : nil
        }

        guard
            let thumb = pos(.thumbTip),
            let index = pos(.indexFingerTip),
            let wrist = pos(.wrist)
        else { return false }

        let pinch = simd_distance(thumb, index) < 0.03

        let folded = [
            HandSkeleton.JointName.indexFingerTip,
            .middleFingerTip,
            .ringFingerTip,
            .littleFingerTip
        ].allSatisfy { n in
            if let p = pos(n) { return simd_distance(p, wrist) < 0.04 }
            return false
        }

        return pinch && folded
    }
}
