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
        if appState.beeSceneState.beeImmersiveContentSceneEntity.findEntity(named: "Forest") == nil {
            let forest = try await loadForest()
            forest.position = [0, 0, -8.3]
            appState.beeSceneState.forest = forest
            RealityKitHelper.addIBLReceiverToAllModels(in: appState.beeSceneState.therapist, from: appState.beeSceneState.lightSkySphereSourceFromForest)
            RealityKitHelper.addIBLReceiverToAllModels(in: appState.beeSceneState.bee, from: appState.beeSceneState.lightSkySphereSourceFromForest)
            RealityKitHelper.addIBLReceiverToAllModels(in: appState.beeSceneState.dialogue, from: appState.beeSceneState.lightSkySphereSourceFromForest)
        }
    }

    func performInteractionInForrestFullSpaceStep() {
        if type(of: appState.currentImmersionStyle) != FullImmersionStyle.self {
            appState.currentImmersionStyle = .full
        }

        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Water_Bottle" })

        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Halo" })

        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Daffodil_flower_pot" })

        appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(appState.beeSceneState.lightSkySphereSourceFromForest)

        appState.beeSceneState.beehive.position = [7, 13, -26.1]

        addNectarGatheringToBee(nectarSpots: appState.beeSceneState.bowlOfFruit)

        appState.beeSceneState.therapist.position.x -= 0.5
        appState.beeSceneState.therapist.position.y += 0.08
        appState.beeSceneState.therapist.position.z -= 0.9

        appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(appState.beeSceneState.forest)

        // TODO: use fake 3D Mesh text button with custom input

        // TODO: Do the GentleGestureVerificationSystem
    }

    func performFinishedInteractionInForrestFullSpaceStep() async throws {}
}
