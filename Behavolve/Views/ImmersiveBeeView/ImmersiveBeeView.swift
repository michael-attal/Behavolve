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
                            // TODO: Fix concurrency problem
                            if appState.beeSceneState.step == .interactionInOwnEnvironment {
                                appState.beeSceneState.step.next()
                                try? await Task.sleep(for: .milliseconds(500))
                                var newPosition = appState.beeSceneState.halo.position(relativeTo: nil)
                                newPosition.y += 0.1
                                do {
                                    // TODO: FIX particles not displaying
                                    let particles = try await loadParticles()
                                }  catch {
                                    print(error)
                                    throw error
                                }
                                appState.beeSceneState.waterBottle.position = newPosition
                                print("Particule loaded and next step charged!")
                            }
                        }
                    } else {
                        if appState.beeSceneState.isCurrentStepConfirmed == true {
                            performInteractionInOwnEnvironmentStep()
                        } else {
                            print("Waiting for user confirmation to start \(appState.beeSceneState.step)")
                            // Load the Water bottles in advances
                            if appState.beeSceneState.waterBottle.name != "Water_Bottle" { // Avoid loading multiple times the water bottle (not the best way to handle concurrency)
                                Task { @MainActor in
                                    do {
                                        let waterBottle = try await loadWaterBottle()
                                        appState.beeSceneState.waterBottle = waterBottle
                                        appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(waterBottle)
                                        // TODO: Refactor Halo: enabled it in performInteractionInOwnEnvironmentStep(-
                                        let halo = await RealityKitHelper.createHaloEntity(radius: 0.1, depth: 0.1, activateTransparency: true, minimumOpacity: 0.5, lowestPercentageEmissive: 0.1, onlyLoadHaloModelFromRealityKitContentBundle: true)
                                        // halo.position.x = flowersPosition.x - 0.5 // TODO: Place it on the first table detected or next to the flowers position.
                                        halo.position.z = -1.6
                                        halo.position.y = 0.7
                                        halo.name = "Halo"
                                        halo.isEnabled = false
                                        appState.beeSceneState.halo = halo
                                        appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(halo)
                                    } catch {
                                        print(error)
                                        throw error
                                    }
                                }
                            }
                        }
                    }
                case .interactionInForrestFullSpace:
                    if appState.beeSceneState.isCurrentStepConfirmed == true {
                        performInteractionInForrestFullSpaceStep()
                    } else {
                        print("Waiting for user confirmation to start \(appState.beeSceneState.step)")
                    }
                case .neutralIdle:
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
                    onConfirmationButtonClicked: {
                        appState.beeSceneState.isCurrentStepConfirmed = true
                    },
                    onNextStepButtonClicked: {
                        appState.beeSceneState.step.next()

                        if appState.beeSceneState.step.isConfirmationRequiredWithThisStep(), AppState.isDevelopmentMode == false {
                            // If it require a confirmation, reset to false and wait for the confirmation button in dialogue view - Refactor later
                            appState.beeSceneState.isCurrentStepConfirmed = false
                        } else {
                            appState.beeSceneState.isCurrentStepConfirmed = true
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
