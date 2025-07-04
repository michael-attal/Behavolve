//
//  NectarDepositComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 23/04/2025.
//

import Foundation
import RealityKit

/// Attach to the bee when its sac is full so it can fly to the hive,
/// oscillate while unloading, then resume foraging.
struct NectarDepositComponent: Component, Sendable {
    /// World‑space position of the hive entrance.
    var depotPosition: SIMD3<Float>

    /// Nectar sources of the known flowers so we can rebuild a new
    /// `NectarGatheringComponent` afterwards.
    var nectarSources: [NectarSource]

    /// Flight speed in metres per second.
    var speed: Float

    /// Amount of nectar currently carried (for analytics / UI).
    var carriedNectar: Int

    var goToDepositAmount: Int

    /// Duration of the unloading animation in seconds.
    var depositDuration: TimeInterval = 2.0

    /// Internal countdown used by `NectarDepositSystem` (seconds left).
    /// Zero when the bee is still in flight.
    var remainingCooldown: TimeInterval = 0.0

    init(depotPosition: SIMD3<Float>,
         nectarSources: [NectarSource],
         speed: Float,
         carriedNectar: Int,
         depositDuration: TimeInterval = 2.0,
         goToDepositAmount: Int)
    {
        self.depotPosition = depotPosition
        self.nectarSources = nectarSources
        self.speed = speed
        self.carriedNectar = carriedNectar
        self.depositDuration = depositDuration
        self.remainingCooldown = 0.0
        self.goToDepositAmount = goToDepositAmount
    }
}
