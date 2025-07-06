//
//  ImmersiveBeeView+NeutralIdleStepExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 04/07/2025.
//

import ARKit
import RealityKit
import SwiftUI
import UIKit

// Extension for the NeutralIdle step (the first one)
extension ImmersiveBeeView {
    func performNeutralIdleStep() {
        if type(of: appState.currentImmersionStyle) != MixedImmersionStyle.self {
            appState.currentImmersionStyle = .mixed
        }
    }

    func performCleanNeutralIdleStep() {
        appState.beeSceneState.beeImmersiveContentSceneEntity.children.removeAll()
    }
}
