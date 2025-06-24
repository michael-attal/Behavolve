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

    static func createExtrudedHaloMesh(radius: CGFloat = 1, depth: Float = 0, color: SIMD3<Float> = .one, startAngle: Angle = Angle.radians(0), endAngle: Angle = Angle.radians(.pi * 2), clockwise: Bool = false) -> MeshResource {
        let shape = RealityKitHelper.generateRingShape(radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)

        // Prepare the extrusion options with a 90° rotation around X
        var options = MeshResource.ShapeExtrusionOptions()
        let transform = Transform(
            rotation: simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0)),
            translation: SIMD3<Float>(0, 0, 0)
        )
        // options.materialAssignment = .init(assignAll:  // TODO: Maybe assign here the material?
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

        var mesh = try! MeshResource(extruding: shape, extrusionOptions: options)
        return mesh
    }

    // Depth in cm, radius in meter
    @MainActor
    static func createHaloEntity(radius: CGFloat = 1, depth: Float = 0, color: SIMD3<Float> = .one) async -> Entity {
        // TODO: Put the color as parameter and see how to pass it to shader graph
        let mesh = RealityKitHelper.createExtrudedHaloMesh(radius: radius, depth: depth, color: color)
        let haloMaterialsScene = try! await Entity(named: "Models/Halos/Halo Materials", in: realityKitContentBundle)
        guard let cylinderEntityWithHaloMaterial1 = haloMaterialsScene.findEntity(named: "Cube") else { fatalError("Cannot find Cylinder entity.") }
        let cylinderComponents = cylinderEntityWithHaloMaterial1.components
        guard let cylinderModelComponent = cylinderComponents[ModelComponent.self] else { fatalError("Model entity is required.") }
        guard let haloMaterial = cylinderModelComponent.materials.first as? ShaderGraphMaterial else {
            fatalError("Expected ShaderGraphMaterial not found.")
        }
        // let material = try! await ShaderGraphMaterial(named: "Halo_Material_1", from: "Models/Halos/Halo Materials.usda", in: realityKitContentBundle) // <- this doesn't work idk why

        return ModelEntity(mesh: mesh, materials: [haloMaterial])
    }
}
