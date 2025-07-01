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
    private var thumbsUp: [UUID: Bool] = [:]
    private var palmOpen: [UUID: Bool] = [:]

    // MARK: FIST CLOSED

    func setFistClosed(_ v: Bool, for id: UUID) { fistClosed[id] = v }
    func isFistClosed(for id: UUID) -> Bool { fistClosed[id] ?? false }
    func isFistClosed(for entity: Entity) -> Bool {
        guard
            let comp = entity.components[HandComponent.self],
            let id = comp.handID
        else { return false }

        return isFistClosed(for: id)
    }

    // MARK: THUMBS UP

    func setThumbsUp(_ v: Bool, for id: UUID) { thumbsUp[id] = v }
    func isThumbsUp(for id: UUID) -> Bool { thumbsUp[id] ?? false }
    func isThumbsUp(for entity: Entity) -> Bool {
        guard
            let comp = entity.components[HandComponent.self],
            let id = comp.handID
        else { return false }
        return isThumbsUp(for: id)
    }

    // MARK: PALM OPEN

    func setPalmOpen(_ v: Bool, for id: UUID) { palmOpen[id] = v }
    func isPalmOpen(for id: UUID) -> Bool { palmOpen[id] ?? false }
    func isPalmOpen(for entity: Entity) -> Bool {
        guard
            let comp = entity.components[HandComponent.self],
            let id = comp.handID
        else { return false }
        return isPalmOpen(for: id)
    }
}

@MainActor
final class HandInputSystem: System {
    private let session = AppState.arkitSession
    private let provider = AppState.handTracking

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

        // Bind / update every visible hand
        for anchor in anchors {
            visible.insert(anchor.id)

            // Find entity already bound to this UUID or grab a free placeholder
            let entity = entities.first(where: {
                $0.components[HandComponent.self]?.handID == anchor.id
            }) ?? entities.first(where: {
                $0.components[HandComponent.self]?.handID == nil
            })

            guard let handEntity = entity else { continue }

            var comp = handEntity.components[HandComponent.self]!
            comp.handID = anchor.id
            handEntity.components.set(comp)

            handEntity.transform.matrix = anchor.originFromAnchorTransform

            // Update cache
            let closed = isFistClosed(anchor)
            let thumbsUp = isThumbsUp(anchor)
            let palmOpen = isPalmOpen(anchor)
            Task {
                await HandPoseCache.shared.setFistClosed(closed, for: anchor.id)
                await HandPoseCache.shared.setThumbsUp(thumbsUp, for: anchor.id)
                await HandPoseCache.shared.setPalmOpen(palmOpen, for: anchor.id)
            }
        }

        // Release placeholders whose hand disappeared
        for e in entities {
            if let id = e.components[HandComponent.self]?.handID,
               !visible.contains(id)
            {
                var comp = e.components[HandComponent.self]!
                comp.handID = nil // back to “free” state
                e.components.set(comp)

                Task {
                    await HandPoseCache.shared.setFistClosed(false, for: id)
                    await HandPoseCache.shared.setThumbsUp(false, for: id)
                }
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

    /// Heuristic thumbs up: thumb extended, all other fingers folded
    private func isThumbsUp(_ anchor: HandAnchor) -> Bool {
        guard let skel = anchor.handSkeleton else { return false }

        func pos(_ n: HandSkeleton.JointName) -> SIMD3<Float>? {
            let j = skel.joint(n)
            return j.isTracked ? j.anchorFromJointTransform.columns.3.xyz : nil
        }

        guard
            let wrist = pos(.wrist),
            let thumbTip = pos(.thumbTip),
            let thumbIP = pos(.thumbIntermediateTip),
            let thumbBase = pos(.thumbKnuckle),
            let indexTip = pos(.indexFingerTip),
            let middleTip = pos(.middleFingerTip),
            let ringTip = pos(.ringFingerTip),
            let littleTip = pos(.littleFingerTip)
        else { return false }

        // Check all other fingers are folded (tips close to wrist)
        let fingerTips = [indexTip, middleTip, ringTip, littleTip]
        let folded = fingerTips.allSatisfy { simd_distance($0, wrist) < 0.08 }

        // Check thumb is far from wrist, i.e. extended outward
        let thumbExtended = simd_distance(thumbTip, wrist) > 0.10

        // Check thumb is “vertical” (upward in hand local space)
        let thumbVec = thumbTip - thumbBase
        let wristToThumbBase = thumbBase - wrist
        // If the angle between thumb vector and wrist-to-thumb-base is small, thumb is “out” (not bent towards palm)
        let cosAngle = simd_dot(simd_normalize(thumbVec), simd_normalize(wristToThumbBase))
        // Acceptable if angle < 45° (cos > ~0.7)
        let goodAngle = cosAngle > 0.7

        // Check thumb is not bent (distance tip/intermediate >= 2 cm)
        let notBent = simd_distance(thumbTip, thumbIP) > 0.02

        // Final decision
        return folded && thumbExtended && goodAngle && notBent
    }
}

/// Heuristic: palm open, all fingers extended and apart, palm facing up
private func isPalmOpen(_ anchor: HandAnchor) -> Bool {
    guard let skel = anchor.handSkeleton else { return false }

    func pos(_ n: HandSkeleton.JointName) -> SIMD3<Float>? {
        let j = skel.joint(n)
        return j.isTracked ? j.anchorFromJointTransform.columns.3.xyz : nil
    }

    guard
        let wrist = pos(.wrist),
        let thumbTip = pos(.thumbTip),
        let indexTip = pos(.indexFingerTip),
        let middleTip = pos(.middleFingerTip),
        let ringTip = pos(.ringFingerTip),
        let littleTip = pos(.littleFingerTip),
        let indexKnuckle = pos(.indexFingerKnuckle),
        let littleKnuckle = pos(.littleFingerKnuckle)
    else { return false }

    // All fingers extended (> 10 cm from wrist)
    let fingers = [thumbTip, indexTip, middleTip, ringTip, littleTip]
    let allExtended = fingers.allSatisfy { simd_distance($0, wrist) > 0.10 }

    // Fingers apart (> 3 cm between neighbors)
    let pairs = [
        (thumbTip, indexTip),
        (indexTip, middleTip),
        (middleTip, ringTip),
        (ringTip, littleTip)
    ]
    let notTooClose = pairs.allSatisfy { simd_distance($0.0, $0.1) > 0.03 }

    // Palm normal: wrist -> indexKnuckle and wrist -> littleKnuckle
    let v1 = indexKnuckle - wrist
    let v2 = littleKnuckle - wrist
    let palmNormal = simd_normalize(simd_cross(v1, v2))

    let worldUp = SIMD3<Float>(0, 1, 0)
    let upDot = simd_dot(palmNormal, worldUp)
    let palmFacingUp = upDot > 0.6 // angle < 53°

    return allExtended && notTooClose && palmFacingUp
}
