//
//  RotationModifier.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 30/01/2025.
//

import RealityKit
import SwiftUI
#if targetEnvironment(simulator)
import ARKit
#else
@preconcurrency import ARKit
#endif

public extension View {
    /// Enables people to rotate a View (with the default hand movement)
    func rotationGesture(
        isRotating: Binding<Bool> = .constant(false)
    ) -> some View {
        modifier(
            RotationModifier(
                isRotating: isRotating
            )
        )
    }

    /// Enables people to rotate a View (with a drag and drop movement)
    func dragRotationGesture(
        isRotating: Binding<Bool> = .constant(false),
        yawLimit: Angle? = nil,
        pitchLimit: Angle? = nil,
        sensitivity: Double = 10,
        axRotateClockwise: Bool = false,
        axRotateCounterClockwise: Bool = false
    ) -> some View {
        modifier(
            DragRotationModifier(
                isRotating: isRotating,
                yawLimit: yawLimit,
                pitchLimit: pitchLimit,
                sensitivity: sensitivity,
                axRotateClockwise: axRotateClockwise,
                axRotateCounterClockwise: axRotateCounterClockwise
            )
        )
    }

    /// Enables people to rotate an Entity (with the default hand movement)
    func rotationGestureToEntity(
        _ target: Entity,
        isRotating: Binding<Bool> = .constant(false),
        speed: Float = 1.0,
        listenRotationGesture: Bool = true
    ) -> some View {
        modifier(
            RotationModifierToEntity(
                target,
                isRotating: isRotating,
                speed: speed,
                listenRotationGesture: listenRotationGesture
            )
        )
    }

    func dragRotationGestureToEntity(
        _ target: Entity,
        isRotating: Binding<Bool> = .constant(false),
        speed: CGFloat = 0.25,
        listenDragRotationGesture: Bool = true,
        startAngle: CGFloat?
    ) -> some View {
        modifier(
            DragRotationModifierToEntity(
                target,
                isRotating: isRotating,
                speed: speed,
                listenDragRotationGesture: listenDragRotationGesture, startAngle: startAngle
            )
        )
    }
}

/// A modifier that add rotation gesture to a View.
private struct RotationModifier: ViewModifier {
    @State private var angle = Angle(degrees: 0.0)

    @Binding var isRotating: Bool

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            RotateGesture().onChanged { value in
                angle = value.rotation
                isRotating = true
            }.onEnded { _ in
                isRotating = false
            }
        ).rotationEffect(angle)
    }
}

/// A modifier that adds a drag rotation gesture to a View in a 3D space.
/// It supports:
///  - Yaw and pitch rotation (around Y and X axes).
///  - Optional yaw/pitch limits for clamping the angles.
///  - Axis blocking (blockYaw/blockPitch) to fully disable rotation on an axis.
///  - Clockwise/counterclockwise rotation triggers.
///  - Spring animations for smoothness.
private struct DragRotationModifier: ViewModifier {
    @State private var baseYaw: Double = 0
    @State private var yaw: Double = 0
    @State private var basePitch: Double = 0
    @State private var pitch: Double = 0

    @Binding var isRotating: Bool

    /// If set, yaw rotation is clamped within ±yawLimit, and pitch rotation is clamped within ±pitchLimit.
    let yawLimit: Angle?
    let pitchLimit: Angle?

    /// Multiplier for how quickly the rotation responds to dragging.
    let sensitivity: Double

    /// Triggers for manual rotation by increments of ±π/6 around the yaw axis.
    let axRotateClockwise: Bool
    let axRotateCounterClockwise: Bool

    /// If `true`, disables rotation around the Y axis (yaw).
    let blockYaw: Bool = false
    /// If `true`, disables rotation around the X axis (pitch).
    let blockPitch: Bool = false

