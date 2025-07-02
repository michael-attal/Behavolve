//
//  ImmersiveView.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import ARKit
import RealityKit
import RealityKitContent
import SwiftUI

enum ImmersiveBeeViewError: Error {
    case entityError(message: String)
}

struct ImmersiveBeeView: View {
    @Environment(AppState.self) var appState
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var errorMessage: String?
    // @State var spatialTrackingSession = SpatialTrackingSession()

    var body: some View {
        RealityView { content, attachments in
            do {
                initRequiredSystems()

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
                let calmMonitorEntity = loadCalmMotionMonitorHeadset()
                loadUserHands(content: &content)
                loadSubscribtionToManipulationEvents(content: &content)

                guard let immersiveContentEntity = try? await Entity(named: "Scenes/Bee Scene", in: realityKitContentBundle) else {
                    throw ImmersiveBeeViewError.entityError(message: "Could not load Bee Scene (where all content will be placed)")
                }

                #if !targetEnvironment(simulator)
                if AppState.showDebugMeshSceneReconstruction {
                    let debugRoot = Entity()
                    debugRoot.name = "DebugMeshRoot"
                    AppState.debugMeshRoot = debugRoot
                    content.add(debugRoot)
                }
                #endif

                // Add a plane ground to not let the watter bottle go beyond the scene in simulator // Also need it in real device since scene mesh reconstruction is not by made default in app
                let planeForGroundCollision = loadPlaneForGroundCollision()
                RealityKitHelper.updateCollisionFilter(
                    for: planeForGroundCollision,
                    groupType: .beehive,
                    maskTypes: [.all],
                    subtracting: .bee
                ) // Avoid collision with bee (needed when she fly away when we are are to close)
                #if !targetEnvironment(simulator)
                planeForGroundCollision.position.y += 0.12 // Not perfectly at 0 in my appartment
                #endif
                immersiveContentEntity.addChild(planeForGroundCollision)

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

                immersiveContentEntity.addChild(calmMonitorEntity)

                content.add(immersiveContentEntity)

                appState.calmMonitorEntity = calmMonitorEntity
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
            print("✊ Exit gesture detected")
            Task { @MainActor in await dismissImmersiveSpace() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .targetReached)) { notification in
            if let name = notification.targetReachedEntityName {
                print("🎯 Target reached by entity: \(name)")
            }
            if let position = notification.targetReachedTargetPosition {
                print("📍 At position: \(position)")
            }

            appState.beeSceneState.isWaterBottlePlacedOnHalo = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .abruptGestureDetected)) { _ in
            print("🤚 Abrupt gesture detected")
        }
        .onReceive(NotificationCenter.default.publisher(for: .abruptHeadMotionDetected)) { _ in
            print("😱 Abrupt head/body motion detected")
        }
        // .onReceive(NotificationCenter.default.publisher(for: .thumbUpGestureDetected)) { notification in
        //     if let position = notification.thumbUpThumbTipPosition {
        //         print("👍 Thumb Up detected at position: \(position)")
        //     } else {
        //         print("👍 Thumb Up detected (no position available)")
        //     }
        // }
        .onReceive(NotificationCenter.default.publisher(for: .palmOpenGestureDetected)) { notification in
            if let position = notification.palmOpenPalmCenterPosition {
                print("🖐️ Palm open at: \(position)")
                // TODO: For testing, remove later:
                if appState.beeSceneState.isPalmUpGestureTested == false && appState.beeSceneState.step == .neutralExplanation {
                    appState.beeSceneState.isPalmUpGestureTested = true
                    appState.beeSceneState.bee.components.set(
                        MoveToComponent(destination: position + [0, 0.1, -0.05],
                                        speed: 0.5,
                                        epsilon: 0.01,
                                        strategy: .direct)
                    )
                    appState.beeSceneState.bee.components.set(LookAtTargetComponent(target: .world(LookAtTargetSystem.shared.devicePoseSafe.value.translation)))
                }
            }
        }
    }

    func initRequiredSystems() {
        LookAtTargetComponent.registerComponent()
        LookAtTargetSystem.registerSystem()

        MoveToComponent.registerComponent()
        MovementSystem.registerSystem()

        OscillationComponent.registerComponent()
        OscillationSystem.registerSystem()

        SteeringComponent.registerComponent()
        SteeringSystem.registerSystem()

        NectarDepositComponent.registerComponent()
        NectarDepositSystem.registerSystem()

        NectarGatheringComponent.registerComponent()
        NectarGatheringSystem.registerSystem()

        UserProximityComponent.registerComponent()
        UserProximitySystem.registerSystem()

        CalmMotionComponent.registerComponent()
        CalmMotionSystem.registerSystem()

        FleeStateComponent.registerComponent()

        TargetReachedSystem.registerSystem()
        TargetReachedComponent.registerComponent()

        #if !targetEnvironment(simulator)
        if AppState.alwaysUseDirectMovement == false {
            PathfindingSystem.registerSystem()
        }

        HandComponent.registerComponent()
        HandInputSystem.registerSystem()

        HandProximityComponent.registerComponent()
        HandProximitySystem.registerSystem()

        HandCollisionComponent.registerComponent()
        HandCollisionSystem.registerSystem()

        ExitGestureComponent.registerComponent()
        ExitGestureSystem.registerSystem()

        GentleGestureComponent.registerComponent()
        GentleGestureSystem.registerSystem()

        // ThumbUpGestureComponent.registerComponent()
        // ThumbUpGestureSystem.registerSystem()

        PalmOpenGestureComponent.registerComponent()
        PalmOpenGestureSystem.registerSystem()

        #endif
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveBeeView()
        .environment(AppState())
}
