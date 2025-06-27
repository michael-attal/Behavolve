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

    @State private var inputText = ""
    @State private var words: [String] = []
    @State private var currentWordIndex = 0
    @State private var timer: Timer?

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
                                        .padding(20)
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
                                        .padding(20)
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
                    .padding(.bottom, appState.audioConversation.isLucieSpeaking ? 8 : 32)
                    .transition(.opacity.combined(with: .scale))
                    .disabled(appState.audioConversation.isLucieSpeaking)

                    if appState.audioConversation.isLucieSpeaking {
                        Text("Lucie is speaking...")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .padding(.bottom, 32)
                            .transition(.opacity)
                    } else {
                        Spacer().frame(height: 32)
                    }
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
        }
    }
}
