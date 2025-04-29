//
//  BeeSceneState.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 31/01/2025.
//

import ARKit
import Foundation
import RealityFoundation

@MainActor
@Observable
class BeeSceneState {
    var bee = Entity()
    var beehive = Entity()
    var beeAudioPlaybackController: AudioPlaybackController!
    var therapist = Entity()
    var isFlowersPlaced: Bool = false
    var flowersPotsGroup = Entity()
    var flowersPotOneDefault = Entity()
    var flowersPotTwoAlternativ = Entity()
    var flowersPotTreeOriginal = Entity()
    var daffodilFlowerPot = Entity()
    var tableInPatientRoom: (any Anchor)?
    var floorInPatientRoom: (any Anchor)?
    var step: ImmersiveBeeSceneStep = AppState.isDevelopmentMode ? .neutralBeeGatheringNectarFromFlowers : .neutralIdle
    var isCurrentStepConfirmed = true
}

enum ImmersiveBeeSceneStep {
    case neutralIdle
    case neutralExplanation
    case neutralBeeGatheringNectarFromFlowers
    case interactionInOwnEnvironment
    case interactionInForrestFullSpace

    func isConfirmationRequiredWithThisStep() -> Bool {
        switch self {
        case .neutralIdle,
             .neutralExplanation,
             .neutralBeeGatheringNectarFromFlowers:
            return false
        case .interactionInOwnEnvironment, .interactionInForrestFullSpace:
            return true
        }
    }

    mutating func next() {
        switch self {
        case .neutralIdle:
            self = .neutralExplanation
        case .neutralExplanation:
            self = .neutralBeeGatheringNectarFromFlowers
        case .neutralBeeGatheringNectarFromFlowers:
            self = .interactionInOwnEnvironment
        case .interactionInOwnEnvironment:
            self = .interactionInForrestFullSpace
        case .interactionInForrestFullSpace:
            self = .neutralIdle
        }
    }

    mutating func previous() {
        switch self {
        case .neutralIdle:
            self = .interactionInForrestFullSpace
        case .neutralExplanation:
            self = .neutralIdle
        case .neutralBeeGatheringNectarFromFlowers:
            self = .neutralExplanation
        case .interactionInOwnEnvironment:
            self = .neutralBeeGatheringNectarFromFlowers
        case .interactionInForrestFullSpace:
            self = .interactionInOwnEnvironment
        }
    }

    func buttonConfirmStepText() -> String? {
        switch self {
        case .neutralIdle, .neutralExplanation, .neutralBeeGatheringNectarFromFlowers:
            return nil
        case .interactionInOwnEnvironment:
            return "Start water bottle challenge"
        case .interactionInForrestFullSpace:
            return "Start picnic experience"
        }
    }

    func buttonNextStepText() -> String {
        switch self {
        case .neutralIdle:
            return "Begin therapeutic journey"
        case .neutralExplanation:
            return "Let's observe bee behavior"
        case .neutralBeeGatheringNectarFromFlowers:
            return "Next: Try the water bottle challenge"
        case .interactionInOwnEnvironment:
            return "Next: Picnic experience in forest"
        case .interactionInForrestFullSpace:
            return "Back to home"
        }
    }

    func buttonCancelText() -> String {
        switch self {
        case .neutralIdle:
            return "I need more time"
        case .neutralExplanation:
            return "Return to start"
        case .neutralBeeGatheringNectarFromFlowers:
            return "Take a break"
        case .interactionInOwnEnvironment:
            return "Step back from challenge"
        case .interactionInForrestFullSpace:
            return "Leave forest experience"
        }
    }

