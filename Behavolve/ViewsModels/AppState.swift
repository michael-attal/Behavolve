//
//  AppState.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import ARKit
import AVFoundation
import Foundation
import OpenAI
import RealityKit
import Speech
import SwiftUI

enum ImmersiveViewAvailable: String {
    case none
    case bee
    case snake

    static func getAllImmersiveViews() -> [ImmersiveViewAvailable] {
        return [.bee, .snake]
    }
}

/// Maintains app-wide state
@MainActor
@Observable
class AppState {
    static let isDevelopmentMode = false
    static let fastDialogue = true
    static let byPassConfirmationStep = false
    static let ChatGptAudioEnabled = true
    static let ChatGptAudioEnabledForOfflineText = false

    let beeSceneState = BeeSceneState()

    var openAI = OpenAI(configuration: OpenAI.Configuration(token: YOUR_OPENAI_TOKEN_HERE, organizationIdentifier: YOUR_OPENAI_ORGANIZATION_ID_HERE, timeoutInterval: 86400.0))

    let MenuWindowID = "MenuWindow"
    let ConversationWindowID = "ConversationWindow"
    let immersiveSpaceID = "ImmersiveSpace"

    var audioConversation = AudioConversation()
    var audioEngine: AVAudioEngine?
    var speechRecognizer: SFSpeechRecognizer?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    var audioFile: AVAudioFile?
    var audioFileURL: URL?
    var streamingTask: Task<Void, Never>?

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    var exitWordDetected = false

    var currentImmersionStyle: ImmersionStyle = .mixed
    var immersiveSpaceState = ImmersiveSpaceState.closed

    var currentImmersiveView: ImmersiveViewAvailable = .none

    var handAnchorEntities: [AnchorEntity] = []
    var handTracking = HandTrackingProvider()
    var planeDetection = PlaneDetectionProvider(alignments: [.horizontal]) // Used to detect ceil
    var wolrdTracking = WorldTrackingProvider()

    func didLeaveImmersiveSpace() {
        arkitSession.stop()
    }

    // MARK: - ARKit state

    var arkitSession = ARKitSession()
    var providersStoppedWithError = false
    var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    var handTrackingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    var sceneReconstruction = SceneReconstructionProvider()
    var isFirstChunkReady = false

    var allRequiredAuthorizationsAreGranted: Bool {
        worldSensingAuthorizationStatus == .allowed && handTrackingAuthorizationStatus == .allowed
    }

    var allRequiredProvidersAreSupported: Bool {
        WorldTrackingProvider.isSupported && HandTrackingProvider.isSupported && PlaneDetectionProvider.isSupported
    }

    var canEnterImmersiveSpace: Bool {
        allRequiredAuthorizationsAreGranted && allRequiredProvidersAreSupported
    }

    func requestHandTrackingAuthorization() async {
        let authorizationResult = await arkitSession.requestAuthorization(for: [.handTracking])
        handTrackingAuthorizationStatus = authorizationResult[.handTracking]!
    }

    func queryHandTrackingAuthorization() async {
        let authorizationResult = await arkitSession.queryAuthorization(for: [.handTracking])
        handTrackingAuthorizationStatus = authorizationResult[.handTracking]!
    }

