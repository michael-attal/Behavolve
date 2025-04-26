//
//  ImmersiveBeeView+LoadsExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 27/03/2025.
//

import _RealityKit_SwiftUI
import RealityFoundation
import RealityKitContent

// Extension for loading asseets in RealityView
extension ImmersiveBeeView {
    func loadBee(from: Entity) async throws -> Entity {
        guard let bee = from.findEntity(named: "Flying_Bee") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Flying_Bee entity")
        }

        bee.setGroundingShadow(castsShadow: true)

        bee.scale = [0.00015, 0.00015, 0.00015]
        bee.position = [0, 1.5, -1.5]

        guard let beeAnimResource = bee.availableAnimations.first else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find bee animation")
        }
        let beeFlyingAnim = try! AnimationResource.generate(with: beeAnimResource.repeat().definition)

        bee.playAnimation(beeFlyingAnim)

        guard let audioResource = try? await AudioFileResource(named: "/Root/Flying_Bee/bee_mp3", from: "Scenes/Bee Scene.usda", in: realityKitContentBundle) else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find bee audio")
        }
        bee.spatialAudio = SpatialAudioComponent(gain: -50)

        appState.beeSceneState.beeAudioPlaybackController = bee.prepareAudio(audioResource)

        bee.components.set(
            SteeringComponent(avoidDistance: 0.15, strength: 1.0)
        )

        return bee
    }

    func loadBeehive(from: Entity) async throws -> Entity {
        guard let beehive = from.findEntity(named: "Wooden_Beehive") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Wooden_Beehive entity")
        }

        beehive.setGroundingShadow(castsShadow: true)
        beehive.scale = [0.005, 0.005, 0.005]
        beehive.position = [-1.5, 0.0, -1.5]
        // TODO: Place it on a table instead of hardcoding the position later (like the flowers)

        return beehive
    }

    func loadTherapist(from: Entity) throws -> Entity {
        guard let therapist = from.findEntity(named: "Therapist") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Therapist entity")
        }
        therapist.setGroundingShadow(castsShadow: true)
        guard let therapistAnimResource = therapist.availableAnimations.first, let therapistAnim = try? AnimationResource.generate(with: therapistAnimResource.repeat().definition) else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Therapist animation")
        }
        therapist.scale = [0.01, 0.01, 0.01]
        therapist.position = [-0.8, 0, -2]
        let therapistControllerAnimation = therapist.playAnimation(
            therapistAnim,
            transitionDuration: 0.3,
            blendLayerOffset: 0,
            separateAnimatedValue: true,
            startsPaused: true
        )
        therapistControllerAnimation.speed = 0.5

        therapist.components.set(LookAtTargetComponent(target: .device) { entityPosition, actualTargetPosition in
            actualTargetPosition.with(\.y, entityPosition.y)
        })
        return therapist
    }

    func loadDialogue(from: RealityViewAttachments) throws -> Entity {
        guard let dialogue = from.entity(for: "dialogue_box") else { throw ImmersiveBeeViewError.entityError(message: "Can't find dialogue_box") }
        dialogue.scale = SIMD3(100, 100, 100)
        dialogue.position = SIMD3<Float>(-10, 220, 0)

        dialogue.components.set(LookAtTargetComponent(target: .device) { entityPosition, actualTargetPosition in
            actualTargetPosition.with(\.y, entityPosition.y)
        })

        return dialogue
    }

    func loadFlower(from: Entity, withName name: String, playScalingAnimation: Bool = true, animatedEntityNamed: String? = nil) throws -> Entity {
        guard let flower = from.findEntity(named: name) else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find \(name) entity")
        }

        flower.setGroundingShadow(castsShadow: true)

        flower.scale = [0.1, 0.1, 0.1]
        flower.position = [1, 0, -1.1]

        // guard let flowerAnimResource = flower.availableAnimations.first else {
        //     throw ImmersiveBeeViewError.entityError(message: "Could not find flower animation")
        // }
        // let flowerAnim = try! AnimationResource.generate(with: flowerAnimResource.repeat().definition)
        // flower.playAnimation(flowerAnim)

        if playScalingAnimation {
            var animatedEntity = flower
            if let animatedEntityNamed {
                guard let animatedEntityFromName = flower.findEntity(named: animatedEntityNamed) else {
                    throw ImmersiveBeeViewError.entityError(message: "Could not find \(animatedEntityNamed) entity for the animation of \(name)")
                }
                animatedEntity = animatedEntityFromName
            }
            RealityKitHelper.fromToByAnimationScaling(fromScale: animatedEntity.scale, toScale: animatedEntity.scale * 1.05, toEntity: animatedEntity, timing: .linear, duration: 2.0, loop: true, isAdditive: false, playAutomatically: true)
        }

        return flower
    }

    func loadCatchError(from: RealityViewAttachments) -> Entity? {
        guard let errorView = from.entity(for: "error_view") else {
            print("Error in catch: no error view attachment found")
            return nil
        }
        errorView.scale = SIMD3(1, 1, 1)
        errorView.position = SIMD3<Float>(0, 1.5, -1)

        return errorView
    }
}
