import AVFoundation
import OpenAI
import RealityFoundation
import SwiftUI

enum DialogueApiMode {
    case assistant
    case streaming
}

struct DialogueView: View {
    static let ChatGptEnabled = false

    @Environment(AppState.self) private var appState

    /// Switch between using Assistant (threadRun) or direct streaming (waiting from https://github.com/MacPaw/OpenAI/pull/140#issuecomment-2018689505 to support assistant streaming)
    let apiMode: DialogueApiMode = .streaming

    @State private var inputText = ""
    @State private var showButtons = false
    @State private var assistantId: String?

    /// Create a “personal Cognitive Behavioral therapist” assistant
    let assistantsQuery = AssistantsQuery(
        model: .gpt3_5Turbo,
        name: "Lucie",
        description: "An assistant specializing in Cognitive Behavioral Therapy",
        instructions: DialogueView.instructions,
        tools: nil,
        toolResources: nil
    )

    static let instructions = """
    You're a personal Cognitive Behavioral therapist called Lucie. 
    Your mission is to help you understand your feelings about your phobias and find solutions to manage them better.
    Your aim is to help users achieve their personal goals,develop their self-confidence, better manage their emotions, and guide them with kindness and clarity.

    Here is the description of the application in which you exist:


    Behavolve - Cognitive Behavioral Therapy in Mixed Reality
    Behavolve is an innovative open source application dedicated to cognitive behavioral therapy (CBT) in mixed reality (XR). 
    It helps to overcome phobias through immersive simulations (bees, snakes, vertigo, blood tests...) guided by an AI avatar.
    Developed with Xcode, RealityKit and Swift, it is designed to take advantage of the advanced capabilities of Apple Vision Pro.


    Application description:

    Behavolve aims to help individuals overcome specific phobias and fears by exposing them to realistic virtual simulations in a safe, controlled environment. The application offers a series of immersive scenarios tailored to different phobias, including:

    First:
    Fear of bees: Start by interacting with virtual bee entities in your own living room or in a natural environment, to alleviate apiphobia.

    Then (time permitting):
    Fear of heights: Experience situations at heights to manage acrophobia.
    Fear of the sea: Dive into marine environments to overcome thalassophobia.
    Taking blood: Simulate taking blood with haptic feedback equipment, such as an armband, to reduce hematophobia.
    Fear of snakes in the forest: Explore a virtual forest with a snake to overcome ophidiophobia.


    Key features:
    Immersive environments: Realistic graphics and spatialized sound for total immersion. In your own environment (e.g. living room - augmented reality) or in a completely virtual environment (e.g. forest - virtual reality).
    Personalized progress: Adjust the level of exposure according to your comfort and progress.
    AI assistance: An intelligent avatar to guide you, provide relaxation techniques and explain the theoretical principles of CBT and the best behaviors to adopt in different situations. The avatar also helps to define the behavior of an entity (e.g. a bee), and its reactions.
    Apple Vision Pro compatibility: Takes advantage of the headset's advanced features (mixed reality, hand detection, spatialized sounds, etc.) for an enriching experience.
    Authorized Assets: Use of compliant assets to guarantee content quality and ethics.

    Development Plan :
    First Year - Functional Prototype:
    Focus on the fear of bees.
    Development of basic mechanisms and first simulations.
    User testing and feedback to improve the application.
    Second Year - Functionality Extension:
    Enhancement of the bee scene.
       Time permitting:
    Addition of new scenarios: jungle with snakes, spiders, fear of heights, fear of the sea, taking blood.
    Integration of haptic feedback equipment to enrich the sensory experience.
    Enhanced AI assistance for more personalized support.

    Documentation:

    Full documentation will be provided to:
    Explain the theoretical concepts of CBT.
    Guide users through the application's functionalities.
    Offer advice on the optimal use of Behavolve as a complement to professional therapeutic follow-up.

    Behavolve's objective:

    Behavolve aims to revolutionize the way phobias are tackled by offering an accessible and interactive solution. By combining the power of mixed reality with the proven principles of cognitive-behavioral therapy, the application aims to facilitate the healing process and improve users' quality of life.

    Bonus:

    The AI-connected avatar not only guides the user, but interacts dynamically to:
    Answer questions in real time.
    Provide emotional support and encouragement.
    Adapt scenarios according to the user's reactions and comfort level.

    Conclusion:

    Behavolve represents a fusion of cutting-edge technology and a modern therapeutic approach, opening up new perspectives in the treatment of phobias. Thanks to its open-source nature, the community of developers and healthcare professionals can use the application free of charge and contribute to its ongoing enhancement, guaranteeing maximum effectiveness for patients.
    """

