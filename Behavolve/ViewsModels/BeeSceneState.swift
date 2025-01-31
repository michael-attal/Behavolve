//
//  BeeSceneState.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 31/01/2025.
//

import Foundation
import RealityFoundation

enum ImmersiveBeeSceneStep {
    case neutralIdle
    case neutralExplanation
    case neutralBeeGatheringNectarFromFlowers
    case interactionInOwnEnvironment
    case interactionInForrestFullSpace

    mutating func next() {
        switch self {
        case .neutralIdle:
            self = .neutralExplanation
        case .neutralExplanation:
            self = .neutralBeeGatheringNectarFromFlowers
        case .neutralBeeGatheringNectarFromFlowers:
            self = .interactionInOwnEnvironment
        case .interactionInOwnEnvironment:
            self = .interactionInForrestFullSpace
        case .interactionInForrestFullSpace:
            self = .neutralIdle
        }
    }

    mutating func previous() {
        switch self {
        case .neutralIdle:
            self = .interactionInForrestFullSpace
        case .neutralExplanation:
            self = .neutralIdle
        case .neutralBeeGatheringNectarFromFlowers:
            self = .neutralExplanation
        case .interactionInOwnEnvironment:
            self = .neutralBeeGatheringNectarFromFlowers
        case .interactionInForrestFullSpace:
            self = .interactionInOwnEnvironment
        }
    }
}

@MainActor
@Observable
class BeeSceneState {
    var bee = Entity()
    var therapist = Entity()
    var step: ImmersiveBeeSceneStep = .neutralIdle
}
