//
//  HandPoseCache.swift
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

        // Poll the most recent anchors (left + right)
        let (left, right) = provider.latestAnchors
        let anchors = [left, right].compactMap { $0 }

        var visible: Set<UUID> = []

        for anchor in anchors {
            visible.insert(anchor.id)

            // Create or reuse an AnchorEntity
            let anchorEntity = hands[anchor.id] ?? {
                let newAnchor = AnchorEntity(world: anchor.originFromAnchorTransform)
                newAnchor.components.set(HandComponent(handID: anchor.id))
                newAnchor.components.set(ExitGestureComponent())
                // context.scene.addAnchor(newAnchor) // FIXME
                hands[anchor.id] = newAnchor
                return newAnchor
            }()

            // Update transform
            anchorEntity.transform.matrix = anchor.originFromAnchorTransform

            // Detect fist
            let fistClosed = isFistClosed(anchor)
            Task { await HandPoseCache.shared.setFistClosed(fistClosed, for: anchor.id) }
        }

        // Remove lost hands
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
            let indexIntermediate = pos(.indexFingerIntermediateTip),
            let indexIntermediateBase = pos(.indexFingerIntermediateBase),
            let indexFingerKnuckle = pos(.indexFingerKnuckle),
            let wrist = pos(.wrist)
        else { return false }

        // let pinch = simd_distance(thumb, index) < 0.03
        let pinch = (simd_distance(thumb, indexIntermediate) < 0.03) || (simd_distance(thumb, indexIntermediateBase) < 0.03) || (simd_distance(thumb, indexFingerKnuckle) < 0.03)

        let foldedFingers: [HandSkeleton.JointName] = [
            .indexFingerTip,
            .middleFingerTip,
            .ringFingerTip,
            .littleFingerTip
        ]

        let folded = foldedFingers.allSatisfy { n in
            if let p = pos(n) { return simd_distance(p, wrist) < 0.10 }
            return false
        }

        return pinch && folded
    }
}
