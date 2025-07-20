//
//  HandInputSystem.swift
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
    private var palmCenter: [UUID: SIMD3<Float>] = [:]

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

    func setPalmCenter(_ pos: SIMD3<Float>?, for id: UUID) {
        palmCenter[id] = pos
    }

    func palmCenter(for id: UUID) -> SIMD3<Float>? {
        palmCenter[id]
    }

    func palmCenter(for entity: Entity) -> SIMD3<Float>? {
        guard
            let comp = entity.components[HandComponent.self],
            let id = comp.handID
        else { return nil }
        return palmCenter[id]
    }
}

@MainActor
final class HandInputSystem: System {
    private let session = ARKitSession()
    private let provider = HandTrackingProvider()

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
            comp.isCurrentlyTracked = true
            comp.trackedPosition = anchor.originFromAnchorTransform.columns.3.xyz
            handEntity.components.set(comp)

            handEntity.transform.matrix = anchor.originFromAnchorTransform

            // Update cache
            let closed = isFistClosed(anchor)
            // let thumbsUp = isThumbsUp(anchor)
            let palmOpen = isPalmOpen(anchor)

            // print("is closed: \(closed)")
            // print("is thumbsUp: \(thumbsUp)")
            // print("is palmOpen: \(palmOpen)")
            HandPoseCache.shared.setFistClosed(closed, for: anchor.id)
            // HandPoseCache.shared.setThumbsUp(thumbsUp, for: anchor.id)
            HandPoseCache.shared.setPalmOpen(palmOpen, for: anchor.id)

            // Store palm center position if available
            if let skeleton = anchor.handSkeleton {
                let wrist = skeleton.joint(.wrist)
                let base = skeleton.joint(.middleFingerKnuckle)
                if wrist.isTracked, base.isTracked {
                    let wristPos = wrist.anchorFromJointTransform.columns.3.xyz
                    let basePos = base.anchorFromJointTransform.columns.3.xyz
                    let localPalm = (wristPos + basePos) * 0.5
                    let worldPalm = anchor.originFromAnchorTransform * SIMD4<Float>(localPalm, 1)
                    let palmPos = SIMD3<Float>(worldPalm.x, worldPalm.y, worldPalm.z)
                    HandPoseCache.shared.setPalmCenter(palmPos, for: anchor.id)
                } else {
                    HandPoseCache.shared.setPalmCenter(nil, for: anchor.id)
                }
            } else {
                HandPoseCache.shared.setPalmCenter(nil, for: anchor.id)
            }
        }

        // Release placeholders whose hand disappeared
        for e in entities {
            if let id = e.components[HandComponent.self]?.handID,
               !visible.contains(id)
            {
                var comp = e.components[HandComponent.self]!
                comp.handID = nil
                comp.isCurrentlyTracked = false
                comp.trackedPosition = nil
                e.components.set(comp)

                HandPoseCache.shared.setFistClosed(false, for: id)
                // HandPoseCache.shared.setThumbsUp(false, for: id)
                HandPoseCache.shared.setPalmOpen(false, for: id)
                HandPoseCache.shared.setPalmCenter(nil, for: id)
            }
        }
    }

    /// Heuristic: Detects a closed fist
    private func isFistClosed(_ anchor: HandAnchor) -> Bool {
        guard let skel = anchor.handSkeleton else { return false }

        func pos(_ n: HandSkeleton.JointName) -> SIMD3<Float>? {
            let j = skel.joint(n)
            return j.isTracked ? j.anchorFromJointTransform.columns.3.xyz : nil
        }

        let fingerJoints: [(base: HandSkeleton.JointName, mid: HandSkeleton.JointName, tip: HandSkeleton.JointName)] = [
            (.indexFingerKnuckle, .indexFingerIntermediateTip, .indexFingerTip),
            (.middleFingerKnuckle, .middleFingerIntermediateTip, .middleFingerTip),
            (.ringFingerKnuckle, .ringFingerIntermediateTip, .ringFingerTip),
            (.littleFingerKnuckle, .littleFingerIntermediateTip, .littleFingerTip)
        ]

        let fingerDistanceLimits: [HandSkeleton.JointName: Float] = [
            .indexFingerTip: 0.09, // 9 cm
            .middleFingerTip: 0.085,
            .ringFingerTip: 0.09,
            .littleFingerTip: 0.10
        ]

        let folded = fingerJoints.allSatisfy { _, _, tip in
            guard let t = pos(tip), let wrist = pos(.wrist) else { return false }
            let dist = simd_distance(t, wrist)
            let limit = fingerDistanceLimits[tip] ?? 0.07
            // print("Distance between \(tip): \(dist) (limit: \(limit)), is dist < limit ? \((dist < limit) ? "✅" : "❌") ")
            return dist < limit
        }

        return folded
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

    /// Heuristic: palm open, all fingers extended and apart, palm facing up (calibrated)
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

        // All fingers extended (distance tip-wrist)
        let fingerLimits: [HandSkeleton.JointName: Float] = [
            .thumbTip: 0.07,
            .indexFingerTip: 0.09,
            .middleFingerTip: 0.10,
            .ringFingerTip: 0.09,
            .littleFingerTip: 0.08
        ]
        let fingerTips: [(HandSkeleton.JointName, SIMD3<Float>)] = [
            (.thumbTip, thumbTip),
            (.indexFingerTip, indexTip),
            (.middleFingerTip, middleTip),
            (.ringFingerTip, ringTip),
            (.littleFingerTip, littleTip)
        ]
        let allExtended = fingerTips.allSatisfy { name, tip in
            let dist = simd_distance(tip, wrist)
            let limit = fingerLimits[name] ?? 0.09
            let result = dist > limit
            // print("Extended: \(name): \(dist) (limit: \(limit)), dist > limit ? \(result ? "✅" : "❌")")
            return result
        }

        // Fingers apart (distance between neighbors)
        let apartThreshold: Float = 0.01 // 1 cm
        let apartPairs = [
            (thumbTip, indexTip, ".thumbTip-.indexFingerTip"),
            (indexTip, middleTip, ".indexFingerTip-.middleFingerTip"),
            (middleTip, ringTip, ".middleFingerTip-.ringFingerTip"),
            (ringTip, littleTip, ".ringFingerTip-.littleFingerTip")
        ]
        let apartCount = apartPairs.reduce(into: 0) { acc, pair in
            let (a, b, label) = pair
            let dist = simd_distance(a, b)
            let result = dist > apartThreshold
            // print("Apart: \(label): \(dist) (limit: \(apartThreshold)), dist > limit ? \(result ? "✅" : "❌")")
            if result { acc += 1 }
        }
        let notTooClose = apartCount >= 3 // at least 3/4 pairs are well separated

        // Palm facing up (normal)
        let v1 = indexKnuckle - wrist
        let v2 = littleKnuckle - wrist
        let palmNormal = simd_normalize(simd_cross(v2, v1))
        let worldUp = SIMD3<Float>(0, 1, 0)
        let upDot = simd_dot(palmNormal, worldUp)
        let palmFacingUp = upDot > 0.6
        // print("Palm upDot (normal.y): \(upDot), > 0.6 ? \(palmFacingUp ? "✅" : "❌")")

        let isPalm = allExtended && notTooClose && palmFacingUp
        // print("isPalmOpen ? \(isPalm ? "✅" : "❌")")
        return isPalm
    }
}
