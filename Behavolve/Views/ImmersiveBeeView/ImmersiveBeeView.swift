//
//  ImmersiveView.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import RealityKit
import RealityKitContent
import SwiftUI

enum ImmersiveBeeViewError: Error {
    case entityError(message: String)
}

struct ImmersiveBeeView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var errorMessage: String?
    @State var spatialTrackingSession = SpatialTrackingSession()

    var body: some View {
        RealityView { content, attachments in
            do {
                // let configuration = SpatialTrackingSession.Configuration(
                //     tracking: [.plane],
                //     sceneUnderstanding: [.collision, .physics]
                // ) // <- New way of tracking plane detection
                // if let unavailableCapabilities = await spatialTrackingSession.run(configuration) {
                //     throw ImmersiveBeeViewError.entityError(message: "Unavailable spatial tracking capabilities: \(unavailableCapabilities)")

                // }
                // let planeAnchor = AnchorEntity(.plane(.horizontal,
                //                                       classification: .table,
                //                                       minimumBounds: [0.15, 0.15]))
                // trackPlaneDetection() // <- Old way to track plane detection
                loadUserHands(content: &content)
                loadSubscribtionToManipulationEvents(content: &content)

                guard let immersiveContentEntity = try? await Entity(named: "Scenes/Bee Scene", in: realityKitContentBundle) else {
                    throw ImmersiveBeeViewError.entityError(message: "Could not load Bee Scene (where all content will be placed)")
                }

                #if targetEnvironment(simulator)
                // Add a plane ground to not let the watter bottle go beyond the scene in simulator
                let planeForGroundCollision = loadPlaneForGroundCollision()
                immersiveContentEntity.addChild(planeForGroundCollision)
                #endif

                let therapist = try await loadTherapist()
                let dialogue = try loadDialogue(from: attachments)
                therapist.addChild(dialogue)
                immersiveContentEntity.addChild(therapist)

                let beehive = try await loadBeehive()
                immersiveContentEntity.addChild(beehive)

                let bee = try await loadBee()
                immersiveContentEntity.addChild(bee)

                let flower = try await loadFlower()
                immersiveContentEntity.addChild(flower)

                content.add(immersiveContentEntity)

                appState.beeSceneState.daffodilFlowerPot = flower
                appState.beeSceneState.therapist = therapist
                appState.beeSceneState.dialogue = dialogue
                appState.beeSceneState.beehive = beehive
                appState.beeSceneState.bee = bee
                appState.beeSceneState.beeImmersiveContentSceneEntity = immersiveContentEntity

            } catch {
                let formattedErrorMessage = "Error in ImmersiveBeeView RealityView's make func: " + String(describing: error)
                print(formattedErrorMessage)
                errorMessage = formattedErrorMessage

                if let errorView = loadCatchError(from: attachments) {
                    content.add(errorView)
                }
            }
        } update: { content, attachments in
            do {
                print(appState.beeSceneState.step)

                switch appState.beeSceneState.step {
                case .neutralExplanation:
                    performNeutralExplanationStep()
                case .neutralBeeGatheringNectarFromFlowers:
                    performNeutralBeeGatheringNectarFromFlowersStep()
                case .interactionInOwnEnvironment:
                    if appState.beeSceneState.isWaterBottlePlacedOnHalo {
                        Task { @MainActor in
                            try await performFinishedInteractionInOwnEnvironmentStep()
                        }
                    } else {
                        if appState.beeSceneState.isCurrentStepConfirmed {
                            performInteractionInOwnEnvironmentStep()
                        } else {
                            Task { @MainActor in
                                try await performPrepareInteractionInOwnEnvironmentStep()
                            }
                        }
                    }
                case .interactionInForrestFullSpace:
                    if appState.beeSceneState.hasBeeFlownAway {
                        Task { @MainActor in
                            try await performFinishedInteractionInForrestFullSpaceStep()
                        }
                    } else {
                        if appState.beeSceneState.isCurrentStepConfirmed {
                            performInteractionInForrestFullSpaceStep()
                        } else {
                            print("Waiting for user confirmation to start \(appState.beeSceneState.step)")
                            Task { @MainActor in
                                try await performPrepareInteractionInForrestFullSpaceStep()
                            }
                        }
                    }
                case .neutralIdle:
                    if type(of: appState.currentImmersionStyle) != MixedImmersionStyle.self {
                        appState.currentImmersionStyle = .mixed
                    }
                    print("Restart experience?")
                }

            } catch {
                let formattedErrorMessage = "Error in ImmersiveBeeView RealityView's update func: " + String(describing: error)
                print(formattedErrorMessage)
                errorMessage = formattedErrorMessage

                if let errorView = loadCatchError(from: attachments) {
                    content.add(errorView)
                }
            }
        } placeholder: {
            ProgressView()
        }
        attachments: {
            Attachment(id: "dialogue_box") {
                DialogueView(
                    step: appState.beeSceneState.step,
                    onConfirmationButtonClicked: {
                        appState.beeSceneState.isCurrentStepConfirmed = true
                    },
                    onNextStepButtonClicked: {
                        appState.beeSceneState.step.next()

                        if appState.beeSceneState.step.isConfirmationRequiredWithThisStep() {
                            // If it require a confirmation, reset to false and wait for the confirmation button in dialogue view
                            appState.beeSceneState.isCurrentStepConfirmed = false

                            // For fast development
                            if AppState.byPassConfirmationStep == true {
                                appState.beeSceneState.isCurrentStepConfirmed = true
                            }
                        }
                    },
                    onCancelButtonClicked: {
                        appState.beeSceneState.step.previous()
                    }
                )
            }

            Attachment(id: "error_view") {
                VStack {
                    Text("Error: \(errorMessage)").font(.largeTitle)
                }
                .frame(maxWidth: 1200)
                .padding(32)
                .glassBackgroundEffect()
            }
        }
        // .spatialTapGestureToEntity(appState.beeSceneState.bee, onSpatialTapRelease: { spatialTagGesture in
        //     // not used and conflicting with hand collision system
        //     print("Bzzzzzz!")
        // })
        // .spatialTapGestureToEntity(appState.beeSceneState.daffodilFlowerPot, onSpatialTapRelease: { spatialTagGesture in
        //     print("Touch daffodilFlowerPot")
        // })
        // .spatialTapGestureToEntity(appState.beeSceneState.waterBottle, onSpatialTapRelease: { spatialTagGesture in
        //     print("Touch Water_Bottle")
        // })

        .onReceive(NotificationCenter.default.publisher(for: .exitWordDetected)) { _ in
            Task {
                @MainActor in await dismissImmersiveSpace()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exitGestureDetected)) { _ in
            Task { @MainActor in await dismissImmersiveSpace() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .targetReached)) { notification in
            if let name = notification.targetReachedEntityName {
                print("🎯 Target reached by entity: \(name)")
            }
            if let position = notification.targetReachedTargetPosition {
                print("📍 At position: \(position)")
            }

            // TODO: trigger visual feedback "congratualition, we can now pass to the next step if you are ready..."
            appState.beeSceneState.isWaterBottlePlacedOnHalo = true
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveBeeView()
        .environment(AppState())
}
