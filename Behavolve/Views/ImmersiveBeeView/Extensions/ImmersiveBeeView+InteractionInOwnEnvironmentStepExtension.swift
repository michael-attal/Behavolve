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
        appState.beeSceneState.waterBottle.position = appState.beeSceneState.daffodilFlowerPot.position + SIMD3<Float>(x: 0.5, y: 0, z: 0)
        appState.beeSceneState.waterBottle.position.y = 0.125
        appState.beeSceneState.waterBottle.isEnabled = true
    }
}
