//
//  ImmersiveBeeView+InteractionInForrestFullSpaceStepExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import SwiftUI

// Extension for the InteractionInForrestFullSpace step
extension ImmersiveBeeView {
    func performPrepareInteractionInForrestFullSpaceStep() async throws {
        let forest = try await loadForest()
        forest.position = [0, 0, -8.3]
        appState.beeSceneState.forest = forest
        RealityKitHelper.addIBLReceiverToAllModels(in: appState.beeSceneState.therapist, from: appState.beeSceneState.lightSkySphereSourceFromForest)
        RealityKitHelper.addIBLReceiverToAllModels(in: appState.beeSceneState.bee, from: appState.beeSceneState.lightSkySphereSourceFromForest)
        RealityKitHelper.addIBLReceiverToAllModels(in: appState.beeSceneState.dialogue, from: appState.beeSceneState.lightSkySphereSourceFromForest)
    }

    func performInteractionInForrestFullSpaceStep() {
        appState.currentImmersionStyle = .full
                
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Water_Bottle" })
                
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Halo" })
                
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Daffodil_flower_pot" })
        
        appState.beeSceneState.bee.components.remove(UserProximityComponent.self)
                
        appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(appState.beeSceneState.lightSkySphereSourceFromForest)
                
        appState.beeSceneState.beehive.position = [7, 13, -26.1]
                
        appState.beeSceneState.bee.position = appState.beeSceneState.beehive.position / 4
                
        addNectarGatheringToBee(nectarSpots: appState.beeSceneState.bowlOfFruit, goToDepositAmount: 2000)
                
        appState.beeSceneState.therapist.position.x -= 1
        appState.beeSceneState.therapist.position.y += 0.16
        appState.beeSceneState.therapist.position.z -= 1.8
                
        appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(appState.beeSceneState.forest)
                
        // TODO: use fake 3D Mesh text button with custom input
    }

    func performFinishedInteractionInForrestFullSpaceStep() async throws {
        openWindow(id: appState.BeeScenePostSessionAssessmentWindowID)
    }
    
    func performCleanInteractionInForrestFullSpaceStep() {
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Forest" })
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "SkySphere" })
        RealityKitHelper.removeIBLReceiverToAllModels(in: appState.beeSceneState.therapist)
        RealityKitHelper.removeIBLReceiverToAllModels(in: appState.beeSceneState.bee)
        RealityKitHelper.removeIBLReceiverToAllModels(in: appState.beeSceneState.dialogue)
        appState.beeSceneState.beehive.position = appState.beeSceneState.beehiveInitialPosition
        appState.beeSceneState.bee.position = appState.beeSceneState.beehiveInitialPosition
        appState.beeSceneState.bee.components.remove(NectarGatheringComponent.self)
        addNectarGatheringToBee(nectarSpots: appState.beeSceneState.daffodilFlowerPot)
        appState.beeSceneState.therapist.position = appState.beeSceneState.therapistInitialPosition
        appState.beeSceneState.bee.components.set(UserProximityComponent(safeDistance: 1.0, fleeSpeed: 0.5, fleeDuration: 2))
    }
}
