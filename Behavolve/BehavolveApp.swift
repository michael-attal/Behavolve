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
        LookAtTargetComponent.registerComponent()
        LookAtTargetSystem.registerSystem()

        MoveToComponent.registerComponent()
        MovementSystem.registerSystem()

        OscillationComponent.registerComponent()
        OscillationSystem.registerSystem()

        SteeringComponent.registerComponent()
        SteeringSystem.registerSystem()

        // PathfindingSystem.registerSystem() // Not working atm

        NectarDepositComponent.registerComponent()
        NectarDepositSystem.registerSystem()

        NectarGatheringComponent.registerComponent()
        NectarGatheringSystem.registerSystem()

        #if !targetEnvironment(simulator)
        ExitGestureComponent.registerComponent()
        ExitGestureSystem.registerSystem()

        HandComponent.registerComponent()
        HandInputSystem.registerSystem()

        HandProximityComponent.registerComponent()
        HandProximitySystem.registerSystem()

        HandCollisionComponent.registerComponent()
        HandCollisionSystem.registerSystem()
        #endif

        UserProximityComponent.registerComponent()
        UserProximitySystem.registerSystem()

        FleeStateComponent.registerComponent()
        
        TargetReachedSystem.registerSystem()
        TargetReachedComponent.registerComponent()
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
