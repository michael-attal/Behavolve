//
//  ImmersiveBeeView+LoadsExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 27/03/2025.
//

import _RealityKit_SwiftUI
import RealityKit
import RealityKitContent
import SwiftUI

// Extension for loading asseets in RealityView
extension ImmersiveBeeView {
    func loadTherapist() async throws -> Entity {
        guard let therapistSceneEntity = try? await Entity(named: "Models/Therapist/Therapist", in: realityKitContentBundle)
        else {
            throw ImmersiveBeeViewError.entityError(message: "Could not load Therapist")
        }

        guard let therapist = therapistSceneEntity.findEntity(named: "Therapist_TCC") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Therapist entity")
        }
        guard let therapistAnimResource = therapist.availableAnimations.first, let therapistAnim = try? AnimationResource.generate(with: therapistAnimResource.repeat().definition) else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Therapist animation")
        }
        therapist.scale = [0.0095, 0.0095, 0.0095]
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

        therapist.components.set(EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings)))

        // therapist.generateCollisionShapes(recursive: true)
        // therapist.components.set(GestureComponent(
        //     TapGesture().onEnded {
        //         print("Therapist tapped")
        //     }
        // ))

        return therapist
    }

    func loadDialogue(from: RealityViewAttachments) throws -> Entity {
        guard let dialogue = from.entity(for: "dialogue_box") else { throw ImmersiveBeeViewError.entityError(message: "Can't find dialogue_box") }
        dialogue.scale = SIMD3(100, 100, 100)
        dialogue.position = SIMD3<Float>(-10, 230, 0)

        dialogue.components.set(LookAtTargetComponent(target: .device) { entityPosition, actualTargetPosition in
            actualTargetPosition.with(\.y, entityPosition.y)
        })

        return dialogue
    }

    func loadBeehive() async throws -> Entity {
        guard let beehiveSceneEntity = try? await Entity(named: "Models/Beehives/Beehive", in: realityKitContentBundle)
        else {
            throw ImmersiveBeeViewError.entityError(message: "Could not load Beehive")
        }

        guard let beehive = beehiveSceneEntity.findEntity(named: "Wooden_Beehive") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Wooden_Beehive entity")
        }

        beehive.scale = [0.005, 0.005, 0.005]
        beehive.position = [-1.5, 0.0, -1.5]

        return beehive
    }

    func loadBee() async throws -> Entity {
        guard let beeSceneEntity = try? await Entity(named: "Models/Bees/Bee", in: realityKitContentBundle)
        else {
            throw ImmersiveBeeViewError.entityError(message: "Could not load Bee")
        }

        guard let bee = beeSceneEntity.findEntity(named: "Flying_Bee") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Flying_Bee entity")
        }

        bee.scale = [0.00015, 0.00015, 0.00015]
        bee.position = [-1.5, 0.1, -1.5] // Same as the beehive

        guard let beeAnimResource = bee.availableAnimations.first else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find bee animation")
        }
        let beeFlyingAnim = try! AnimationResource.generate(with: beeAnimResource.repeat().definition)

        bee.playAnimation(beeFlyingAnim)

        guard let audioResource = try? await AudioFileResource(named: "/Root/bee_mp3", from: "Models/Bees/Bee.usda", in: realityKitContentBundle) else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find bee audio")
        }
        bee.spatialAudio = SpatialAudioComponent(gain: -50)
        appState.beeSceneState.beeAudioPlaybackController = bee.prepareAudio(audioResource)

        bee.components.set(SteeringComponent(avoidDistance: 0.15, strength: 1.0))

        #if !targetEnvironment(simulator)
        bee.components.set(HandProximityComponent(safeDistance: 0.3, fleeSpeed: 0.5, fleeDuration: 2))
        bee.components.set(HandCollisionComponent(collisionDistance: 0.2, impulseStrength: 1, recoverDuration: 3))
        #endif

        // bee.components.set(UserProximityComponent(safeDistance: 1.0, fleeSpeed: 0.5, fleeDuration: 2))
        bee.components.set(OscillationComponent(amplitude: 0.01, frequency: 4)) // idle oscillation

        bee.components.set(EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings)))

        return bee
    }

    func loadFlower(playScalingAnimation: Bool = true) async throws -> Entity {
        guard let flowersSceneEntity = try? await Entity(named: "Models/Flowers/Flowers", in: realityKitContentBundle)
        else {
            throw ImmersiveBeeViewError.entityError(message: "Could not load Flowers")
        }

        guard let flower = flowersSceneEntity.findEntity(named: "Daffodil_flower_pot") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Daffodil_flower_pot entity")
        }

        flower.scale = [0.001, 0.001, 0.001]
        flower.position = [1, 0, -1.1]

        // guard let flowerAnimResource = flower.availableAnimations.first else {
        //     throw ImmersiveBeeViewError.entityError(message: "Could not find flower animation")
        // }
        // let flowerAnim = try! AnimationResource.generate(with: flowerAnimResource.repeat().definition)
        // flower.playAnimation(flowerAnim)

        if playScalingAnimation {
            guard let animatedEntity = flower.findEntity(named: "Daffodil") else {
                throw ImmersiveBeeViewError.entityError(message: "Could not find Daffodil entity for the animation of Flowers")
            }
            RealityKitHelper.fromToByAnimationScaling(fromScale: animatedEntity.scale, toScale: animatedEntity.scale * 1.01, toEntity: animatedEntity, timing: .linear, duration: 2.0, loop: true, isAdditive: false, playAutomatically: true)
        }

        flower.components.set(EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings)))

        // New api for gesture, directly with a gesture component.
        // flower.components.set(GestureComponent(
        //     TapGesture().onEnded {
        //         print("Flower tapped")
        //     }
        // ))

        return flower
    }

    func loadWaterBottle() async throws -> Entity {
        guard let waterBottleSceneEntity = try? await Entity(named: "Models/Water Bottles/Water Bottle 2", in: realityKitContentBundle)
        else {
            throw ImmersiveBeeViewError.entityError(message: "Could not load Water Bottle")
        }

        guard let waterBottle = waterBottleSceneEntity.findEntity(named: "Water_Bottle") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Water_Bottle entity")
        }
        waterBottle.scale = [0.006, 0.006, 0.006]
        waterBottle.isEnabled = false // Enabled at InteractionInOwnEnvironment

        waterBottle.components.set(EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings)))
       
        ManipulationComponent.configureEntity(waterBottle)
        waterBottle.generateCollisionShapes(recursive: true)
        guard let collisionComponent = waterBottle.findModelEntity()?.findFirstCollisionComponent() else {
            throw ImmersiveBeeViewError.entityError(message: "Could not get Water_Bottle collision shapes")
        }
        ManipulationComponent.configureEntity(
            waterBottle,
            hoverEffect: .spotlight(.init(color: .white)),
            allowedInputTypes: .direct,
            collisionShapes: collisionComponent.shapes
        )
       
        var manipulationComponent = waterBottle.components[ManipulationComponent.self]!
        manipulationComponent.dynamics.scalingBehavior = .none
        manipulationComponent.releaseBehavior = .stay
        waterBottle.components.set(manipulationComponent)

        return waterBottle
    }

    func loadUserHands(content: inout RealityViewContent) {
        #if !targetEnvironment(simulator)
        if appState.handAnchorEntities.isEmpty {
            for _ in 0 ..< 2 { // left + right
                let anchor = AnchorEntity(world: .zero)
                anchor.components.set(HandComponent()) // handID == nil for now
                appState.handAnchorEntities.append(anchor)
                content.add(anchor)
            }
        }
        for handAnchorEntity in appState.handAnchorEntities {
            handAnchorEntity.components.set(ExitGestureComponent())
        }
        #endif
    }

    func loadSubscribtionToManipulationEvents(content: inout RealityViewContent) {
        var willBegin = content.subscribe(to: ManipulationEvents.WillBegin.self) { event in
            print("Will begin manipulation")
            if var physicsBody = event.entity.components[PhysicsBodyComponent.self] {
                physicsBody.mode = .kinematic
                event.entity.components.set(physicsBody)
            }
        }

        var willEnd = content.subscribe(to: ManipulationEvents.WillEnd.self) { event in
            print("Will end manipulation")
            if var physicsBody = event.entity.components[PhysicsBodyComponent.self] {
                physicsBody.mode = .dynamic
                event.entity.components.set(physicsBody)
            }
        }
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
