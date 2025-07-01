//
//  BehavolveApp.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import SwiftUI

@main
struct BehavolveApp: App {
    @State private var appState: AppState

    init() {
        appState = AppState()

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

        GentleGestureComponent.registerComponent()
        GentleGestureSystem.registerSystem()

        ThumbUpGestureComponent.registerComponent()
        ThumbUpGestureSystem.registerSystem()

        PalmOpenGestureComponent.registerComponent()
        PalmOpenGestureSystem.registerSystem()
        #endif

        UserProximityComponent.registerComponent()
        UserProximitySystem.registerSystem()

        CalmMotionComponent.registerComponent()
        CalmMotionSystem.registerSystem()

        FleeStateComponent.registerComponent()

        TargetReachedSystem.registerSystem()
        TargetReachedComponent.registerComponent()
    }

    var body: some Scene {
        WindowGroup(id: appState.BeeScenePreSessionAssessmentWindowID) {
            BeeScenePreSessionAssessmentView()
                .environment(appState)
        }.windowResizability(.contentSize)

        WindowGroup(id: appState.BeeScenePostSessionAssessmentWindowID) {
            BeeScenePostSessionAssessmentView()
                .environment(appState)
        }.windowResizability(.contentSize)

        WindowGroup(id: appState.MenuWindowID) {
            MenuView()
                .environment(appState)
        }.windowResizability(.contentSize)

        WindowGroup(id: appState.ConversationWindowID) {
            ConversationView(step: appState.beeSceneState.step)
                .environment(appState)
        }
        .defaultWindowPlacement { _, context in
            if let main = context.windows.first(where: { $0.id == appState.MenuWindowID }) {
                WindowPlacement(.trailing(main))
            } else {
                WindowPlacement()
            }
        }
        .windowResizability(.contentSize)

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
        .immersionStyle(selection: Binding<ImmersionStyle>(
            get: { appState.currentImmersionStyle },
            set: { _ in }
        ), in: .mixed, .full)
    }
}
