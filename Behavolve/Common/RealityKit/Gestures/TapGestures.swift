//
//  TapModifier.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 30/01/2025.
//

import RealityKit
import SwiftUI

public extension View {
    func tapGesture(
        isTapReleased: Binding<Bool> = .constant(false),
        onTapRelease: @escaping (_: TapGesture.Value) -> Void = { _ in },
        listenTapGesture: Bool = true
    ) -> some View {
        modifier(
            TapModifier(
                isTapReleased: isTapReleased,
                completion: onTapRelease,
                listenTapGesture: listenTapGesture
            )
        )
    }

    func tapGestureToEntity(
        _ target: Entity,
        isTapReleased: Binding<Bool> = .constant(false),
        onTapRelease: @escaping (_: EntityTargetValue<TapGesture.Value>) -> Void = { _ in },
        listenTapGesture: Bool = true
    ) -> some View {
        modifier(
            TapModifierToEntity(
                target,
                isTapReleased: isTapReleased,
                completion: onTapRelease,
                listenTapGesture: listenTapGesture
            )
        )
    }

    func spatialTapGesture(
        isSpatialTapReleased: Binding<Bool> = .constant(false),
        onSpatialTapPressing: @escaping (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void = { _ in },
        onSpatialTapRelease: @escaping (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void = { _ in },
        listenSpatialTapGesture: Bool = true
    ) -> some View {
        modifier(
            SpatialTapModifier(
                isSpatialTapReleased: isSpatialTapReleased,
                preCompletion: onSpatialTapPressing,
                completion: onSpatialTapRelease,
                listenSpatialTapGesture: listenSpatialTapGesture
            )
        )
    }

    /// Enables people to tap an Entity
    func spatialTapGestureToEntity(
        _ target: Entity,
        isSpatialTapReleased: Binding<Bool> = .constant(false),
        onSpatialTapPressing: @escaping (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void = { _ in },
        onSpatialTapRelease: @escaping (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void = { _ in },
        listenSpatialTapGesture: Bool = true
    ) -> some View {
        modifier(
            SpatialTapModifierToEntity(
                target,
                isSpatialTapReleased: isSpatialTapReleased,
                preCompletion: onSpatialTapPressing,
                completion: onSpatialTapRelease,
                listenSpatialTapGesture: listenSpatialTapGesture
            )
        )
    }
}

/// A modifier that add tap gesture to a View.
private struct TapModifier: ViewModifier {
    @Binding var isTapReleased: Bool
    let completion: (_: TapGesture.Value) -> Void
    let isTapGestureActivated: Bool

    init(isTapReleased: Binding<Bool> = .constant(false), completion: @escaping (_: TapGesture.Value) -> Void, listenTapGesture isTapGestureActivated: Bool = true) {
        self._isTapReleased = isTapReleased
        self.completion = completion
        self.isTapGestureActivated = isTapGestureActivated
    }

    func body(content: Content) -> some View {
        content.gesture(
            TapGesture().onEnded { tapGestureValue in
                if isTapGestureActivated {
                    completion(tapGestureValue)
                    isTapReleased = true
                }
            }
        )
    }
}

/// A modifier that add tap gesture to an Entity.
private struct TapModifierToEntity: ViewModifier {
    let target: Entity
    @Binding var isTapReleased: Bool
    let completion: (_: EntityTargetValue<TapGesture.Value>) -> Void
    let isTapGestureActivated: Bool

    init(_ target: Entity, isTapReleased: Binding<Bool> = .constant(false), completion: @escaping (_: EntityTargetValue<TapGesture.Value>) -> Void, listenTapGesture isTapGestureActivated: Bool = true) {
        self.target = target
        self._isTapReleased = isTapReleased
        self.completion = completion
        self.isTapGestureActivated = isTapGestureActivated
    }

    func body(content: Content) -> some View {
        content.gesture(
            TapGesture()
                .targetedToEntity(target)
                .onEnded { tapGestureValue in
                    var entity: Entity? = tapGestureValue.entity

                    if tapGestureValue.entity != target {
                        entity = HelperGestures.findTarget(target, from: tapGestureValue.entity)
                    }

                    if let entity = entity, isTapGestureActivated {
                        completion(tapGestureValue)
                        isTapReleased = true
                    }
                }
        )
    }
}

private struct SpatialTapModifier: ViewModifier {
    @Binding var isSpatialTapReleased: Bool
    let preCompletion: (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void
    let completion: (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void
    let isSpatialTapGestureActivated: Bool

    init(isSpatialTapReleased: Binding<Bool> = .constant(false), preCompletion: @escaping (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void, completion: @escaping (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void, listenSpatialTapGesture isSpatialTapGestureActivated: Bool = true) {
        self._isSpatialTapReleased = isSpatialTapReleased
        self.preCompletion = preCompletion
        self.completion = completion
        self.isSpatialTapGestureActivated = isSpatialTapGestureActivated
    }

    func body(content: Content) -> some View {
        content.gesture(
            SpatialTapGesture().targetedToAnyEntity()
                .onChanged { spatialTapGestureValue in
                    if isSpatialTapGestureActivated {
                        preCompletion(spatialTapGestureValue)
                        isSpatialTapReleased = false
                    }
                }.onEnded { spatialTapGestureValue in
                    if isSpatialTapGestureActivated {
                        completion(spatialTapGestureValue)
                        isSpatialTapReleased = true
                    }
                }
        )
    }
}

private struct SpatialTapModifierToEntity: ViewModifier {
    let target: Entity
    @Binding var isSpatialTapReleased: Bool
    let preCompletion: (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void
    let completion: (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void
    let isSpatialTapGestureActivated: Bool

    init(_ target: Entity, isSpatialTapReleased: Binding<Bool> = .constant(false), preCompletion: @escaping (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void, completion: @escaping (_: EntityTargetValue<SpatialTapGesture.Value>) -> Void, listenSpatialTapGesture isSpatialTapGestureActivated: Bool = true) {
        print("=====> Target \(target.name)")
        self.target = target
        self._isSpatialTapReleased = isSpatialTapReleased
        self.preCompletion = preCompletion
        self.completion = completion
        self.isSpatialTapGestureActivated = isSpatialTapGestureActivated
    }

    func body(content: Content) -> some View {
        content.gesture(
            SpatialTapGesture().targetedToEntity(target)
                .onChanged { spatialTapGestureValue in
                    var entity: Entity? = spatialTapGestureValue.entity

                    if spatialTapGestureValue.entity != target {
                        entity = HelperGestures.findTarget(target, from: spatialTapGestureValue.entity)
                    }

                    if let entity = entity, isSpatialTapGestureActivated {
                        preCompletion(spatialTapGestureValue)
                        isSpatialTapReleased = false
                    }
                }.onEnded { spatialTapGestureValue in
                    var entity: Entity? = spatialTapGestureValue.entity

                    if spatialTapGestureValue.entity != target {
                        entity = HelperGestures.findTarget(target, from: spatialTapGestureValue.entity)
                    }

                    if let entity = entity, isSpatialTapGestureActivated {
                        completion(spatialTapGestureValue)
                        isSpatialTapReleased = true
                    }
                }
        )
    }
}
