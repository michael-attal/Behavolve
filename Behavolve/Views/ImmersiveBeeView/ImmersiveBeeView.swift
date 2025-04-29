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

    var body: some View {
        RealityView { content, attachments in
            do {
                if let immersiveContentEntity = try? await Entity(named: "Scenes/Bee Scene", in: realityKitContentBundle) {
                    let flower = try loadFlower(from: immersiveContentEntity, withName: "Flowers", animatedEntityNamed: "Daffodil")
                    let bee = try await loadBee(from: immersiveContentEntity)
                    let beehive = try await loadBeehive(from: immersiveContentEntity)
                    let therapist = try loadTherapist(from: immersiveContentEntity)
                    let dialogue = try loadDialogue(from: attachments)

                    therapist.addChild(dialogue)
                    immersiveContentEntity.addChild(flower)

                    // Uncomment to have some nightmares
                    // for i in 1 ... 100 {
                    //     let clonedBee = bee.clone(recursive: true)
                    //     clonedBee.position.x += Float(i) / 100.0
                    //     let daffodilFlowerPot = flower
                   
                    //     var nectarSourcesPositions: [SIMD3<Float>] = []
                    //     for i in 1 ... 5 {
                    //         if let entity = daffodilFlowerPot.findEntity(named: "Nectar_spot_\(i)") {
                    //             nectarSourcesPositions.append(entity.position(relativeTo: nil))
                    //         }
                    //     }
                   
                    //     let nectarSources = nectarSourcesPositions.enumerated().map { index, position in
                    //         NectarSource(
                    //             position: position,
                    //             stock: 100,
                    //             reloadDuration: TimeInterval(Int.random(in: 20 ... 40))
                    //         )
                    //     }
                   
                    //     var depotSitePosition = beehive.position(relativeTo: nil)
                    //     depotSitePosition.y += 0.1
                   
                    //     clonedBee.components.set(
                    //         NectarGatheringComponent(
                    //             nectarDepotSitePosition: depotSitePosition,
                    //             nectarSources: nectarSources,
                    //             speed: Float(Int.random(in: 1 ... 100)) / 100.0
                    //         )
                    //     )
                   
                    //     immersiveContentEntity.addChild(clonedBee)
                    // }
                    content.add(immersiveContentEntity)

                    trackPlaneDetection()

                    appState.beeSceneState.daffodilFlowerPot = flower
                    appState.beeSceneState.therapist = therapist
                    appState.beeSceneState.beehive = beehive
                    appState.beeSceneState.bee = bee
                }
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
                    if appState.beeSceneState.isCurrentStepConfirmed == true {
                        performInteractionInOwnEnvironmentStep()
                    } else {
                        print("Waiting for user confirmation to start \(appState.beeSceneState.step)")
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
        .spatialTapGestureToEntity(appState.beeSceneState.therapist, onSpatialTapRelease: { spatialTagGesture in
            print("Hello!")
        })
        .spatialTapGestureToEntity(appState.beeSceneState.bee, onSpatialTapRelease: { spatialTagGesture in
            print("Bzzzzzz!")
        })
        .spatialTapGestureToEntity(appState.beeSceneState.daffodilFlowerPot, onSpatialTapRelease: { spatialTagGesture in
            print("Touch daffodilFlowerPot")
        })
        .onReceive(NotificationCenter.default.publisher(for: .exitGestureDetected)) { _ in
            Task { @MainActor in await dismissImmersiveSpace() }
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveBeeView()
        .environment(AppState())
}
