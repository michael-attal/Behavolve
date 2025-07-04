//
//  ImmersiveBeeView+NeutralBeeGatheringNectarFromFlowersStepExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import Foundation
import RealityKit

// Extension for the NeutralBeeGatheringNectarFromFlowers step
extension ImmersiveBeeView {
    func performNeutralBeeGatheringNectarFromFlowersStep() {
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll(where: { $0.name == "BeeGlassCube" })
        appState.beeSceneState.beeAudioPlaybackController.play()

        #if !targetEnvironment(simulator)
        appState.beeSceneState.bee.components.set(HandProximityComponent(safeDistance: 0.3, fleeSpeed: 0.5, fleeDuration: 2))
        appState.beeSceneState.bee.components.set(HandCollisionComponent(collisionDistance: 0.2, impulseStrength: 1, recoverDuration: 3))
        #endif

        appState.beeSceneState.bee.components.set(UserProximityComponent(safeDistance: 1.0, fleeSpeed: 0.5, fleeDuration: 2))
        addNectarGatheringToBee(nectarSpots: appState.beeSceneState.daffodilFlowerPot)
    }

    func performCleanNeutralBeeGatheringNectarFromFlowersStep() {
        appState.beeSceneState.beeAudioPlaybackController.pause()
        #if !targetEnvironment(simulator)
        appState.beeSceneState.bee.components.remove(HandProximityComponent.self)
        appState.beeSceneState.bee.components.remove(HandCollisionComponent.self)
        #endif

        appState.beeSceneState.bee.components.remove(UserProximityComponent.self)
        appState.beeSceneState.bee.components.remove(NectarGatheringComponent.self)
    }

    func addNectarGatheringToBee(nectarSpots: Entity, goToDepositAmount: Int = 400) {
        var nectarSourcesPositions: [SIMD3<Float>] = []
        for i in 1 ... 5 {
            if let entity = nectarSpots.findEntity(named: "Nectar_spot_\(i)") {
                nectarSourcesPositions.append(entity.position(relativeTo: nil))
            }
        }

        let nectarSources = nectarSourcesPositions.enumerated().map { _, position in
            NectarSource(
                position: position,
                stock: 100,
                reloadDuration: TimeInterval(Int.random(in: 20 ... 40))
            )
        }

        var depotSitePosition = appState.beeSceneState.beehive.position(relativeTo: nil)
        depotSitePosition.y += 0.1

        appState.beeSceneState.bee.components.set(
            NectarGatheringComponent(
                nectarDepotSitePosition: depotSitePosition,
                nectarSources: nectarSources,
                speed: 0.3,
                goToDepositAmount: 400
            )
        )
    }
}
