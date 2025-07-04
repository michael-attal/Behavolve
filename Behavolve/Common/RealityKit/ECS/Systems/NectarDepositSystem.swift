//
//  NectarDepositSystem.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 23/04/2025.
//

import ARKit
import RealityKit
import SwiftUI

@MainActor
final class NectarDepositSystem: @MainActor System {
    static var dependencies: [SystemDependency] { [.after(MovementSystem.self), .after(NectarGatheringSystem.self)] }

    /// Entities currently in deposit phase (no gathering component).
    private static let query = EntityQuery(where: .has(NectarDepositComponent.self))

    private let epsilon: Float = 0.01

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = context.deltaTime

        for parent in context.scene.performQuery(Self.query) {
            guard var deposit = parent.components[NectarDepositComponent.self],
                  let model = parent.findModelEntity()
            else { continue }

            // Cool‑down (bee already on the hive)
            if deposit.remainingCooldown > 0 {
                deposit.remainingCooldown -= dt
                parent.components.set(deposit) // persist

                if deposit.remainingCooldown <= 0 {
                    // Drop finished -> switch to gathering
                    parent.components.set(OscillationComponent(amplitude: 0.01, frequency: 4)) // Back to default oscilliation
                    parent.components.remove(NectarDepositComponent.self)
                    parent.components.set(
                        NectarGatheringComponent(
                            nectarDepotSitePosition: deposit.depotPosition,
                            nectarSources: deposit.nectarSources,
                            speed: deposit.speed,
                            nectarStock: 0,
                            goToDepositAmount: deposit.goToDepositAmount
                        )
                    )
                }
                continue
            }

            // Move to the beehive position
            let here = model.position(relativeTo: nil)
            let distance = simd_distance(here, deposit.depotPosition)

            let moving = parent.components[MoveToComponent.self] != nil
            let arrived = distance <= epsilon && !moving

            if !arrived {
                // Not yet arrived -> ensure a MoveToComponent
                if !moving {
                    #if targetEnvironment(simulator)
                    var strategy: MoveStrategy = .direct
                    #else
                    var strategy: MoveStrategy = .direct

                    if AppState.alwaysUseDirectMovement == false {
                        strategy = .pathfinding
                    }

                    #endif
                    parent.components.set(
                        MoveToComponent(destination: deposit.depotPosition,
                                        speed: deposit.speed,
                                        epsilon: epsilon,
                                        strategy: strategy)
                    )
                    parent.components.set(
                        LookAtTargetComponent(target: .world(deposit.depotPosition))
                    )
                }
                // let MovementSystem manage the move
                continue
            }

            // Arrival: oscillation + countdown
            parent.components.remove(LookAtTargetComponent.self)
            parent.components.remove(MoveToComponent.self) // ensure stopped
            parent.components.set(OscillationComponent(amplitude: 0.03, frequency: 4) // Larger oscillation upon deposition
            )

            deposit.remainingCooldown = deposit.depositDuration
            parent.components.set(deposit)
        }
    }
}
