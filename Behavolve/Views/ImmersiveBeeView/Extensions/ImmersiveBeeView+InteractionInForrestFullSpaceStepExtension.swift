//
//  ImmersiveBeeView+InteractionInForrestFullSpaceStepExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

import SwiftUI

// Extension for the InteractionInForrestFullSpace step
extension ImmersiveBeeView {
    // TODO: Clean up old elements and load full space.
    func performPrepareInteractionInForrestFullSpaceStep() async throws {}

    func performInteractionInForrestFullSpaceStep() {
        if type(of: appState.currentImmersionStyle) != FullImmersionStyle.self {
            appState.currentImmersionStyle = .full
        }
        // TODO: Stay in mixed mode since Apple has decided to not allow UI button on .full space.
        // Instead do a dome around the user? Or use fake 3D Mesh text button with custom input
    }

    func performFinishedInteractionInForrestFullSpaceStep() async throws {}
}
