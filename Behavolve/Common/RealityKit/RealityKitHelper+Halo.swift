//
//  RealityKitHelper+Halo.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/06/2025.
//

import RealityKit
import RealityKitContent
import simd
import SwiftUI

extension RealityKitHelper {
    /// Generate a 2D ring shape for extrusion
    static func generateRingShape(center: CGPoint = .zero, radius: CGFloat = 1, startAngle: Angle = Angle.radians(0), endAngle: Angle = Angle.radians(.pi * 2), clockwise: Bool = false) -> Path {
        var ringShapePath = Path()

        ringShapePath.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)

        return ringShapePath
    }

    static func createExtrudedHaloMesh(radius: CGFloat = 1, depth: Float = 0, startAngle: Angle = Angle.radians(0), endAngle: Angle = Angle.radians(.pi * 2), clockwise: Bool = false) -> MeshResource {
        let shape = RealityKitHelper.generateRingShape(radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)

        // Prepare the extrusion options with a 90° rotation around X
        var options = MeshResource.ShapeExtrusionOptions()
        let transform = Transform(
            rotation: simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0)),
            translation: SIMD3<Float>(0, 0, 0)
        )
        options.extrusionMethod = .traceTransforms([transform.matrix])
        // var chamferRadius: Float = radius > 1 ? Float(radius) / depth : Float(radius) * depth

        var chamferRadius: Float = depth

        if chamferRadius != 0 {
            if radius > 1 {
                if depth > 1 {
                    chamferRadius = Float(radius) * depth
                } else {
                    chamferRadius = Float(radius) / depth
                }
            } else {
                if depth > 1 {
                    chamferRadius = Float(radius) / depth
                } else {
                    chamferRadius = Float(radius) * depth
                }
            }
        }
        options.chamferRadius = chamferRadius
        // Increase smoothness of the ring
        options.boundaryResolution = .uniformSegmentsPerSpan(segmentCount: 64)

        let mesh = try! MeshResource(extruding: shape, extrusionOptions: options)
        return mesh
    }

    // Depth in cm, radius in meter
    @MainActor
    static func createHaloEntity(radius: CGFloat = 1, depth: Float = 0, baseColor: UIColor = .white, emissiveColor: UIColor = .blue, activateTransparency: Bool = false, minimumOpacity: Float = 1, speed: Float = 2.0, emissiveMultiplier: Float = 30, lowestPercentageEmissive: Float = 0.1, onlyLoadHaloModelFromRealityKitContentBundle: Bool = false) async -> Entity {
        var haloMaterial = try! await ShaderGraphMaterial(named: "/Root/Halo_Material_1", from: "Models/Halos/Halo Materials.usda", in: realityKitContentBundle)
        try! haloMaterial.setParameter(name: "EmissiveColor", value: .color(emissiveColor))
        try! haloMaterial.setParameter(name: "EmissiveMultiplier", value: .float(emissiveMultiplier))
        try! haloMaterial.setParameter(name: "SpeedEmissive", value: .float(speed))
        try! haloMaterial.setParameter(name: "LowestPercentageEmissive", value: .float(lowestPercentageEmissive))
        try! haloMaterial.setParameter(name: "BaseColor", value: .color(baseColor))
        try! haloMaterial.setParameter(name: "ActivateTransparency", value: .bool(activateTransparency))
        try! haloMaterial.setParameter(name: "MinimumOpacity", value: .float(minimumOpacity))

        var haloModelEntity = ModelEntity()
        if onlyLoadHaloModelFromRealityKitContentBundle {
            let haloScene = try! await Entity(named: "Models/Halos/Halo Materials", in: realityKitContentBundle)
            let haloEntity = haloScene.findEntity(named: "Halo_Sample")!
            haloModelEntity = haloEntity.findModelEntity()!
            haloModelEntity = ModelEntity(mesh: haloModelEntity.model!.mesh, materials: [haloMaterial])
            haloModelEntity.scale = .init(x: Float(radius * 2), y: depth, z: Float(radius * 2))
        } else {
            let mesh = RealityKitHelper.createExtrudedHaloMesh(radius: radius, depth: depth)
            haloModelEntity = ModelEntity(mesh: mesh, materials: [haloMaterial])
        }

        haloModelEntity.generateCollisionShapes(recursive: true)
        haloModelEntity.components.set(PhysicsBodyComponent(shapes: haloModelEntity.findFirstCollisionComponent()!.shapes, mass: .infinity, mode: .static))

        return haloModelEntity
    }
}
