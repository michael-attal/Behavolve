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
        let (nextTextButton3D, prevTextButton3D) = try await load3DTextButtons()
        forest.position = [0, 0, -8.3]
        appState.beeSceneState.forest = forest
        appState.beeSceneState.nextTextButton3D = nextTextButton3D
        appState.beeSceneState.prevTextButton3D = prevTextButton3D
        RealityKitHelper.addIBLReceiverToAllModels(in: appState.beeSceneState.therapist, from: appState.beeSceneState.lightSkySphereSourceFromForest)
        RealityKitHelper.addIBLReceiverToAllModels(in: appState.beeSceneState.bee, from: appState.beeSceneState.lightSkySphereSourceFromForest)
        RealityKitHelper.addIBLReceiverToAllModels(in: appState.beeSceneState.dialogue, from: appState.beeSceneState.lightSkySphereSourceFromForest)
    }

    func performInteractionInForrestFullSpaceStep() {
        // appState.currentImmersionStyle = .full
                
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Water_Bottle" })
                
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Halo" })
                
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Daffodil_flower_pot" })
        
        appState.beeSceneState.bee.components.remove(UserProximityComponent.self)
                
        appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(appState.beeSceneState.lightSkySphereSourceFromForest)
                
        appState.beeSceneState.beehive.position = [15, 13, -25]
        
        appState.beeSceneState.bee.components.remove(MoveToComponent.self)
        appState.beeSceneState.bee.position = [5, 5, -5]
        
        addNectarGatheringToBee(nectarSpots: appState.beeSceneState.bowlOfFruit, goToDepositAmount: 700, reloadDuration: 20)
                
        appState.beeSceneState.therapist.position.x -= 1
        appState.beeSceneState.therapist.position.y += 0.16
        appState.beeSceneState.therapist.position.z -= 1.8
        
        appState.beeSceneState.nextTextButton3D.position = appState.beeSceneState.therapist.position
        appState.beeSceneState.prevTextButton3D.position.x -= 0.5
        appState.beeSceneState.nextTextButton3D.position.y += 2
        appState.beeSceneState.prevTextButton3D.position = appState.beeSceneState.therapist.position
        appState.beeSceneState.prevTextButton3D.position.x += 0.5
        appState.beeSceneState.prevTextButton3D.position.y += 2

        // appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(appState.beeSceneState.nextTextButton3D)
        // appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(appState.beeSceneState.prevTextButton3D)
        appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(appState.beeSceneState.forest)
        
        #if !targetEnvironment(simulator)
        appState.beeSceneState.bee.components.set(HandProximityComponent(safeDistance: 0.3, fleeSpeed: 0.5, fleeDuration: .infinity)) // If hand proxity has been detected and no abrupt gesture then the bee will flee away forever and a notification will be send to end the experience
        appState.beeSceneState.bee.components.set(HandCollisionComponent(collisionDistance: 0.2, impulseStrength: 1, recoverDuration: 3))
        #endif
        
        appState.beeSceneState.bee.components.set(EntityProximityComponent(distanceToUser: 0, targetDistanceToUser: 8))
    }

    func performFinishedInteractionInForrestFullSpaceStep() async throws {
        appState.beeSceneState.step.next()
    }
    
    func performCleanInteractionInForrestFullSpaceStep() {
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Forest_With_Picnic" })
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "SkySphere" })
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "NextTextButton3D" })
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "PrevTextButton3D" })
        RealityKitHelper.removeIBLReceiverToAllModels(in: appState.beeSceneState.therapist)
        RealityKitHelper.removeIBLReceiverToAllModels(in: appState.beeSceneState.bee)
        RealityKitHelper.removeIBLReceiverToAllModels(in: appState.beeSceneState.dialogue)

        appState.beeSceneState.beehive.position = appState.beeSceneState.beehiveInitialPosition
        appState.beeSceneState.bee.position = appState.beeSceneState.beehiveInitialPosition
        appState.beeSceneState.bee.components.remove(MoveToComponent.self)
        appState.beeSceneState.bee.components.remove(NectarGatheringComponent.self)
        addNectarGatheringToBee(nectarSpots: appState.beeSceneState.daffodilFlowerPot)
        appState.beeSceneState.therapist.position = appState.beeSceneState.therapistInitialPosition
        appState.beeSceneState.bee.components.set(UserProximityComponent(safeDistance: 1.0, fleeSpeed: 0.5, fleeDuration: 2))
    }
}
