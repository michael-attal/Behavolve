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
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

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
                // Add brightness in the app. I don’t know why the model is so dark in mixed space, even though there is enough light in the room.
                addDefaultLighting(to: immersiveContentEntity)
                #endif

                // Add a plane ground to not let the watter bottle go beyond the scene in simulator // Also need it in real device since scene mesh reconstruction is not by made default in app
                let planeForGroundCollision = loadPlaneForGroundCollision()
                immersiveContentEntity.addChild(planeForGroundCollision)

                let therapist = try await loadTherapist(at: appState.beeSceneState.therapistInitialPosition)
                let dialogue = try loadDialogue(from: attachments)
                let warnings = try loadWarnings(from: attachments)
                therapist.addChild(dialogue)
                therapist.addChild(warnings)
                immersiveContentEntity.addChild(therapist)

                let beehive = try await loadBeehive(at: appState.beeSceneState.beehiveInitialPosition)
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
                appState.beeSceneState.warnings = warnings
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

                switch appState.beeSceneState.step.type {
                case .neutralIdle:
                    if appState.beeSceneState.step.isPreviousStep
                        && appState.beeSceneState.step.isCleaned == false
                    {
                        performCleanNeutralExplanationStep() // Clean if we step back
                        appState.beeSceneState.step.isCleaned = true
                    }
                    if appState.beeSceneState.step.isPlaced == false {
                        performNeutralIdleStep()
                        appState.beeSceneState.step.isPlaced = true
                    }
                case .neutralExplanation:
                    if appState.beeSceneState.step.isPreviousStep
                        && appState.beeSceneState.step.isCleaned == false
                    {
                        performCleanNeutralBeeGatheringNectarFromFlowersStep() // Clean if we step back
                        appState.beeSceneState.step.isCleaned = true
                    }
                    if appState.beeSceneState.step.isPlaced == false {
                        performNeutralExplanationStep()
                        appState.beeSceneState.step.isPlaced = true
                    }
                case .neutralBeeGatheringNectarFromFlowers:
                    if appState.beeSceneState.step.isPreviousStep
                        && appState.beeSceneState.step.isCleaned == false
                    {
                        performCleanInteractionInOwnEnvironmentStep() // Clean if we step back
                        appState.beeSceneState.step.isCleaned = true
                    }
                    if appState.beeSceneState.step.isPlaced == false {
                        performNeutralBeeGatheringNectarFromFlowersStep()
                        appState.beeSceneState.step.isPlaced = true
                    }
                case .interactionInOwnEnvironment:
                    if appState.beeSceneState.step.isPreviousStep
                        && appState.beeSceneState.step.isCleaned == false
                    {
                        performCleanInteractionInForrestFullSpaceStep() // Clean if we step back
                        appState.beeSceneState.step.isCleaned = true
                    }
                    if appState.beeSceneState.isWaterBottlePlacedOnHalo {
                        Task { @MainActor in
                            try await performFinishedInteractionInOwnEnvironmentStep()
                        }
                    } else {
                        if appState.beeSceneState.step.isCurrentStepConfirmed {
                            if appState.beeSceneState.step.isPlaced == false {
                                performInteractionInOwnEnvironmentStep()
                                appState.beeSceneState.step.isPlaced = true
                            }
                        } else {
                            Task { @MainActor in
                                if appState.beeSceneState.step.isLoaded == false {
                                    try await performPrepareInteractionInOwnEnvironmentStep()
                                    appState.beeSceneState.step.isLoaded = true
                                }
                            }
                        }
                    }
                case .interactionInForrestFullSpace:
                    if appState.beeSceneState.step.isPreviousStep
                        && appState.beeSceneState.step.isCleaned == false
                    {
                        appState.beeSceneState.step.isCleaned = true
                    }
                    if appState.beeSceneState.hasBeeFlownAway {
                        Task { @MainActor in
                            try await performFinishedInteractionInForrestFullSpaceStep()
                        }
                    } else {
                        if appState.beeSceneState.step.isCurrentStepConfirmed {
                            if appState.beeSceneState.step.isPlaced == false {
                                performInteractionInForrestFullSpaceStep()
                                appState.beeSceneState.step.isPlaced = true
                            }
                        } else {
                            print("Waiting for user confirmation to start \(appState.beeSceneState.step)")
                            Task { @MainActor in
                                if appState.beeSceneState.step.isLoaded == false {
                                    try await performPrepareInteractionInForrestFullSpaceStep()
                                    appState.beeSceneState.step.isLoaded = true
                                }
                            }
                        }
                    }
                case .end:
                    if appState.beeSceneState.step.isPlaced == false {
                        performEndStep()
                        appState.beeSceneState.step.isPlaced = true
                    }
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
                        appState.beeSceneState.step.isCurrentStepConfirmed = true
                    },
                    onNextStepButtonClicked: {
                        appState.beeSceneState.step.next()
                        if appState.beeSceneState.step.type == .end {
                            // Open post assessment when therapy is finished
                            Task { @MainActor in
                                performCleanEndStep()
                                openWindow(id: appState.BeeScenePostSessionAssessmentWindowID)
                                appState.beeSceneState.isPostSessionAssessmentFormWindowOpened = true
                            }
                        }
                    },
                    onCancelButtonClicked: {
                        if appState.beeSceneState.step.type == .neutralIdle || appState.beeSceneState.step.type == .end {
                            // Back to menu
                            openWindow(id: appState.MenuWindowID)
                            Task { @MainActor in
                                dismissWindow(id: appState.ConversationWindowID)
                                if appState.beeSceneState.isPostSessionAssessmentFormWindowOpened {
                                    dismissWindow(id: appState.BeeScenePostSessionAssessmentWindowID)
                                }
                                await dismissImmersiveSpace()
                            }
                        } else {
                            appState.beeSceneState.step.previous()
                        }
                    }
                )
            }

            Attachment(id: "warnings_box") {
                WarningsView(warningsText: appState.beeSceneState.warningsText,
                             warningsTextID: appState.beeSceneState.warningsTextID)
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
            if (appState.beeSceneState.step.type == .interactionInOwnEnvironment || appState.beeSceneState.step.type == .interactionInForrestFullSpace) && appState.beeSceneState.step.isCurrentStepConfirmed == true {
                print("🤚 Abrupt gesture detected")
                appState.beeSceneState.warningsText = "Oops! An abrupt gesture was detected – Move your hands gently so the bee doesn’t get scared."
                appState.beeSceneState.warningsTextID = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .abruptHeadMotionDetected)) { _ in
            if (appState.beeSceneState.step.type == .interactionInOwnEnvironment || appState.beeSceneState.step.type == .interactionInForrestFullSpace) && appState.beeSceneState.step.isCurrentStepConfirmed == true {
                print("😱 Abrupt head/body motion detected")
                appState.beeSceneState.warningsText = "Oops! An abrupt head/body motion was detected – try to move gently so the bee doesn’t get scared."
                appState.beeSceneState.warningsTextID = UUID()
            }
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
                if appState.beeSceneState.isPalmUpGestureTested == false && appState.beeSceneState.step.type == .neutralExplanation {
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
        .onReceive(NotificationCenter.default.publisher(for: .entityTargetDistanceToUserReached)) { notification in
            if let name = notification.entityName, let position = notification.entityPosition, let dist = notification.targetDistanceToUser {
                print("➡ Distance from entity: \(name) to user has reached target distance (\(dist)) -  Entity position: \(position)")
                appState.beeSceneState.hasBeeFlownAway = true
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
        FleeStateSystem.registerSystem()

        TargetReachedComponent.registerComponent()
        TargetReachedSystem.registerSystem()

        EntityProximityComponent.registerComponent()
        EntityProximitySystem.registerSystem()

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
        // PalmOpenGestureSystem.registerSystem()

        #endif
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveBeeView()
        .environment(AppState())
}
