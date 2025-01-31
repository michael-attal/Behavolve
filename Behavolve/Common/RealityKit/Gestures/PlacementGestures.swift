//
//  PlacementGestureModifier.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 30/01/2025.
//

import RealityKit
import SwiftUI

public extension View {
    /// Listens for gestures and places an item based on those inputs.
    func placementGesture(
        initialPosition: Point3D = .zero,
        isMoving: Binding<Bool?> = .constant(nil)
    ) -> some View {
        modifier(
            PlacementGestureModifier(
                initialPosition: initialPosition,
                isMoving: isMoving
            )
        )
    }

    func placementGestureToEntity(
        _ target: Entity,
        isMoving: Binding<Bool> = .constant(false)
    ) -> some View {
        modifier(
            PlacementGestureModifierToEntity(
                target,
                isMoving: isMoving
            )
        )
    }
}

/// A modifier that adds gestures and positioning to a View
private struct PlacementGestureModifier: ViewModifier {
    @State private var position: Point3D = .zero
    @State private var startPosition: Point3D?

    var initialPosition: Point3D
    @Binding var isMoving: Bool?

    func body(content: Content) -> some View {
        content
            .onAppear {
                position = initialPosition
            }
            .position(x: position.x, y: position.y)
            .offset(z: position.z)

            // Enable people to move the model anywhere in their space.
            .gesture(DragGesture(minimumDistance: 0.0, coordinateSpace: .global)
                .handActivationBehavior(.pinch)
                .onChanged { value in
                    if let startPosition {
                        let delta = value.location3D - value.startLocation3D
                        position = startPosition + delta
                    } else {
                        startPosition = position
                    }
                    isMoving = true
                }
                .onEnded { _ in
                    startPosition = nil
                    isMoving = false
                }
            )
    }
}

/// A modifier that adds gestures and positioning to an Entity
private struct PlacementGestureModifierToEntity: ViewModifier {
    let target: Entity
    @Binding var isMoving: Bool
    @State var startLocation: SIMD3<Float>
    let isPlacementGestureActivated: Bool

    init(_ target: Entity, isMoving: Binding<Bool> = .constant(false), isPlacementGestureActivated: Bool = true) {
        self.target = target
        self.startLocation = target.position(relativeTo: nil)
        self._isMoving = isMoving
        self.isPlacementGestureActivated = isPlacementGestureActivated
    }

    func body(content: Content) -> some View {
        content
            .gesture(DragGesture(minimumDistance: 0.0)
                .targetedToEntity(target)
                .onChanged { dragGestureValue in
                    var entity: Entity? = dragGestureValue.entity

                    if dragGestureValue.entity != target {
                        entity = HelperGestures.findTarget(target, from: dragGestureValue.entity)
                    }

                    if let entity = entity, isPlacementGestureActivated {
                        handleDragPlacement(entity, dragGestureValue)
                        isMoving = true
                    }
                }
                .onEnded { dragGestureValue in
                    var entity: Entity? = dragGestureValue.entity

                    if dragGestureValue.entity != target {
                        entity = HelperGestures.findTarget(target, from: dragGestureValue.entity)
                    }

                    if let entity = entity, isPlacementGestureActivated {
                        handleDragPlacement(entity, dragGestureValue, ended: true)
                        isMoving = false
                    }
                }
            )
    }

    @MainActor
    func handleDragPlacement(_ entity: Entity, _ dragGestureValue: EntityTargetValue<DragGesture.Value>, ended: Bool = false) {
        let destination = dragGestureValue.convert(dragGestureValue.gestureValue.translation3D, from: .local, to: .scene)
        entity.position = (startLocation + destination)

        if ended {
            startLocation = entity.position(relativeTo: nil)
        }
    }
}
