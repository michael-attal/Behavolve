//
//  BehavolveApp.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import SwiftUI

@main
struct BehavolveApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            MenuView()
                .environment(appModel)
        }.windowResizability(.contentSize)
        

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            if appModel.currentImmersiveView == .bee {
                ImmersiveBeeView()
                    .environment(appModel)
                    .onAppear {
                        appModel.immersiveSpaceState = .open
                    }
                    .onDisappear {
                        appModel.immersiveSpaceState = .closed
                    }
            } else {
                // TODO: Other scene
                EmptyView()
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
