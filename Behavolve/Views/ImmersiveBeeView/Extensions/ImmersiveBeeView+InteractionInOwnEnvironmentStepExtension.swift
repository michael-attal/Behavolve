//
//  ImmersiveBeeView+InteractionInOwnEnvironmentStepExtension.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 24/04/2025.
//

// Extension for the InteractionInOwnEnvironment step
extension ImmersiveBeeView {
    func performPrepareInteractionInOwnEnvironmentStep() async throws {
        do {
            print("Waiting for user confirmation to start \(appState.beeSceneState.step)")
            // Load the water bottle and halo in advance

            if appState.beeSceneState.beeImmersiveContentSceneEntity.findEntity(named: "Water_Bottle") == nil {
                let waterBottle = try await loadWaterBottle()
                appState.beeSceneState.waterBottle = waterBottle
                appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(waterBottle)
                let halo = await RealityKitHelper.createHaloEntity(radius: 0.1, depth: 0.1, activateTransparency: true, minimumOpacity: 0.5, lowestPercentageEmissive: 0.1, onlyLoadHaloModelFromRealityKitContentBundle: true)
                // halo.position.x = flowersPosition.x - 0.5 // TODO: Place it on the first table detected or close to the flowers position.
                halo.position.z = -1.6
                halo.position.y = 0.7
                halo.name = "Halo"
                halo.isEnabled = false
                appState.beeSceneState.halo = halo
                appState.beeSceneState.beeImmersiveContentSceneEntity.addChild(halo)
            }
        } catch {
            print(error)
            throw error
        }
    }

    func performInteractionInOwnEnvironmentStep() {
        let flowersPosition = appState.beeSceneState.daffodilFlowerPot.position
        appState.beeSceneState.waterBottle.position.x = flowersPosition.x + 0.5
        appState.beeSceneState.waterBottle.position.z = flowersPosition.z
        appState.beeSceneState.waterBottle.isEnabled = true
        appState.beeSceneState.waterBottle.components.set(TargetReachedComponent(targetPosition: appState.beeSceneState.halo.position(relativeTo: nil), currentPosition: appState.beeSceneState.waterBottle.position(relativeTo: nil)))
        appState.beeSceneState.halo.isEnabled = true
    }

    func performFinishedInteractionInOwnEnvironmentStep() async throws {
        do {
            if appState.beeSceneState.step == .interactionInOwnEnvironment {
                appState.beeSceneState.step.next()
                appState.beeSceneState.isCurrentStepConfirmed = false

                try? await Task.sleep(for: .milliseconds(500))
                var newPosition = appState.beeSceneState.halo.position(relativeTo: nil)
                newPosition.y += 0.17

                let particles = try await loadParticles()
                appState.beeSceneState.halo.addChild(particles)

                appState.beeSceneState.waterBottle.transform.rotation = .init()
                appState.beeSceneState.waterBottle.position = newPosition
                print("Particule loaded and next step charged!")
            }
        } catch {
            print(error)
            throw error
        }
    }
}
