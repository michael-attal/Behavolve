//
//  AppModel.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import SwiftUI

enum ImmersiveViewAvailable: String {
    case none
    case bee
    case snake

    static func getAllImmersiveViews() -> [ImmersiveViewAvailable] {
        return [.bee, .snake]
    }
}

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    var immersiveSpaceState = ImmersiveSpaceState.closed

    var currentImmersiveView: ImmersiveViewAvailable = .none
}
