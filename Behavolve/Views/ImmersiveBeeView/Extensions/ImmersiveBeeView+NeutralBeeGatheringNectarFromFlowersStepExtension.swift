//
//  ImmersiveBeeView+NeutralBeeGatheringNectarFromFlowersStepExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import Foundation

// Extension for the NeutralBeeGatheringNectarFromFlowers step
extension ImmersiveBeeView {
    func performNeutralBeeGatheringNectarFromFlowersStep() {
        appState.beeSceneState.beeAudioPlaybackController.play()
        let daffodilFlowerPot = appState.beeSceneState.daffodilFlowerPot

        var nectarSourcesPositions: [SIMD3<Float>] = []
        for i in 1 ... 5 {
            if let entity = daffodilFlowerPot.findEntity(named: "Nectar_spot_\(i)") {
                nectarSourcesPositions.append(entity.position(relativeTo: nil))
            }
        }

        let nectarSources = nectarSourcesPositions.enumerated().map { index, position in
            NectarSource(
                position: position,
                stock: 100,
                reloadDuration: TimeInterval(Int.random(in: 20...40))
            )
        }

        var depotSitePosition = appState.beeSceneState.beehive.position(relativeTo: nil)
        depotSitePosition.y += 0.1

        appState.beeSceneState.bee.components.set(
            NectarGatheringComponent(
                nectarDepotSitePosition: depotSitePosition,
                nectarSources: nectarSources,
                speed: 0.6,
            )
        )
    }
}
