//
//  ImmersiveBeeView+NeutralExplanationStepExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

// Extension for the NeutralExplanation step
extension ImmersiveBeeView {
    func performNeutralExplanationStep() {
        // TODO: Put the bee in a cube to make the user feel safer.
        appState.beeSceneState.bee.components.set(
            MoveToComponent(destination: [0, 1.5, -1.5], // [0, 1, -0.4] // when debugging
                            speed: 0.5,
                            epsilon: 0.01,
                            strategy: .direct)
        )
    }
}
