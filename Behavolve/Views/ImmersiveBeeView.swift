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
    @Environment(AppModel.self) private var appModel

    var body: some View {
        RealityView { content, attachments in
            do {
                if let immersiveContentEntity = try? await Entity(named: "Scenes/Bee Scene", in: realityKitContentBundle) {
                    guard let bee = immersiveContentEntity.findEntity(named: "Flying_Bee") else {
                        throw ImmersiveBeeViewError.entityError(message: "Could not find Flying_Bee entity")
                    }

                    bee.setGroundingShadow(castsShadow: true)

                    bee.scale = [0.001, 0.001, 0.001]
                    bee.position = [0, 1.5, -1.5]

                    guard let beeAnimResource = bee.availableAnimations.first else { return }
                    let beeFlyingAnim = try! AnimationResource.generate(with: beeAnimResource.repeat().definition)

                    bee.playAnimation(beeFlyingAnim)

                    guard let therapist = immersiveContentEntity.findEntity(named: "Therapist") else {
                        throw ImmersiveBeeViewError.entityError(message: "Could not find Therapist entity")
                    }
                    therapist.setGroundingShadow(castsShadow: true)
                    guard let therapistAnimResource = therapist.availableAnimations.first else { return }
                    guard let therapistAnim = try? AnimationResource.generate(with: therapistAnimResource.repeat().definition) else {
                        throw ImmersiveBeeViewError.entityError(message: "Could not find Therapist animation")
                    }
                    therapist.scale = [0.01, 0.01, 0.01]
                    therapist.position = [-0.8, 0, -2]
                    let therapistControllerAnimation = therapist.playAnimation(
                        therapistAnim,
                        transitionDuration: 0.3,
                        blendLayerOffset: 0,
                        separateAnimatedValue: true,
                        startsPaused: true
                    )
                    therapistControllerAnimation.speed = 0.5

                    guard let dialogue = attachments.entity(for: "dialogue_box") else { throw ImmersiveBeeViewError.entityError(message: "Can't find dialogue_box") }
                    dialogue.scale = SIMD3(100, 100, 100)
                    dialogue.position = SIMD3<Float>(-10, 220, 0)
                    dialogue.components.set(LookAtTargetComponent(target: .device) { entityPosition, actualTargetPosition in
                        actualTargetPosition.with(\.y, entityPosition.y)
                    })
                    therapist.components.set(LookAtTargetComponent(target: .device) { entityPosition, actualTargetPosition in
                        actualTargetPosition.with(\.y, entityPosition.y)
                    })
                    therapist.addChild(dialogue)

                    content.add(immersiveContentEntity)

                    #if targetEnvironment(simulator)
                    print("In simulator, plane detection & hand tracking disabled!")
                    #else
                    Task {
                        try await appState.arkitSession.run([appState.planeDetection])

                        for await update in appState.planeDetection.anchorUpdates {
                            if update.anchor.classification == .ceiling {
                                print("ceiling detected!")
                            }
                        }
                    }
                    Task {
                        print("Start Custom gesture if we want to")
                    }
                    #endif

                    appModel.beeSceneState.therapist = therapist
                    appModel.beeSceneState.bee = bee
                }
            } catch {
                print("Error in ImmersiveBeeView RealityView's make func: \(error)")
            }
        } update: { _, _ in
            print(appModel.beeSceneState.step)
        } placeholder: {
            ProgressView()
        }
        attachments: {
            Attachment(id: "dialogue_box") {
                DialogueView {
                    appModel.beeSceneState.step.next()
                } onCancelButtonClicked: {
                    appModel.beeSceneState.step.previous()
                }
            }
        }
        .spatialTapGestureToEntity(appModel.beeSceneState.therapist, onSpatialTapRelease: { spatialTagGesture in
            print("Hello!")
        })
        .spatialTapGestureToEntity(appModel.beeSceneState.bee, onSpatialTapRelease: { spatialTagGesture in
            print("Bzzzzzz!")
        })
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveBeeView()
        .environment(AppModel())
}
