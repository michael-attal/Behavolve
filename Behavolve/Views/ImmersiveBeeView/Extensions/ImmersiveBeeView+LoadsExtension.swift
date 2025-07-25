//
//  ImmersiveBeeView+LoadsExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 27/03/2025.
//

import RealityKit
import RealityKitContent
import SwiftUI

// Extension for loading asseets in RealityView
extension ImmersiveBeeView {
    func addDefaultLighting(to scene: Entity) {
        let directionalLight = Entity()
        directionalLight.name = "DirectionalLightMixedSpace"
        directionalLight.components.set(
            DirectionalLightComponent(
                color: .white,
                intensity: 1000
            )
        )

        directionalLight.transform.rotation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])
        scene.addChild(directionalLight)

        // let pointLight = Entity()
        // pointLight.name = "PointLightMixedSpace"
        // pointLight.components.set(
        //     PointLightComponent(
        //         color: .white,
        //         intensity: 500
        //     )
        // )
        // scene.addChild(pointLight)
    }

    func loadTherapist(at position: SIMD3<Float>) async throws -> Entity {
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
        therapist.position = position
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

    func loadWarnings(from: RealityViewAttachments) throws -> Entity {
        guard let warnings = from.entity(for: "warnings_box") else { throw ImmersiveBeeViewError.entityError(message: "Can't find warnings_box") }
        warnings.scale = SIMD3(100, 100, 100)
        warnings.position = SIMD3<Float>(-10, 195, 0)

        warnings.components.set(LookAtTargetComponent(target: .device) { entityPosition, actualTargetPosition in
            actualTargetPosition.with(\.y, entityPosition.y)
        })

        return warnings
    }

    func loadBeehive(at position: SIMD3<Float>) async throws -> Entity {
        guard let beehiveSceneEntity = try? await Entity(named: "Models/Beehives/Beehive", in: realityKitContentBundle)
        else {
            throw ImmersiveBeeViewError.entityError(message: "Could not load Beehive")
        }

        guard let beehive = beehiveSceneEntity.findEntity(named: "Wooden_Beehive") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Wooden_Beehive entity")
        }

        beehive.scale = [0.005, 0.005, 0.005]
        beehive.position = position

        RealityKitHelper.updateCollisionFilter(
            for: beehive,
            groupType: .beehive,
            maskTypes: [.all],
            subtracting: .bee
        )

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

        guard let audioResource = try? await AudioFileResource(named: "/Root/Flying_Bee/bee_mp3", from: "Models/Bees/Bee.usda", in: realityKitContentBundle) else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find bee audio")
        }

        bee.components.set(SpatialAudioComponent(
            gain: -35.0,
            directLevel: 0.0,
            reverbLevel: -10.0,
            directivity: .beam(focus: 0.5),
            distanceAttenuation: .rolloff(factor: 2)
        ))

        appState.beeSceneState.beeAudioPlaybackController = bee.prepareAudio(audioResource)

        bee.components.set(SteeringComponent(avoidDistance: 0.15, strength: 1.0))

        bee.components.set(OscillationComponent(amplitude: 0.01, frequency: 4)) // idle oscillation

        bee.components.set(EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings)))

        RealityKitHelper.updateCollisionFilter(
            for: bee.findFirstEntityWithCollisionComponent()!,
            groupType: .bee,
            maskTypes: [.all],
            subtracting: .beehive
        )

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

            Entity.animate(.linear.repeatForever(autoreverses: true).speed(0.1)) {
                animatedEntity.scale *= 1.002
            } completion: {
                print("TADA")
            }
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
        // guard let waterBottleSceneEntity = try? await Entity(named: "Models/Water Bottles/Water Bottle 2", in: realityKitContentBundle)
        guard let waterBottleSceneEntity = try? await Entity(named: "Models/Water Bottles/Water Bottle", in: realityKitContentBundle)
        else {
            throw ImmersiveBeeViewError.entityError(message: "Could not load Water Bottle")
        }

        guard let waterBottle = waterBottleSceneEntity.findEntity(named: "Water_Bottle") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Water_Bottle entity")
        }

        // waterBottle.scale = [0.006, 0.006, 0.006]
        waterBottle.scale = [0.18, 0.18, 0.18]
        waterBottle.position.y = RealityKitHelper.getModelHeight(modelEntity: waterBottle.findModelEntity()!) + 0.10

        waterBottle.isEnabled = false // Enabled at InteractionInOwnEnvironment

        waterBottle.components.set(EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings)))

        ManipulationComponent.configureEntity(waterBottle)
        waterBottle.generateCollisionShapes(recursive: true)
        guard let collisionComponent = waterBottle.findModelEntity()?.findFirstCollisionComponent() else {
            throw ImmersiveBeeViewError.entityError(message: "Could not get Water_Bottle collision shapes")
        }
        #if !targetEnvironment(simulator)
        ManipulationComponent.configureEntity(
            waterBottle,
            hoverEffect: .spotlight(.init(color: .white)),
            allowedInputTypes: .direct,
            collisionShapes: collisionComponent.shapes
        )
        #endif
        #if targetEnvironment(simulator)
        ManipulationComponent.configureEntity(
            waterBottle,
            hoverEffect: .spotlight(.init(color: .white)),
            allowedInputTypes: .all,
            collisionShapes: collisionComponent.shapes
        )
        #endif

        var manipulationComponent = waterBottle.components[ManipulationComponent.self]!
        manipulationComponent.dynamics.scalingBehavior = .none
        manipulationComponent.releaseBehavior = .stay
        waterBottle.components.set(manipulationComponent)

        return waterBottle
    }

    func loadParticles() async throws -> Entity {
        guard let particlesSceneEntity = try? await Entity(named: "Models/Particles/Particles", in: realityKitContentBundle)
        else {
            throw ImmersiveBeeViewError.entityError(message: "Could not load Particles")
        }

        guard let particlesEmitter = particlesSceneEntity.findEntity(named: "ParticleEmitter") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find ParticleEmitter entity")
        }

        particlesEmitter.position = appState.beeSceneState.halo.position(relativeTo: nil)
        return particlesEmitter
    }

    func loadForest() async throws -> Entity {
        guard let forestSceneEntity = try? await Entity(named: "Models/Forest/Forest", in: realityKitContentBundle)
        else {
            throw ImmersiveBeeViewError.entityError(message: "Could not load Forest")
        }

        guard let forestWithPicnic = forestSceneEntity.findEntity(named: "Forest_With_Picnic") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find Forest_With_Picnic entity")
        }

        guard let bowlOfFruit = forestWithPicnic.findEntity(named: "bowl_of_fruit") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find bowl_of_fruit entity")
        }

        guard let lightSkySphere = forestSceneEntity.findEntity(named: "SkySphere") else {
            throw ImmersiveBeeViewError.entityError(message: "Could not find SkySphere entity")
        }

        #if !targetEnvironment(simulator)
        // In device remove one third of tree for performance
        // for i in 0 ... 100 {
        //     if let tree = forestWithPicnic.findEntity(named: "_4K_0_\(i)"), i % 3 == 0 {
        //         tree.removeFromParent()
        //     }
        // }
        // if let koffer = forestWithPicnic.findEntity(named: "Koffer") /* , i % 3 == 0 */ {
        //     koffer.removeFromParent()
        // }
        #endif

        appState.beeSceneState.bowlOfFruit = bowlOfFruit

        appState.beeSceneState.lightSkySphereSourceFromForest = lightSkySphere

        RealityKitHelper.addIBLReceiverToAllModels(in: forestWithPicnic, from: lightSkySphere)

        return forestWithPicnic
    }

    func load3DTextButtons() async throws -> (Entity, Entity) {
        // TODO: Create 3D text mesh with blender
        guard let textButtonsEntity = try? await Entity(named: "Models/3DTextButtons/3DTextButtons", in: realityKitContentBundle)
        else {
            throw ImmersiveBeeViewError.entityError(message: "Could not load 3DTextButtons")
        }

        let nextTextButton = textButtonsEntity.findEntity(named: "NextTextButton3D")!
        let prevTextButton = textButtonsEntity.findEntity(named: "PrevTextButton3D")!

        return (nextTextButton, prevTextButton)
    }

    func loadPlaneForGroundCollision() -> Entity {
        let planeMesh = MeshResource.generateBox(width: 100, height: 1, depth: 100)
        var planeMaterial = PhysicallyBasedMaterial()
        planeMaterial.baseColor = PhysicallyBasedMaterial.BaseColor(
            tint: .white.withAlphaComponent(1)
            // tint: .red
        )
        planeMaterial.blending = .transparent(opacity: 0.0)
        planeMaterial.opacityThreshold = 1.0

        let planeModelCommponent = ModelComponent(mesh: planeMesh, materials: [planeMaterial])
        let planeEntity = Entity(components: planeModelCommponent)
        planeEntity.generateCollisionShapes(recursive: true)
        planeEntity.components.set(PhysicsBodyComponent(shapes: planeEntity.findFirstCollisionComponent()!.shapes, mass: .infinity, mode: .static))
        planeEntity.position.y = -0.5

        RealityKitHelper.updateCollisionFilter(
            for: planeEntity,
            groupType: .beehive,
            maskTypes: [.all],
            subtracting: .bee
        ) // Avoid collision with bee (needed when she fly away when we are are to close)

        return planeEntity
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
            handAnchorEntity.components.set(GentleGestureComponent())
            // handAnchorEntity.components.set(ThumbUpGestureComponent())
        }
        #endif
    }

    func loadCalmMotionMonitorHeadset() -> Entity {
        let calmMonitorEntity = Entity()
        calmMonitorEntity.components.set(CalmMotionComponent())
        return calmMonitorEntity
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
