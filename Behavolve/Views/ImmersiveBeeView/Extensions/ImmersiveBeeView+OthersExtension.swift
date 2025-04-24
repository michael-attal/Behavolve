//
//  ImmersiveBeeView+OthersExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 01/04/2025.
//

import RealityFoundation

extension ImmersiveBeeView {
    func placeFlower() {
        if let table = appState.beeSceneState.tableInPatientRoom {
            // appState.beeSceneState.daffodilFlowerPot.position = AnchorEntity(.plane(.horizontal, classification: .table, minimumBounds: [0.2, 0.2])).position
            appState.beeSceneState.daffodilFlowerPot.transform = Transform(matrix: table.originFromAnchorTransform)
        } else if let floor = appState.beeSceneState.floorInPatientRoom {
            // appState.beeSceneState.daffodilFlowerPot.position = AnchorEntity(.plane(.horizontal, classification: .floor, minimumBounds: [0.5, 0.5])).position
            appState.beeSceneState.daffodilFlowerPot.transform = Transform(matrix: floor.originFromAnchorTransform)
        } else {
            // Let the flower in the initial place
        }
    }
}