    func body(content: Content) -> some View {
        content
            // Apply 3D rotation effects.
            .rotation3DEffect(.radians(yaw == 0 ? 0.0001 : yaw), axis: .y)
            .rotation3DEffect(.radians(pitch == 0 ? 0.0001 : pitch), axis: .x)
            // The gesture that drives the rotation.
            .gesture(
                DragGesture(minimumDistance: 0.0)
                    .targetedToAnyEntity()
                    .onChanged { value in
                        isRotating = true

                        // Convert gesture points to 3D scene coordinates.
                        let location3D = value.convert(value.location3D, from: .local, to: .scene)
                        let startLocation3D = value.convert(value.startLocation3D, from: .local, to: .scene)
                        let delta = location3D - startLocation3D

                        // Apply a spring animation while dragging.
                        withAnimation(.interactiveSpring()) {
                            yaw = spin(
                                displacement: Double(delta.x),
                                base: baseYaw,
                                limit: yawLimit,
                                blockAxis: blockYaw
                            )
                            pitch = spin(
                                displacement: Double(delta.y),
                                base: basePitch,
                                limit: pitchLimit,
                                blockAxis: blockPitch
                            )
                        }
                    }
                    .onEnded { value in
                        // Convert gesture points to 3D scene coordinates.
                        let location3D = value.convert(value.location3D, from: .local, to: .scene)
                        let startLocation3D = value.convert(value.startLocation3D, from: .local, to: .scene)
                        let predictedEndLocation3D = value.convert(value.predictedEndLocation3D, from: .local, to: .scene)
                        let delta = location3D - startLocation3D
                        let predictedDelta = predictedEndLocation3D - location3D

                        // Apply a spring animation when the gesture ends (for "inertia").
                        withAnimation(.spring()) {
                            yaw = finalSpin(
                                displacement: Double(delta.x),
                                predictedDisplacement: Double(predictedDelta.x),
                                base: baseYaw,
                                limit: yawLimit,
                                blockAxis: blockYaw
                            )
                            pitch = finalSpin(
                                displacement: Double(delta.y),
                                predictedDisplacement: Double(predictedDelta.y),
                                base: basePitch,
                                limit: pitchLimit,
                                blockAxis: blockPitch
                            )
                        }

                        // Store the new base angles for the next gesture.
                        baseYaw = yaw
                        basePitch = pitch

                        isRotating = false
                    }
            )
            // If we receive a `true` on axRotateClockwise or axRotateCounterClockwise,
            // rotate yaw by ±π/6. We guard with `blockYaw` to avoid changes if yaw is blocked.
            .onChange(of: axRotateClockwise) { newValue in
                if newValue {
                    withAnimation(.spring()) {
                        guard !blockYaw else { return }
                        yaw -= (.pi / 6)
                        baseYaw = yaw
                    }
                }
            }
            .onChange(of: axRotateCounterClockwise) { newValue in
                if newValue {
                    withAnimation(.spring()) {
                        guard !blockYaw else { return }
                        yaw += (.pi / 6)
                        baseYaw = yaw
                    }
                }
            }
    }

    /// Calculates the rotation value during the drag (onChanged).
    /// - Parameters:
    ///   - displacement: The distance moved in scene space (x or y).
    ///   - base: The current base angle, so we can add or offset the new delta.
    ///   - limit: An optional Angle that clamps the rotation in ±limit.
    ///   - blockAxis: If true, block rotation completely on this axis.
    /// - Returns: The new angle to apply.
    private func spin(
        displacement: Double,
        base: Double,
        limit: Angle?,
        blockAxis: Bool
    ) -> Double {
        // If we want to completely block rotation on this axis, just return the base angle as is.
        if blockAxis {
            return base
        }

        // If a limit is provided, we do a partial approach:
        // We don't add 'base' here (by original design),
        // but you can customize the behavior if you prefer to accumulate.
        if let limit = limit {
            // Use a scaled arctangent approach to avoid large angles quickly.
            let angleWithinLimit = atan(displacement * sensitivity) * (limit.degrees / 90)
            return base + angleWithinLimit
        } else {
            // No limit: we accumulate the rotation freely.
            return base + displacement * sensitivity
        }
    }

    /// Calculates the final spin value when the gesture ends (onEnded),
    /// potentially applying an "inertia" effect using predicted displacement,
    /// and clamping to a limit if provided.
    /// - Parameters:
    ///   - displacement: Current displacement at gesture end.
    ///   - predictedDisplacement: Projected displacement after gesture ends.
    ///   - base: The base angle before final spin is applied.
    ///   - limit: An optional Angle that clamps the rotation in ±limit.
    ///   - blockAxis: If true, block rotation completely on this axis.
    /// - Returns: The new (final) angle after applying inertia and clamping.
    private func finalSpin(
        displacement: Double,
        predictedDisplacement: Double,
        base: Double,
        limit: Angle?,
        blockAxis: Bool
    ) -> Double {
        // If the axis is blocked, we keep the base angle and skip changes.
        if blockAxis {
            return base
        }

        // If no limit is defined, we do the "free spin" with a cap.
        guard let limit = limit else {
            // Cap the maximum spin to ± one revolution to avoid an extreme jump.
            let cap = .pi * 2.0 / sensitivity
            let delta = displacement + max(-cap, min(cap, predictedDisplacement))
            return base + delta * sensitivity
        }

        // If limit is defined, we clamp the final angle within ±limit (in radians).
        let totalDisplacement = displacement + predictedDisplacement
        let newAngle = base + totalDisplacement * sensitivity
        let limitRadians = limit.radians

        // Clamp between -limit.radians and +limit.radians.
        return max(-limitRadians, min(limitRadians, newAngle))
    }
}

