//
//  ImmersiveBeeView+InteractionInOwnEnvironmentStepExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

// Extension for the InteractionInOwnEnvironment step
extension ImmersiveBeeView {
    func performInteractionInOwnEnvironmentStep() {
        let flowersPosition = appState.beeSceneState.daffodilFlowerPot.position
        appState.beeSceneState.waterBottle.position.x = flowersPosition.x + 0.5
        appState.beeSceneState.waterBottle.position.z = flowersPosition.z
        appState.beeSceneState.waterBottle.isEnabled = true
        appState.beeSceneState.halo.isEnabled = true
    }
}
