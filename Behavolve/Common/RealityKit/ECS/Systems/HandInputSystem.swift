//
//  HandPoseCache.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 29/04/2025.
//

import ARKit
import RealityKit
import simd

@MainActor
final class HandPoseCache: Sendable {
    static let shared = HandPoseCache()
    private var fistClosed: [UUID: Bool] = [:]

    func setFistClosed(_ v: Bool, for id: UUID) { fistClosed[id] = v }
    func isFistClosed(for id: UUID) -> Bool { fistClosed[id] ?? false }

    func isFistClosed(for entity: Entity) -> Bool {
        guard
            let comp = entity.components[HandComponent.self],
            let id = comp.handID
        else { return false }

        return isFistClosed(for: id)
    }
}

@MainActor
final class HandInputSystem: System {
    // ARKit
    private let session = ARKitSession()
    private let provider = HandTrackingProvider()

    // Query all entities that own a HandComponent
    private static let handsQuery = EntityQuery(where: .has(HandComponent.self))

    required init(scene: Scene) {
        Task.detached { [provider, session] in
            guard HandTrackingProvider.isSupported else { return }
            try? await session.run([provider])
        }
    }

    func update(context: SceneUpdateContext) {
        guard case .running = provider.state else { return }

        // Latest anchors (max two: left & right)
        let anchors = [provider.latestAnchors.0, provider.latestAnchors.1]
            .compactMap { $0 }

        // Hand placeholders already in the scene
        let entities = context.scene.performQuery(Self.handsQuery)

        var visible: Set<UUID> = []

        // ------------------------------------------------------------------ A —
        // Bind / update every visible hand
        // ----------------------------------------------------------------------
        for anchor in anchors {
            visible.insert(anchor.id)

            // Find entity already bound to this UUID or grab a free placeholder
            let entity = entities.first(where: {
                $0.components[HandComponent.self]?.handID == anchor.id
            }) ?? entities.first(where: {
                $0.components[HandComponent.self]?.handID == nil
            })

            guard let handEntity = entity else { continue }

            // 1. (bind) update component
            var comp = handEntity.components[HandComponent.self]!
            comp.handID = anchor.id
            handEntity.components.set(comp)

            // 2. (update) push transform
            handEntity.transform.matrix = anchor.originFromAnchorTransform

            // 3. (gesture) update cache
            let closed = isFistClosed(anchor)
            Task { await HandPoseCache.shared.setFistClosed(closed, for: anchor.id) }
        }

        // ------------------------------------------------------------------ B —
        // Release placeholders whose hand disappeared
        // ----------------------------------------------------------------------
        for e in entities {
            if let id = e.components[HandComponent.self]?.handID,
               !visible.contains(id)
            {
                var comp = e.components[HandComponent.self]!
                comp.handID = nil // back to “free” state
                e.components.set(comp)

                Task { await HandPoseCache.shared.setFistClosed(false, for: id) }
            }
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
