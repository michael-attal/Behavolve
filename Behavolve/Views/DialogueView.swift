//
//  DialogueView.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 27/06/2025.
//

import RealityKit
import SwiftUI

// TODO: Refactor the code to make it more generic for future therapies, such as treating ophidiophobia (fear of snakes) ...

struct DialogueView: View {
    let step: ImmersiveBeeSceneStep

    var onConfirmationButtonClicked: () -> Void = {}
    var onNextStepButtonClicked: () -> Void = {}
    var onCancelButtonClicked: () -> Void = {}

    @Environment(AppState.self) private var appState

    @State private var inputText = ""
    @State private var words: [String] = []
    @State private var currentWordIndex = 0
    @State private var showButtons = false

    @State private var timer: Timer?

    var body: some View {
        VStack {
            Text(inputText)
                .frame(maxWidth: 1000, alignment: .leading)
                .font(.extraLargeTitle2)
                .fontWeight(.regular)
                .padding(40)
                .glassBackgroundEffect()

            if showButtons {
                VStack(spacing: 20) {
                    HStack {
                        if step.isConfirmationRequired
                            && step.isCurrentStepConfirmed == false,
                            let confirm = step.buttonConfirmStepText()
                        {
                            Button(action: {
                                onConfirmationButtonClicked()
                            }) {
                                Text(confirm)
                                    .font(.extraLargeTitle)
                                    .fontWeight(.regular)
                                    .padding(42)
                                    .cornerRadius(8)
                                    .glassBackgroundEffect()
                            }
                            .buttonStyle(.plain)
                        }

                        if step.type != .end || (step.type == .end && appState.beeSceneState.isPostSessionAssessmentFormWindowOpened == false && appState.beeSceneState.isPostSessionAssessmentFormWindowFulfilled == false) {
                            if (step.isConfirmationRequired
                                && step.isCurrentStepConfirmed)
                                || step.isConfirmationRequired == false,
                                let buttonNextStepText = step.buttonNextStepText()
                            {
                                Button(action: {
                                    onNextStepButtonClicked()
                                }) {
                                    Text(buttonNextStepText)
                                        .font(.extraLargeTitle)
                                        .fontWeight(.regular)
                                        .padding(42)
                                        .cornerRadius(8)
                                        .glassBackgroundEffect()
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button(action: {
                            onCancelButtonClicked()
                        }) {
                            Text(step.buttonCancelText())
                                .font(.extraLargeTitle)
                                .fontWeight(.regular)
                                .padding(42)
                                .cornerRadius(8)
                                .glassBackgroundEffect()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            let presentationStep = step.offlineStepPresentationText()
            animateText(presentationStep)
            if AppState.ChatGptAudioEnabledForOfflineText {
                Task {
                    await appState.generateAndPlayAudio(from: presentationStep)
                }
            }
        }
        .onChange(of: step) { _, newStep in
            var text = ""
            if step.isConfirmationRequired
                && step.isCurrentStepConfirmed,
                let offlineStepInstructionText = newStep.offlineStepInstructionText()
            {
                text = offlineStepInstructionText
            } else {
                text = newStep.offlineStepPresentationText()
            }

            animateText(text)
            if AppState.ChatGptAudioEnabledForOfflineText {
                Task {
                    await appState.generateAndPlayAudio(from: text)
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func animateText(_ text: String) {
        timer?.invalidate()
        inputText = ""
        showButtons = false
        words = text.components(separatedBy: " ")
        currentWordIndex = 0

        timer = Timer.scheduledTimer(withTimeInterval: AppState.fastDialogue ? 0.01 : 0.1, repeats: true) { timer in
            guard currentWordIndex < words.count else {
                timer.invalidate()
                withAnimation { showButtons = true }
                return
            }

            inputText += words[currentWordIndex] + " "
            currentWordIndex += 1
        }
    }
}
