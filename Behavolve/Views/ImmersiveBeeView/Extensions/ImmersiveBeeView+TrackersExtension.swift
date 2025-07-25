//
//  ImmersiveBeeView+TrackersExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 27/03/2025.
//

// Extension for plane/hand/world tracking providers in RealityView
extension ImmersiveBeeView {
    @MainActor func trackWorldDetection() {
        Task {
            try await AppState.arkitSession.run([AppState.worldTracking])

            for await update in AppState.worldTracking.anchorUpdates {
                print(update.anchor.description)
            }
        }
    }

    @MainActor func trackSceneReconstruction() {
        #if targetEnvironment(simulator)
        print("In simulator, scene reconstruction is disabled!")
        #else
        Task {
            try await AppState.arkitSession.run([AppState.sceneReconstruction])

            for await update in AppState.sceneReconstruction.anchorUpdates {
                print(update.anchor.description)
            }
        }
        #endif
    }

    @MainActor func trackPlaneDetection() {
        #if targetEnvironment(simulator)
        print("In simulator, plane detection is disabled!")
        #else
        Task {
            try await AppState.arkitSession.run([AppState.planeDetection])

            // TODO: Later, when all anchors have been placed (isFlowersPlaced, ...), put a condition to cancel the for await loop.
            for await update in AppState.planeDetection.anchorUpdates {
                if update.anchor.classification == .table {
                    appState.beeSceneState.tableInPatientRoom = update.anchor
                } else if update.anchor.classification == .floor {
                    appState.beeSceneState.floorInPatientRoom = update.anchor
                }
                if appState.beeSceneState.isFlowersPlaced == false {
                    placeFlower()
                }
            }
        }
        #endif
    }

    @MainActor func trackHandDetection() {
        #if targetEnvironment(simulator)
        print("In simulator hand tracking is disabled!")
        #else
        Task {
            try await AppState.arkitSession.run([AppState.handTracking])

            for await update in AppState.planeDetection.anchorUpdates {
                if update.anchor.classification == .ceiling {
                    print("ceiling detected!")
                }
            }
        }
        Task {
            print("Start Custom gesture if we want to")
        }
        #endif
    }

    @MainActor func trackImageDetection() {
        #if targetEnvironment(simulator)
        print("In simulator image tracking is disabled!")
        #else
        #endif
    }
}
