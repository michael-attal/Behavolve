//
//  BeeScenePatientAssessmentViews.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 01/07/2025.
//

import ResearchKit
import ResearchKitSwiftUI
import SwiftUI

// MARK: Pre-Session Questionnaire

struct BeeSceneResearchKitQuestionnaireView: View {
    var onCompletion: (ORKTaskResult?) -> Void

    private var task: ORKOrderedTask {
        // Consent step
        let consentStep = ORKInstructionStep(identifier: "consent")
        consentStep.title = "Consent"
        consentStep.text = "You are about to participate in a therapeutic VR experience to help manage your fear of bees. Your data will remain anonymous and secure."

        // Phobia rating before session
        let scaleAnswerFormat = ORKScaleAnswerFormat(
            maximumValue: 10,
            minimumValue: 0,
            defaultValue: 5,
            step: 1,
            vertical: false,
            maximumValueDescription: "Max anxiety",
            minimumValueDescription: "No anxiety"
        )
        let phobiaStep = ORKQuestionStep(
            identifier: "phobiaLevelBefore",
            title: "How anxious do you feel about bees right now?",
            answer: scaleAnswerFormat
        )

        let expectationsStep = ORKQuestionStep(
            identifier: "expectations",
            title: "What do you hope to achieve during this experience?",
            answer: ORKTextAnswerFormat(maximumLength: 150)
        )

        let ageStep = ORKQuestionStep(
            identifier: "age",
            title: "What is your age?",
            answer: ORKNumericAnswerFormat(style: .integer, unit: "years")
        )

        return ORKOrderedTask(
            identifier: "BeeSceneTherapyPreAssessment",
            steps: [consentStep, phobiaStep, expectationsStep, ageStep]
        )
    }

    var body: some View {
        // Present the questionnaire using the SwiftUI wrapper from ResearchKitSwiftUI fork
        ORKOrderedTaskView(tasks: task) { result in
            switch result {
            case .completed(let taskResult):
                onCompletion(taskResult)
            default:
                onCompletion(nil)
            }
        }
        .navigationTitle("Pre-session assessment")
    }
}

// MARK: Pre-session assessment

struct BeeScenePreSessionAssessmentView: View {
    @Environment(AppState.self) private var appState

    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var extractedScore: Int = 5
    @State private var extractedExpectations: String = ""

    var body: some View {
        BeeSceneResearchKitQuestionnaireView { result in
            if let result = result,
               let phobiaStep = result.stepResult(forStepIdentifier: "phobiaLevelBefore")?.firstResult as? ORKScaleQuestionResult,
               let level = phobiaStep.scaleAnswer?.intValue,
               let expStep = result.stepResult(forStepIdentifier: "expectations")?.firstResult as? ORKTextQuestionResult,
               let exp = expStep.textAnswer
            {
                extractedScore = level
                extractedExpectations = exp

                // TODO: appState.savePreSession(score: level, expectations: exp)
                print("PRE: Anxiety Score: \(level), Expectations: \(exp)")

                appState.handleBeginTherapy(immersiveView: .bee, researchKitQuestionnaireWindowID: appState.BeeScenePreSessionAssessmentWindowID, openImmersiveSpace: openImmersiveSpace, dismissImmersiveSpace: dismissImmersiveSpace, openWindow: openWindow, dismissWindow: dismissWindow)
            } else {
                appState.handleBeginTherapy(immersiveView: .bee, researchKitQuestionnaireWindowID: appState.BeeScenePreSessionAssessmentWindowID, openImmersiveSpace: openImmersiveSpace, dismissImmersiveSpace: dismissImmersiveSpace, openWindow: openWindow, dismissWindow: dismissWindow)
            }
        }
        .frame(width: 600)
        .task {
            dismissWindow(id: appState.MenuWindowID)
        }
    }
}

// MARK: - Post-session assessment view

struct BeeScenePostSessionResearchKitView: View {
    var onCompletion: (ORKTaskResult?) -> Void

    private var task: ORKOrderedTask {
        // Mood/Anxiety after session
        let scaleAnswerFormat = ORKScaleAnswerFormat(
            maximumValue: 10,
            minimumValue: 0,
            defaultValue: 5,
            step: 1,
            vertical: false,
            maximumValueDescription: "Max anxiety",
            minimumValueDescription: "No anxiety"
        )
        let moodStep = ORKQuestionStep(
            identifier: "moodAfter",
            title: "How do you feel now (anxiety level)?",
            answer: scaleAnswerFormat
        )

        let feedbackStep = ORKQuestionStep(
            identifier: "feedback",
            title: "How did the experience go? Any feedback?",
            answer: ORKTextAnswerFormat(maximumLength: 200)
        )

        return ORKOrderedTask(
            identifier: "BeeSceneTherapyPostAssessment",
            steps: [moodStep, feedbackStep]
        )
    }

    var body: some View {
        ORKOrderedTaskView(tasks: task) { result in
            switch result {
            case .completed(let taskResult):
                onCompletion(taskResult)
            default:
                onCompletion(nil)
            }
        }
        .navigationTitle("Post-session assessment")
    }
}

struct BeeScenePostSessionAssessmentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var extractedScore: Int = 5
    @State private var extractedFeedback: String = ""

    var body: some View {
        BeeScenePostSessionResearchKitView { result in
            if let result = result,
               let moodStep = result.stepResult(forStepIdentifier: "moodAfter")?.firstResult as? ORKScaleQuestionResult,
               let level = moodStep.scaleAnswer?.intValue,
               let fbStep = result.stepResult(forStepIdentifier: "feedback")?.firstResult as? ORKTextQuestionResult,
               let fb = fbStep.textAnswer
            {
                extractedScore = level
                extractedFeedback = fb

                // TODO: appState.savePostSession(score: level, feedback: fb)
                print("POST: Mood Score: \(level), Feedback: \(fb)")
                appState.beeSceneState.isPostSessionAssessmentFormWindowOpened = false
                appState.beeSceneState.isPostSessionAssessmentFormWindowFulfilled = true
                dismissWindow()
            } else {
                appState.beeSceneState.isPostSessionAssessmentFormWindowOpened = false
                appState.beeSceneState.isPostSessionAssessmentFormWindowFulfilled = true
                dismissWindow()
            }
        }
        .frame(width: 600)
    }
}
