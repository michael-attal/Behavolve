//
//  ImmersiveBeeView+EndStepExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 06/07/2025.
//

import ARKit
import RealityKit
import SwiftUI
import UIKit

// Extension for the End step (the last one)
extension ImmersiveBeeView {
    func performEndStep() {}

    func performCleanEndStep() {
        performCleanInteractionInForrestFullSpaceStep()
        performCleanInteractionInOwnEnvironmentStep()
        performCleanNeutralBeeGatheringNectarFromFlowersStep()
        performCleanNeutralExplanationStep()
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Flying_Bee" })
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "Wooden_Beehive" })
    }
}
