//
//  BeeSceneState.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 31/01/2025.
//

import ARKit
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

    func buttonText() -> String {
        switch self {
        case .neutralIdle:
            return "I'm ready to start"
        case .neutralExplanation:
            return "Ok let's continu"
        default:
            return "Next"
        }
    }

    func buttonCancelText() -> String {
        switch self {
        case .neutralIdle:
            return "Cancel"
        default:
            return "Cancel"
        }
    }

    func fakeInputTextForDevelopment() -> String {
        switch self {
        case .neutralIdle:
            return "..."
        default:
            return "Blabla \(self)"
        }
    }
}

@MainActor
@Observable
class BeeSceneState {
    var bee = Entity()
    var beehive = Entity()
    var beeAudioPlaybackController: AudioPlaybackController!
    var therapist = Entity()
    var isFlowersPlaced: Bool = false
    var flowersPotsGroup = Entity()
    var flowersPotOneDefault = Entity()
    var flowersPotTwoAlternativ = Entity()
    var flowersPotTreeOriginal = Entity()
    var daffodilFlowerPot = Entity()
    var tableInPatientRoom: (any Anchor)?
    var floorInPatientRoom: (any Anchor)?
    var step: ImmersiveBeeSceneStep = AppState.isDevelopmentMode ? .neutralBeeGatheringNectarFromFlowers : .neutralIdle
}