    let welcomeText = """
    Hello and welcome to Behavolve. Our mission is to help you understand your feelings about your phobias and find solutions to manage them better. 
    To begin with, could you tell me how you're feeling right now?
    """

    var onConfirmationButtonClicked: (() -> ()) = {}
    var onNextStepButtonClicked: (() -> ()) = {}
    var onCancelButtonClicked: (() -> ()) = {}

    var body: some View {
        VStack {
            Text(inputText)
                .frame(maxWidth: 950, alignment: .leading)
                .font(.extraLargeTitle2)
                .fontWeight(.regular)
                .padding(40)
                .glassBackgroundEffect()

            if showButtons {
                VStack(spacing: 20) {
                    HStack {
                        // Don't show already confirmed button
                        if appState.beeSceneState.isCurrentStepConfirmed == false {
                            if let confirm = appState.beeSceneState.step.buttonConfirmStepText(), let instructions = appState.beeSceneState.step.offlineStepInstructionText() {
                                Button(action: {
                                    onConfirmationButtonClicked()
                                    if AppState.isDevelopmentMode || DialogueView.ChatGptEnabled == false {
                                        Task {
                                            // Don't use OpenAI during development or when offline.
                                            await animatePromptText(instructions)
                                        }
                                    }
                                }) {
                                    Text(confirm)
                                        .font(.extraLargeTitle)
                                        .fontWeight(.regular)
                                        .padding(42)
                                        .cornerRadius(8)
                                        .glassBackgroundEffect()
                                }
                                .padding(0)
                                .buttonStyle(.plain)
                            }
                        }

                        if appState.beeSceneState.isCurrentStepConfirmed == true {
                            Button(action: {
                                onNextStepButtonClicked()
                                if AppState.isDevelopmentMode || DialogueView.ChatGptEnabled == false {
                                    Task {
                                        // Don't use OpenAI during development or when offline.
                                        await animatePromptText(appState.beeSceneState.step.offlineStepPresentationText())
                                    }
                                }
                            }) {
                                Text(appState.beeSceneState.step.buttonNextStepText())
                                    .font(.extraLargeTitle)
                                    .fontWeight(.regular)
                                    .padding(42)
                                    .cornerRadius(8)
                                    .glassBackgroundEffect()
                            }
                            .padding(0)
                            .buttonStyle(.plain)
                        }

                        Button(action: {
                            onCancelButtonClicked()
                        }) {
                            Text(appState.beeSceneState.step.buttonCancelText())
                                .font(.extraLargeTitle)
                                .fontWeight(.regular)
                                .padding(42)
                                .cornerRadius(8)
                                .glassBackgroundEffect()
                        }
                        .padding(0)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task {
            if AppState.isDevelopmentMode || DialogueView.ChatGptEnabled == false {
                // Don't consume OpenAI during development
                await animatePromptText(welcomeText)
                return
            }
            do {
                if apiMode == .assistant {
                    // A) Assistant
                    let assistantCreateResult = try await appState.openAI.assistantCreate(query: assistantsQuery)
                    assistantId = assistantCreateResult.id
                    guard let asstId = assistantId else { return }

                    // 1) Start query
                    let threadsQuery = ThreadsQuery(messages: [
                        .init(role: .user, content: "Hello, who are you?")!
                    ])
                    let runQuery = ThreadRunQuery(assistantId: asstId, thread: threadsQuery)
                    let initialRunResult = try await appState.openAI.threadRun(query: runQuery)

                    // 2) Wait until finished
                    let finalRunResult = try await waitUntilRunComplete(
                        threadId: initialRunResult.threadId,
                        runId: initialRunResult.id
                    )

                    if finalRunResult.status == .completed {
                        // 3) Get messages
                        let messagesResult = try await appState.openAI.threadsMessages(threadId: finalRunResult.threadId)
                        if let assistantMsg = messagesResult.data.last(where: { $0.role == .assistant }) {
                            let combinedText = assistantMsg.content
                                .filter { $0.type == .text }
                                .compactMap { $0.text?.value }
                                .joined(separator: " ")

                            finalizeResponse(combinedText.isEmpty ? "No text content." : combinedText)
                        } else {
                            finalizeResponse("No assistant message found.")
                        }
                    } else {
                        finalizeResponse("Run ended with status: \(finalRunResult.status)")
                    }
                } else {
                    // B) Chat streaming
                    let query = ChatQuery(
                        messages: [
                            .init(role: .assistant, content: DialogueView.instructions)!,
                            .init(role: .user, content: "Hello, who are you?")!
                        ],
                        model: .gpt3_5Turbo,
                        stream: true
                    )

                    appState.openAI.chatsStream(query: query) { partialResult in
                        showButtons = false
                        switch partialResult {
                        case .success(let chunk):
                            let textChunk = chunk.choices.first?.delta.content ?? ""
                            inputText.append(textChunk)
                        case .failure(let error):
                            print("Streaming chunk error:", error)
                        }
                    } completion: { error in
                        if let error = error {
                            print("Completion error:", error)
                        } else {
                            Task { finalizeResponse(inputText) }
                        }
                    }
                }
            } catch {
                print("Error:", error)
            }
        }
    }

    private func waitUntilRunComplete(threadId: String, runId: String) async throws -> RunResult {
        var result = try await appState.openAI.runRetrieve(threadId: threadId, runId: runId)

        while result.status == .queued || result.status == .inProgress {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            result = try await appState.openAI.runRetrieve(threadId: threadId, runId: runId)
        }
        return result
    }

    private func finalizeResponse(_ text: String) {
        inputText = text
        Task {
            await generateAndPlayAudio(from: text)
            withAnimation { showButtons = true }
        }
    }

    /// Generates audio via the OpenAI TTS API, then plays it from the therapist
    private func generateAndPlayAudio(from text: String) async {
        do {
            let audioQuery = AudioSpeechQuery(
                model: .tts_1,
                input: text,
                voice: .nova,
                responseFormat: .aac,
                speed: 1.0
            )
            let result = try await appState.openAI.audioCreateSpeech(query: audioQuery)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("tts_temp.mp3")
            try result.audio.write(to: tempURL)

            let config = AudioFileResource.Configuration(shouldLoop: false)
            let audioResource = try AudioFileResource.load(
                contentsOf: tempURL,
                withName: "GeneratedAudio",
                configuration: config
            )
            let audioPlaybackController = appState.beeSceneState.therapist.playAudio(audioResource)

            audioPlaybackController.completionHandler = {
                try? FileManager.default.removeItem(at: tempURL)
                // showButtons = true
            }
        } catch {
            print("Audio error:", error)
        }
    }

    func animatePromptText(_ text: String) async {
        showButtons = false
        inputText = ""
        let words = text.split(separator: " ")
        for word in words {
            inputText.append(word + " ")
            let milliseconds = AppState.isDevelopmentMode || DialogueView.ChatGptEnabled == false ? 1 : (1 + UInt64.random(in: 0 ... 1)) * 100
            try? await Task.sleep(for: .milliseconds(milliseconds))
        }

        withAnimation {
            showButtons = true
        }
    }
}
