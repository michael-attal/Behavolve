//
//  ImmersiveBeeView+NeutralExplanationStepExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import RealityKit
import UIKit

// Extension for the NeutralExplanation step
extension ImmersiveBeeView {
    func performNeutralExplanationStep() {
        let destination: SIMD3<Float> = [0, 1.5, -1.5]
        appState.beeSceneState.bee.components.set(
            MoveToComponent(destination: destination,
                            speed: 0.5,
                            epsilon: 0.01,
                            strategy: .direct)
        )
        appState.beeSceneState.bee.components.set(LookAtTargetComponent(target: .world(destination)))

        Task {
            try? await Task.sleep(for: .milliseconds(2000))
            appState.beeSceneState.bee.components.set(LookAtTargetComponent(target: .world(LookAtTargetSystem.shared.devicePoseSafe.value.translation)))
        }

        appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(createBeeInGlassCube(beeEntity: appState.beeSceneState.bee, position: [0, 1.5, -1.5]))
    }

    func performFinishedNeutralExplanationStep() {}

    func performCleanNeutralExplanationStep() {
        appState.beeSceneState.bee.position = appState.beeSceneState.beehiveInitialPosition

        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "BeeGlassCube" })
    }

    /// Creates a transparent glass cube at the given position, with the bee entity placed inside.
    func createBeeInGlassCube(beeEntity: Entity, position: SIMD3<Float> = [0, 1.5, -1.5]) -> ModelEntity {
        // Create glass cube mesh
        let cubeSize: Float = 0.1
        let cubeMesh = MeshResource.generateBox(size: cubeSize)

        var glassMaterial = PhysicallyBasedMaterial()
        glassMaterial.baseColor = .init(tint: UIColor(red: 0.8, green: 0.95, blue: 1.0, alpha: 0.22))
        glassMaterial.roughness = 0.04 // almost perfectly smooth
        glassMaterial.clearcoat = .init(floatLiteral: 1.0) // Brillance
        glassMaterial.clearcoatRoughness = .init(floatLiteral: 0.01)
        glassMaterial.specular = .init(floatLiteral: 0.95) // Intensity of shiny highlights on the glass
        glassMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.22))
        glassMaterial.faceCulling = .none // See inside the cube
        glassMaterial.emissiveIntensity = 0.1
        glassMaterial.emissiveColor = .init(color: .white)
        // glassMaterial.opacityThreshold = 0.0

        // Create the cube entity
        let glassCube = ModelEntity(mesh: cubeMesh, materials: [glassMaterial])
        glassCube.name = "BeeGlassCube"
        glassCube.position = position
        ManipulationComponent.configureEntity(glassCube)
        var manipulationComponent = glassCube.components[ManipulationComponent.self]!
        manipulationComponent.releaseBehavior = .stay
        glassCube.components.set(manipulationComponent)

        return glassCube
    }
}
