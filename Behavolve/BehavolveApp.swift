//
//  BehavolveApp.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import SwiftUI

@main
struct BehavolveApp: App {
    @State private var appState = AppState()

    init() {
        LookAtTargetSystem.registerSystem()
        LookAtTargetComponent.registerComponent()
    }

    var body: some Scene {
        WindowGroup(id: appState.MenuWindowID) {
            MenuView()
                .environment(appState)
        }.windowResizability(.contentSize)

        ImmersiveSpace(id: appState.immersiveSpaceID) {
            if appState.currentImmersiveView == .bee {
                ImmersiveBeeView()
                    .environment(appState)
                    .onAppear {
                        appState.immersiveSpaceState = .open
                    }
                    .onDisappear {
                        appState.immersiveSpaceState = .closed
                    }
            } else {
                // TODO: Other scene
                EmptyView()
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