/// A modifier that add rotation gesture to an Entity.
private struct RotationModifierToEntity: ViewModifier {
    @State private var startOrientation: simd_quatf

    let target: Entity
    @Binding var isRotating: Bool
    let speed: Float
    let isRotationGestureActivated: Bool

    init(_ target: Entity, isRotating: Binding<Bool> = .constant(false), speed: Float = 1.0, listenRotationGesture isRotationGestureActivated: Bool = true) {
        self.target = target
        self._isRotating = isRotating
        self.startOrientation = target.orientation(relativeTo: nil)
        self.speed = speed
        self.isRotationGestureActivated = isRotationGestureActivated
    }

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(RotateGesture()
                .targetedToEntity(target)
                .onChanged { rotateGestureValue in
                    var entity: Entity? = rotateGestureValue.entity

                    if rotateGestureValue.entity != target {
                        entity = HelperGestures.findTarget(target, from: rotateGestureValue.entity)
                    }

                    if let entity = entity, isRotationGestureActivated {
                        handleRotationChanged(entity, rotateGestureValue)
                        isRotating = true
                    }
                }.onEnded { rotateGestureValue in
                    var entity: Entity? = rotateGestureValue.entity

                    if rotateGestureValue.entity != target {
                        entity = HelperGestures.findTarget(target, from: rotateGestureValue.entity)
                    }

                    if let entity = entity, isRotationGestureActivated {
                        handleRotationChanged(entity, rotateGestureValue, ended: true)
                        isRotating = false
                    }
                })
    }

    func handleRotationChanged(_ entity: Entity, _ rotateGestureValue: EntityTargetValue<RotateGesture.Value>, ended: Bool = false) {
        let orientation = (startOrientation + simd_quatf(angle: Float(rotateGestureValue.gestureValue.rotation.degrees) * speed, axis: SIMD3<Float>(x: 0, y: 1, z: 0)))

        entity.setOrientation(orientation, relativeTo: nil)

        if ended {
            startOrientation = entity.orientation(relativeTo: nil)
        }
    }
}

/// A modifier that add drag rotation gesture to an Entity.
private struct DragRotationModifierToEntity: ViewModifier {
    private var midX: CGFloat = 500
    private var midY: CGFloat = 500
    @State private var startAngle: CGFloat = 0

    let target: Entity
    @Binding var isRotating: Bool
    let speed: CGFloat
    let isDragRotationGestureActivated: Bool

    init(_ target: Entity, isRotating: Binding<Bool> = .constant(false), isDragRotation: Bool = false, speed: CGFloat = 1.0, listenDragRotationGesture isDragRotationGestureActivated: Bool = true, startAngle: CGFloat?) {
        self.target = target
        self._isRotating = isRotating
        if let startAngle = startAngle {
            self.startAngle = startAngle
        } else {
            self.startAngle = CGFloat(target.transform.rotation.angle)
        }
        self.midX = CGFloat(target.visualBounds(relativeTo: self.target).center.x)
        self.midY = CGFloat(target.visualBounds(relativeTo: self.target).center.y)
        self.speed = speed
        self.isDragRotationGestureActivated = isDragRotationGestureActivated
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

                    if let entity = entity, isDragRotationGestureActivated {
                        let startAngle = entity.components[RotationComponent.self]?.startAngle ?? startAngle
                        let rotationComponent = RotationComponent(value: dragGestureValue, midX: midX, midY: midY, startAngle: startAngle, isEnded: false, speed: speed)
                        entity.components.set(rotationComponent)
                        isRotating = true
                    }
                }.onEnded { dragGestureValue in
                    var entity: Entity? = dragGestureValue.entity
                    if dragGestureValue.entity != target {
                        entity = HelperGestures.findTarget(target, from: dragGestureValue.entity)
                    }

                    if let entity = entity, isDragRotationGestureActivated {
                        let startAngle = entity.components[RotationComponent.self]?.startAngle ?? startAngle
                        let rotationComponent = RotationComponent(value: dragGestureValue, midX: midX, midY: midY, startAngle: startAngle, isEnded: true, speed: speed)
                        entity.components.set(rotationComponent)
                        isRotating = false
                    }
                })
    }
}

public struct RotationComponent: Component {
    public var value: EntityTargetValue<DragGesture.Value>?
    public var midX: CGFloat = 0
    public var midY: CGFloat = 0
    public var startAngle: CGFloat = 0
    public var isEnded = false
    public var speed: CGFloat = 1
}
