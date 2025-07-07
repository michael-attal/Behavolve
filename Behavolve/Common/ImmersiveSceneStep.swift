//
//  ImmersiveSceneStep.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 07/07/2025.
//

/// Protocol for a generic immersive scene step (phobia therapy, exposure, etc.)
protocol ImmersiveSceneStep: Equatable, Codable, Sendable {
    associatedtype StepType: RawRepresentable, Codable, CaseIterable, Equatable where StepType.RawValue == Int

    var type: StepType { get set }
    var isCleaned: Bool { get set }
    var isLoaded: Bool { get set }
    var isPlaced: Bool { get set }
    var isFinished: Bool { get set }
    var isCurrentStepConfirmed: Bool { get set }
    var isPreviousStep: Bool { get set }

    mutating func next()
    mutating func previous()

    var isConfirmationRequired: Bool { get }
    func buttonConfirmStepText() -> String?
    func buttonNextStepText() -> String?
    func buttonCancelText() -> String
    func offlineStepPresentationText() -> String
    func offlineStepInstructionText() -> String?
}
