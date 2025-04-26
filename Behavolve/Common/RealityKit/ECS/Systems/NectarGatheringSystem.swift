//
//  NectarGatheringSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 23/04/2025.
//

import ARKit
import RealityKit
import SwiftUI

@MainActor
final class NectarGatheringSystem: @preconcurrency System {
    static var dependencies: [SystemDependency] { [.after(MovementSystem.self)] }

    // Quantity withdrawn at each visit (limit: remaining stock).
    private let harvestAmount = 100
    private let goToDepositAmount = 400
    private let epsilon: Float = 0.01 // arrival tolerance

    private static let query = EntityQuery(
        where: .has(NectarGatheringComponent.self)
    )

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = context.deltaTime

        for entity in context.scene.performQuery(Self.query) {
            guard var gather = entity.components[NectarGatheringComponent.self],
                  let model = entity.findModelEntity()
            else { continue }

            // ──────────────────────────────────────────────────────────────
            // 1️⃣ Updated cooldowns for all flowers
            // ──────────────────────────────────────────────────────────────
            for i in gather.nectarSources.indices {
                gather.nectarSources[i].updateCooldown(dt: dt)
            }

            // ──────────────────────────────────────────────────────────────
            // 2️⃣ Is the bee still foraging?
            // ──────────────────────────────────────────────────────────────
            if var cd = entity.components[NectarGatheringCooldownComponent.self] {
                cd.remainingCooldown -= dt
                entity.components.set(cd) // always persist!

                if cd.remainingCooldown > 0 {
                    entity.components.set(gather) // nothing else to do
                    continue
                }

                // End of foraging: everything is put away, the stock is credited
                entity.components.remove(NectarGatheringCooldownComponent.self)
                entity.components.remove(OscillationComponent.self)

                if let idx = gather.lastVisitedIndex {
                    let taken = min(harvestAmount, gather.nectarSources[idx].stock)
                    gather.nectarStock += taken
                    gather.nectarSources[idx].stock -= taken

                    // Empty flower -> starts its own reload
                    if gather.nectarSources[idx].stock <= 0 {
                        gather.nectarSources[idx].reloadTimeRemaining =
                            gather.nectarSources[idx].reloadDuration
                    }
                }
            }

            // ──────────────────────────────────────────────────────────────
            // 3️⃣ Full bag? -> go to the depot
            // ──────────────────────────────────────────────────────────────
            if gather.nectarStock >= goToDepositAmount {
                entity.components.remove(NectarGatheringComponent.self)
                entity.components.set(
                    NectarDepositComponent(
                        depotPosition: gather.nectarDepotSitePosition,
                        nectarSources: gather.nectarSources,
                        speed: gather.speed,
                        carriedNectar: gather.nectarStock, // deposit quantity
                        depositDuration: 5.0
                    )
                )
                continue
            }
            // ──────────────────────────────────────────────────────────────
            // 4️⃣ Choice of target flower (from the available ones and different of the last visited)
            // ──────────────────────────────────────────────────────────────
            let here = model.position(relativeTo: nil)
            let available = gather.nectarSources.enumerated().filter { idx, src in
                src.isAvailable && idx != gather.lastVisitedIndex
            }

            guard let (tIndex, target) = available.min(by: { a, b in
                simd_distance(a.element.position, here) <
                    simd_distance(b.element.position, here)
            }) else {
                // No ready flowers yet
                entity.components.set(gather)
                continue
            }

            // ──────────────────────────────────────────────────────────────
            // 5️⃣ Arriving on the flower?
            // ──────────────────────────────────────────────────────────────
            let arrived = entity.components[MoveToComponent.self] == nil &&
                simd_distance(here, target.position) <= epsilon

            if arrived {
                // 5.a Snap parent so we don’t teleport on next flight
                entity.transform.translation = here // copy position
                entity.transform.rotation = model.orientation(relativeTo: nil)

                // 5.b Reset model local transform (keep scale so the bee size is constant)
                let scale = model.transform.scale
                model.transform = Transform(scale: scale,
                                            rotation: .init(),
                                            translation: .zero)

                // 5.c Stop looking at the flower
                entity.components.remove(LookAtTargetComponent.self)

                // 5.d Visible vibration while gathering
                entity.components.set(
                    OscillationComponent(amplitude: 50, frequency: 4)
                )

                // 5.e Start gathering cooldown
                entity.components.set(
                    NectarGatheringCooldownComponent(remainingCooldown: gather.gatheringCooldown)
                )

                gather.lastVisitedIndex = tIndex
                entity.components.set(gather)
                continue // next frame
            }

            // ──────────────────────────────────────────────────────────────
            // 6️⃣ If the bee is not already moving ➜ MoveTo + LookAt
            // ──────────────────────────────────────────────────────────────
            if entity.components[MoveToComponent.self] == nil {
                #if targetEnvironment(simulator)
                let strategy: MoveStrategy = .direct
                #else
                // let strategy: MoveStrategy = .pathfinding // not working atm
                let strategy: MoveStrategy = .direct
                #endif

                let distance = simd_distance(here, target.position)

                entity.components.set(
                    MoveToComponent(destination: target.position,
                                    speed: distance < 0.5 ? gather.speed / 3.0 : gather.speed, // Slow down when recolting nectar
                                    epsilon: epsilon,
                                    strategy: strategy)
                )

                // Keep watching the target while flying
                entity.components.set(
                    LookAtTargetComponent(target: .world(target.position))
                )
            }

            // Save the new component data
            entity.components.set(gather)
        }
    }
}