    func requestWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession.requestAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }

    func queryWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession.queryAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }

    func requestSpeechAndMicAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        let audioStatus = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        return (speechStatus == .authorized) && audioStatus
    }

    func monitorSessionEvents() async {
        for await event in arkitSession.events {
            switch event {
            case .dataProviderStateChanged(_, let newState, let error):
                switch newState {
                case .initialized:
                    break
                case .running:
                    break
                case .paused:
                    break
                case .stopped:
                    if let error {
                        print("An error occurred: \(error)")
                        providersStoppedWithError = true
                    }
                @unknown default:
                    break
                }
            case .authorizationChanged(let type, let status):
                print("Authorization type \(type) changed to \(status)")
                if type == .worldSensing {
                    worldSensingAuthorizationStatus = status
                } else if type == .handTracking {
                    handTrackingAuthorizationStatus = status
                }
            default:
                print("An unknown event occured \(event)")
            }
        }
    }

    static let therapistInstructions = """
    You are Lucie, an AI-powered Cognitive Behavioral therapist. Your role is to accompany the user throughout their therapeutic journey in the Behavolve mixed reality application, helping them to understand, manage, and gradually overcome their phobias (especially fear of bees, for now).

    Your objectives:
    - Guide the user step by step, adapting your guidance to their current progress (“step”) and emotional state.
    - Respond to user questions in real time, always referencing their current context in the application.
    - Use a kind, encouraging and pedagogical tone at all times.
    - Provide explanations about CBT, exposure therapy, and bee behavior, as needed.
    - Encourage relaxation and emotional regulation techniques when appropriate.

    Instructions:
    - At each interaction, you will receive:
       - The user's current **step** in the scenario.
       - A **presentation** text describing this step.
       - Potentially, a list of **detailed instructions** for the step (e.g., actions to perform, goals).
       - The **runtime state** of the scene (e.g., whether the water bottle is placed, if the bee has flown away, etc.).

    - Always **adapt your answers** :
       - Guide the user according to the current step, referencing the presentation and instructions provided.
       - Answer questions clearly and succinctly, making sure to explain the “why” behind each recommendation.
       - If the user seems anxious or hesitant, encourage calm and propose concrete relaxation techniques.
       - Remind the user that they are always in control and can exit the scenario at any time.

    General information:
    Behavolve is a mixed reality CBT app for the Apple Vision Pro. It allows users to confront their fears in a controlled, progressive and safe way, with real-time support from you, Lucie.

    Never break character: always speak as a supportive therapist.  
    If the user asks technical questions about the app, reply in simple language and relate it to therapy if possible.
    """

    static let behavolveAppDescription = """
    Behavolve is an innovative open-source application dedicated to Cognitive Behavioral Therapy (CBT) in mixed reality (XR), primarily designed for Apple Vision Pro.

    Mission:
    - Behavolve helps individuals gradually overcome specific phobias and fears (initially, the fear of bees) by exposing them to realistic virtual simulations in a safe and controlled environment.
    - The application supports users through immersive scenarios, each tailored to a particular phobia (e.g., bees, heights, sea, blood tests, snakes).

    Key Features:
    - Immersive environments using advanced graphics and spatialized audio, allowing exposure therapy either in the user’s own space (augmented reality) or in fully virtual environments (e.g., a forest).
    - Progressive exposure: the level of challenge is adjusted according to the user’s comfort and progress.
    - Real-time AI assistance: an intelligent avatar (the therapist) provides guidance, reassurance, CBT psychoeducation, and feedback tailored to each scenario and the user's reactions.
    - Advanced hand tracking and scene understanding, leveraging Apple Vision Pro capabilities for interaction and safety.
    - All content and assets comply with ethical and therapeutic standards.

    Development Plan:
    - Year 1: Focus on the bee scenario, basic mechanisms, first simulations, and user feedback.
    - Year 2: Expansion to new scenarios (jungle/snakes, heights, sea, blood draws), addition of haptic feedback, and advanced AI assistance for more personalized guidance.

    Therapeutic Goals:
    - Demystify phobic stimuli by making them predictable and manageable.
    - Teach users practical coping and relaxation techniques for use both in-app and in real life.
    - Promote autonomy, self-confidence, and emotional regulation.

    Behavolve’s Approach:
    - Combines mixed reality technology with evidence-based CBT principles for an accessible, interactive, and effective therapeutic process.
    - The AI avatar adapts its support in real time, based on user actions and context, to ensure a personalized and empowering experience.

    Behavolve is open-source and intended as a complement to professional therapeutic follow-up. The app’s documentation provides educational resources on CBT and on how to use Behavolve safely and effectively.
    """

    static let beeScenarioStepList = """
    The scenario for the Bee module in Behavolve is structured in the following ordered steps. Each step is described with its technical name, a user-friendly label, and a summary of what the user experiences at this stage.

    1. neutralIdle
       Label: "Welcome & Orientation"
       Description: "The user is welcomed to Behavolve. Safety instructions are explained. The user learns they can exit the experience at any time by making a fist gesture or saying 'EXIT.' The bee will be introduced in a protective virtual cube in the room."

    2. neutralExplanation
       Label: "Bee Behavior Explanation"
       Description: "The AI explains how bees behave in their natural environment: their peaceful routines, their lack of interest in humans, and their predictable behaviors. The user can observe without risk, and is reassured about safety and control."

    3. neutralBeeGatheringNectarFromFlowers
       Label: "Bee Gathering Nectar"
       Description: "The user watches the bee collect nectar from flowers, following a natural routine. The bee keeps a safe distance from the user. This step demonstrates the bee's focus on flowers, not on humans."

    4. interactionInOwnEnvironment
       Label: "Water Bottle Challenge"
       Description: "First interactive exposure: the user is challenged to pick up a blue water bottle placed near the bee and set it on a target, all while maintaining calm, slow movements. The bee will move away if the user gets too close."

    5. interactionInForrestFullSpace
       Label: "Picnic Challenge in the Forest"
       Description: "The final challenge. The user experiences a virtual picnic in a peaceful forest. A bee approaches the user's food. The user must stay calm and can use gentle hand movements to guide the bee away or simply remain relaxed until the bee leaves on its own."

    After the last step, the experience can loop or return to the start.

    During the scenario, for each step, the following context may also be given:
    - The current step name
    - A presentation text for the step
    - Detailed instructions for the current challenge (if any)
    - The following state variables:
        - isCurrentStepConfirmed (Bool): Whether the current step has been confirmed by the user
        - isWaterBottlePlacedOnHalo (Bool): Whether the user has successfully placed the water bottle
        - hasBeeFlownAway (Bool): Whether the bee has left the scene
    - You should use all this information to respond with empathy, guidance, and contextually relevant advice.

    Your role is to act as a cognitive-behavioral therapist, guide the user step by step, answer their questions, reassure them, and help them progress in managing their phobia of bees.
    """
}
