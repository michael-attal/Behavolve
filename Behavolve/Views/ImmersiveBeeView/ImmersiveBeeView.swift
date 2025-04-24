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
                    performInteractionInOwnEnvironmentStep()
                case .interactionInForrestFullSpace:
                    performInteractionInForrestFullSpaceStep()
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
                DialogueView {
                    appState.beeSceneState.step.next()
                } onCancelButtonClicked: {
                    appState.beeSceneState.step.previous()
                }
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
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveBeeView()
        .environment(AppState())
}
