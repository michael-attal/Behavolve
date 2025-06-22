//
//  ImmersiveBeeView+InteractionInOwnEnvironmentStepExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

// Extension for the InteractionInOwnEnvironment step
extension ImmersiveBeeView {
    // TODO: Put the bottle next to the flower
    func performInteractionInOwnEnvironmentStep() {
        let flowersPosition = appState.beeSceneState.daffodilFlowerPot.position
        appState.beeSceneState.waterBottle.position.x = flowersPosition.x + 0.5
        appState.beeSceneState.waterBottle.position.z = flowersPosition.z
        // TODO: Fix y position
        appState.beeSceneState.waterBottle.isEnabled = true
    }
}
