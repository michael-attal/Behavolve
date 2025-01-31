//
//  ScaleGestureModifier.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 30/01/2025.
//



import RealityKit
import SwiftUI

public extension View {
    func scaleGesture(
        axZoomIn: Bool = false,
        axZoomOut: Bool = false,
        isScaling: Binding<Bool> = .constant(false)
    ) -> some View {
        modifier(
            ScaleGestureModifier(
                axZoomIn: axZoomIn,
                axZoomOut: axZoomOut,
                isScaling: isScaling
            )
        )
    }

    func scaleGestureToEntity(
        _ target: Entity,
        isScaling: Binding<Bool> = .constant(false),
        currentScale: Binding<Float> = .constant(1),
        scaleMin: Float? = nil,
        scaleMax: Float = 10.0,
        listenScaleGesture: Bool = true
    ) -> some View {
        modifier(
            ScaleGestureModifierToEntity(
                target,
                isScaling: isScaling,
                currentScale: currentScale,
                scaleMin: scaleMin,
                scaleMax: scaleMax,
                listenScaleGesture: listenScaleGesture
            )
        )
    }
}

/// A modifier that add scale gesture to a View.
private struct ScaleGestureModifier: ViewModifier {
    @State private var scale: Double = 1
    @State private var startScale: Double?

    var axZoomIn: Bool
    var axZoomOut: Bool
    @Binding var isScaling: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            // Enable people to scale the model within certain bounds.
            .simultaneousGesture(MagnifyGesture()
                .onChanged { value in
                    if let startScale {
                        scale = max(0.1, min(3, value.magnification * startScale))
                    } else {
                        startScale = scale
                    }
                    isScaling = true
                }
                .onEnded { _ in
                    startScale = scale
                    isScaling = false
                }
            )
            .onChange(of: axZoomIn) {
                scale = max(0.1, min(3, scale + 0.2))
                startScale = scale
            }
            .onChange(of: axZoomOut) {
                scale = max(0.1, min(3, scale - 0.2))
                startScale = scale
            }
    }
}

/// A modifier that add scale gesture to an Entity.
private struct ScaleGestureModifierToEntity: ViewModifier {
    var target: Entity
    @Binding var isScaling: Bool
    @Binding var currentScale: Float
    @State var startScale: SIMD3<Float>
    let isScaleGestureActivated: Bool
    let scaleMin: Float
    let scaleMax: Float

    init(_ target: Entity, isScaling: Binding<Bool> = .constant(false), currentScale: Binding<Float> = .constant(1), scaleMin: Float?, scaleMax: Float = 10.0, listenScaleGesture isScaleGestureActivated: Bool = true) {
        self.target = target
        self._isScaling = isScaling
        self._currentScale = currentScale
        if let scaleMin = scaleMin {
            self.scaleMin = scaleMin
        } else {
            self.scaleMin = target.scale.x // By default, the minimum scale is arbitrarily set to the value of entity.scale.x.
        }
        self.scaleMax = scaleMax
        self.startScale = SIMD3(repeating: currentScale.wrappedValue)
        self.isScaleGestureActivated = isScaleGestureActivated
    }

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(MagnifyGesture()
                .targetedToEntity(target)
                .onChanged { magnifyGestureValue in
                    var entity: Entity? = magnifyGestureValue.entity

                    if magnifyGestureValue.entity != target {
                        entity = HelperGestures.findTarget(target, from: magnifyGestureValue.entity)
                    }

                    if let entity = entity, isScaleGestureActivated {
                        // Enable people to scale the Entity within certain bounds.
                        let scale = startScale * Float(magnifyGestureValue.magnification)
                        if scale.min() < scaleMin {
                            entity.scale = SIMD3(scaleMin, scaleMin, scaleMin)
                        } else if scale.max() > scaleMax {
                            entity.scale = SIMD3(scaleMax, scaleMax, scaleMax)
                        } else {
                            entity.scale = scale
                        }
                        currentScale = entity.scale.x
                        isScaling = true
                    }
                }
                .onEnded { magnifyGestureValue in
                    var entity: Entity? = magnifyGestureValue.entity

                    if magnifyGestureValue.entity != target {
                        entity = HelperGestures.findTarget(target, from: magnifyGestureValue.entity)
                    }

                    if let entity = entity, isScaleGestureActivated {
                        startScale = entity.scale
                        isScaling = false
                    }
                }
            )
    }
}
