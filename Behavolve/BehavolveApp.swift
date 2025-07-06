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

    var body: some Scene {
        WindowGroup(id: appState.MenuWindowID) {
            MenuView()
                .environment(appState)
        }.windowResizability(.contentSize)

        WindowGroup(id: appState.BeeScenePreSessionAssessmentWindowID) {
            BeeScenePreSessionAssessmentView()
                .environment(appState)
        }
        .windowResizability(.contentSize)
        .defaultWindowPlacement { _, context in
            if let main = context.windows.first(where: { $0.id == appState.MenuWindowID }) {
                WindowPlacement(.replacing(main))
            } else {
                WindowPlacement()
            }
        }
        .windowResizability(.contentSize)

        WindowGroup(id: appState.BeeScenePostSessionAssessmentWindowID) {
            BeeScenePostSessionAssessmentView()
                .environment(appState)
        }
        .windowResizability(.contentSize)
        .defaultWindowPlacement { _, context in
            if let main = context.windows.first(where: { $0.id == appState.ConversationWindowID }) {
                // WindowPlacement(.leading(main))
                WindowPlacement(.utilityPanel)
            } else {
                WindowPlacement()
            }
        }

        WindowGroup(id: appState.ConversationWindowID) {
            ConversationView(step: appState.beeSceneState.step)
                .environment(appState)
        }
        .defaultWindowPlacement { _, context in
            if let main = context.windows.first(where: { $0.id == appState.BeeScenePreSessionAssessmentWindowID }) {
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
