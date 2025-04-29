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

        MoveToComponent.registerComponent()
        MovementSystem.registerSystem()

        OscillationComponent.registerComponent()
        OscillationSystem.registerSystem()

        SteeringComponent.registerComponent()
        SteeringSystem.registerSystem()

        PathfindingSystem.registerSystem()

        NectarDepositSystem.registerSystem()
        NectarDepositComponent.registerComponent()

        NectarGatheringSystem.registerSystem()
        NectarGatheringComponent.registerComponent()

        #if !targetEnvironment(simulator)
        ExitGestureComponent.registerComponent()
        HandComponent.registerComponent()
        HandProximityComponent.registerComponent()
        HandCollisionComponent.registerComponent()

        ExitGestureSystem.registerSystem()
        HandInputSystem.registerSystem()
        HandProximitySystem.registerSystem()
        HandCollisionSystem.registerSystem()
        #endif

        UserProximityComponent.registerComponent()
        FleeStateComponent.registerComponent()

        UserProximitySystem.registerSystem()
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