    func offlineStepPresentationText() -> String {
        switch self {
        case .neutralIdle:
            return """
            Welcome to Behavolve, a therapeutic experience designed to help you overcome your fear of bees in a safe, controlled environment. 

            This application uses mixed reality to gradually expose you to bee encounters while teaching you practical coping strategies. Remember, you're always in control - you can exit at any time by making a fist gesture or simply saying "EXIT".

            Throughout this experience, the bee will naturally move away if you get too close, just like in nature. This ensures you'll always maintain a comfortable distance. Are you ready to begin this journey towards understanding and managing your fear better?
            
            In the next step, the bee will fly to the middle of the room in a protective cube. If you want, you can inspect it or even remove the cube with your hand if you want.
            """

        case .neutralExplanation:
            return """
            Let me explain how bees behave in their natural environment. Bees are fascinating creatures that play a vital role in our ecosystem. They are actually quite predictable and peaceful when undisturbed.

            In their daily routine, bees follow specific patterns: they leave their hive, search for flowers, collect nectar and pollen, and return home. They're not interested in humans at all - they're focused on their important work!

            I'll show you these behaviors step by step, starting with a simple demonstration. This will help you understand that bees are not actively seeking to harm anyone. They're simply busy workers doing their job.

            Remember, you're completely safe here. We can pause or stop at any time if you feel uncomfortable. Would you like to see how a bee typically moves around flowers?
            """

        case .neutralBeeGatheringNectarFromFlowers:
            return """
            Now, watch as our bee demonstrates its natural nectar-gathering behavior. Notice how focused it is on the flowers, following a precise pattern as it moves from bloom to bloom.

            I've implemented a safety system that makes the bee naturally maintain its distance if you get too close - just like real bees prefer to avoid human contact. This gives you the chance to observe without anxiety.

            Pay attention to how methodically it works: approaching each flower, gathering nectar, and moving to the next. This is their natural purpose - they're not interested in humans unless disturbed.

            Take your time to observe. How do you feel watching the bee from this safe distance?
            """

        case .interactionInOwnEnvironment:
            return """
            It's time for your first interactive challenge! I've placed a water bottle near the flower pot where our bee is gathering nectar. Your goal is to calmly reach for and retrieve the bottle without making any sudden movements.

            Remember, sudden movements are what can startle bees in real life. This exercise will help you practice maintaining composure around bees while accomplishing a simple task.

            The bee will continue its natural behavior and will move away if you get too close. Focus on keeping your movements smooth and deliberate. Take deep breaths if you need to - there's no rush.

            Remember, you can exit at any time by making a fist or saying "EXIT". Ready to try?
            """

        case .interactionInForrestFullSpace:
            return """
            Welcome to the final challenge! You're now in a peaceful forest setting for a picnic. As expected in nature, a curious bee has noticed the sweet foods in your picnic basket.

            Don't worry - this is a perfect opportunity to practice the calm response techniques we've been developing. The bee will maintain a safe distance, but it's interested in the sweet scents.

            Your goal is to remain calm and use gentle hand movements to guide the bee away - just like you might in a real picnic situation. No sudden movements needed; simple, slow gestures are most effective.

            Remember all you've learned about bee behavior, and that you can exit anytime by making a fist or saying "EXIT". How about we practice these calming techniques together?
            """
        }
    }

    func offlineStepInstructionText() -> String? {
        switch self {
        case .interactionInOwnEnvironment:
            return """
            Here's your first interactive challenge:

            1. Locate the blue water bottle near the flower pot
            2. Slowly reach for the bottle, keeping your movements smooth and controlled
            3. Pick up the bottle and place it about 5 meters away from the flowers
            4. Remember: the bee will naturally move away if you get too close
            5. Take deep breaths if you feel anxious

            Your goal is to complete this task while staying calm. There's no time limit - move at your own pace.
            Remember you can exit anytime by making a fist or saying "EXIT".

            Ready? Take a deep breath, and begin when you feel comfortable.
            """

        case .interactionInForrestFullSpace:
            return """
            Guide to your picnic experience:

            1. You're sitting at your picnic spot with some sweet treats nearby
            2. A curious bee will approach, interested in the sweet scents
            3. Practice using gentle hand movements to guide the bee away
            4. Keep your movements slow and deliberate - no sudden gestures
            5. Focus on your breathing to stay calm

            Remember: The bee will maintain a safe distance naturally. This is a controlled environment to practice your response techniques.
            You can exit anytime by making a fist or saying "EXIT".

            Take a deep breath. When you're ready, we'll begin the experience.
            """

        default:
            return nil
        }
    }
}
