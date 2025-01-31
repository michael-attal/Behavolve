import AVFoundation
import OpenAI
import RealityFoundation
import SwiftUI

struct DialogueView: View {
    @Environment(AppModel.self) private var appModel

    @State private var inputText = ""
    @State private var showButtons: Bool = false
    @State private var audioPlayer: AVAudioPlayer?

    /// We store the ID of the wizard created (to use it later).
    @State private var assistantId: String?

    /// Create a “personal development coach” assistant
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
    Your mission is to help you understand your feelings about your phobias and find solutions to manage them better
    Your aim is to help users achieve their personal goals, 
     develop their self-confidence, better manage their emotions, 
     and guide them with kindness and clarity.

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

    var onValidationButtonClicked: (() -> ()) = {}
    var onCancelButtonClicked: (() -> ()) = {}

    var body: some View {
        VStack {
            Text(inputText)
                .frame(maxWidth: 600, alignment: .leading)
                .font(.extraLargeTitle2)
                .fontWeight(.regular)
                .padding(40)
                .glassBackgroundEffect()

            if showButtons {
                VStack(spacing: 20) {
                    HStack {
                        Button(action: {
                            onValidationButtonClicked()
                        }) {
                            Text("I'm ready to start")
                                .font(.extraLargeTitle)
                                .fontWeight(.regular)
                                .padding(42)
                                .cornerRadius(8)
                                .glassBackgroundEffect()
                        }
                        .padding(0)
                        .buttonStyle(.plain)

                        Button(action: {
                            onCancelButtonClicked()
                        }) {
                            Text("I'd like to know more")
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
            do {
                let assistantCreateResult = try await appModel.openAI.assistantCreate(query: assistantsQuery)
                self.assistantId = assistantCreateResult.id
                
                // TODO: Use assistant instead of ChatQuery
                let query = ChatQuery(
                    messages: [
                        .init(role: .assistant, content: DialogueView.instructions)!,
                        .init(role: .user, content: "who are you?")!
                    ],
                    model: .gpt3_5Turbo
                )

                appModel.openAI.chatsStream(query: query) { partialResult in
                    showButtons = false
                    switch partialResult {
                    case .success(let chunk):
                        let textChunk = chunk.choices.first?.delta.content ?? ""
                        inputText.append(textChunk)

                    case .failure(let error):
                        print("Streaming error chunk:", error)
                    }
                } completion: { error in
                    // When all the streaming is finished, we launch the audio synthesis
                    if let error = error {
                        print("Error in complete flow:", error)
                    } else {
                        Task {
                            await generateAndPlayAudio(from: inputText)
                            withAnimation {
                                showButtons = true
                            }
                        }
                    }
                }

            } catch {
                print("Error when creating assistant or chat:", error)
            }
        }
    }

    /// Generates audio via the OpenAI TTS API, then plays it from the therapist
    private func generateAndPlayAudio(from text: String) async {
        do {
            let audioQuery = AudioSpeechQuery(
                model: .tts_1,
                input: text,
                voice: .nova,
                responseFormat: .mp3,
                speed: 1.0
            )
            let result = try await appModel.openAI.audioCreateSpeech(query: audioQuery)

            do {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("tts_temp.mp3")
                try result.audio.write(to: tempURL)

                let config = AudioFileResource.Configuration(shouldLoop: false)
                let audioResource = try AudioFileResource.load(contentsOf: tempURL,
                                                               withName: "GeneratedAudio",
                                                               configuration: config)

                let playbackController = appModel.beeSceneState.therapist.playAudio(audioResource)
            } catch {
                print("Error writing or loading MP3 file:", error)
            }
        } catch {
            print("Error during audio generation/playback:", error)
        }
    }

    func animatePromptText(_ text: String) async {
        showButtons = false
        inputText = ""
        let words = text.split(separator: " ")
        for word in words {
            inputText.append(word + " ")
            let milliseconds = (1 + UInt64.random(in: 0 ... 1)) * 100
            try? await Task.sleep(for: .milliseconds(milliseconds))
        }

        withAnimation {
            showButtons = true
        }
    }
}
