//
//  ConversationView.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 27/06/2025.
//

import AVFoundation
import OpenAI
import RealityKit
import SwiftUI

enum ConversationApiMode {
    case assistant
    case streaming
}

struct ConversationView: View {
    @Environment(AppState.self) private var appState

    /// Switch between using Assistant (threadRun) or direct streaming (waiting from https://github.com/MacPaw/OpenAI/pull/140#issuecomment-2018689505 to support assistant streaming)
    let apiMode: ConversationApiMode = .streaming

    @State private var inputText = ""
    @State private var words: [String] = []
    @State private var currentWordIndex = 0
    @State private var timer: Timer?

    @State private var showButtons = false
    @State private var assistantId: String?

    /// Create a “personal Cognitive Behavioral therapist” assistant
    let assistantsQuery = AssistantsQuery(
        model: .gpt3_5Turbo,
        name: "Lucie",
        description: "An assistant specializing in Cognitive Behavioral Therapy",
        instructions: ConversationView.instructions,
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

    let step: ImmersiveBeeSceneStep

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // Status bar with colored circle and status
                HStack {
                    Circle()
                        .fill(appState.audioConversation.audioStatus == .listening ? .green : .red)
                        .frame(width: 14, height: 14)
                        .shadow(radius: 3)
                        .animation(.easeInOut, value: appState.audioConversation.audioStatus)
                    Text(appState.audioConversation.audioStatus == .listening ? "Listening..." : "Not started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)

                // Conversation transcription area
                ScrollView {
                    if appState.audioConversation.transcribedText.isEmpty && appState.audioConversation.responseText.isEmpty {
                        Text("Ready to start a conversation with Lucie, your cognitive behavioral therapist?")
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 650)
                            .foregroundStyle(.secondary)
                            .padding(40)
                    } else {
                        VStack(alignment: .leading, spacing: 32) {
                            if !appState.audioConversation.transcribedText.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("**You said:**")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                    Text(appState.audioConversation.transcribedText)
                                        .font(.title2)
                                        .padding(12)
                                        .frame(maxWidth: 950, alignment: .leading)
                                        .glassBackgroundEffect()
                                }
                            }
                            if !appState.audioConversation.responseText.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("**Therapist Lucie:**")
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                    Text(appState.audioConversation.responseText)
                                        .font(.title2)
                                        .padding(12)
                                        .frame(maxWidth: 950, alignment: .leading)
                                        .glassBackgroundEffect()
                                }
                            }
                        }
                        .padding(40)
                    }
                }

                Spacer()

                // Control buttons
                if appState.audioConversation.audioStatus != .listening {
                    Button {
                        Task {
                            await appState.startAudioConversationStreaming(step: step)
                        }
                    } label: {
                        Label("Start the conversation", systemImage: "mic.fill")
                            .font(.title)
                            .padding(.vertical, 22)
                            .padding(.horizontal, 60)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 32)
                    .transition(.opacity.combined(with: .scale))
                } else {
                    Button(role: .destructive) {
                        Task {
                            await appState.stopAudioConversationStreaming()
                        }
                    } label: {
                        Label("Stop the conversation", systemImage: "stop.fill")
                            .font(.title2)
                            .padding(.vertical, 18)
                            .padding(.horizontal, 50)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 32)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: appState.audioConversation.audioStatus)
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: 700, maxHeight: 600)
        .task {
            // await appState.startAudioConversationStreaming(step: step)
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
            if AppState.ChatGptAudioEnabled {
                await appState.generateAndPlayAudio(from: text)
            }
            withAnimation { showButtons = true }
        }
    }
}
