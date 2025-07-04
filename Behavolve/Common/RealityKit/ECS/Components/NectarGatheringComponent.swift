//
//  NectarGatheringComponent.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 23/04/2025.
//

import Foundation
import RealityKit

struct NectarSource: Hashable, Sendable {
    static let fullStock: Int = 300 // capacity
    static let defaultReloadDuration: TimeInterval = 20

    let position: SIMD3<Float>

    /// Used to restock when stock is <= 0 and reloadTimeRemaining has passed.
    let initialStock: Int

    var stock: Int
    let reloadDuration: TimeInterval
    var reloadTimeRemaining: TimeInterval // handled by system

    init(position: SIMD3<Float>,
         stock: Int = NectarSource.fullStock,
         reloadDuration: TimeInterval = NectarSource.defaultReloadDuration,
         reloadTimeRemaining: TimeInterval = 0)
    {
        self.position = position
        self.initialStock = stock
        self.stock = stock
        self.reloadDuration = reloadDuration
        self.reloadTimeRemaining = reloadTimeRemaining
    }

    /// `true` iff the flower can be visited now.
    var isAvailable: Bool { stock > 0 && reloadTimeRemaining == 0 }

    /// Tick the countdown; when finished, refill the stock.
    mutating func updateCooldown(dt: TimeInterval) {
        // Count down only while reloading
        guard reloadTimeRemaining > 0 else { return }

        reloadTimeRemaining -= dt
        if reloadTimeRemaining <= 0 {
            reloadTimeRemaining = 0
            stock = initialStock // full again
        }
    }
}

struct NectarGatheringComponent: Component, Sendable {
    var nectarDepotSitePosition: SIMD3<Float>
    var nectarSources: [NectarSource]
    var nectarStock: Int = 0 // carried
    var speed: Float
    var gatheringCooldown: TimeInterval = 3.0
    var goToDepositAmount: Int

    /// Index of the flower visited at last foraging (nil if none).
    var lastVisitedIndex: Int? = nil

    init(nectarDepotSitePosition: SIMD3<Float>,
         nectarSources: [NectarSource],
         speed: Float,
         nectarStock: Int = 0,
         gatheringCooldown: TimeInterval = 3.0,
         goToDepositAmount: Int)
    {
        self.nectarDepotSitePosition = nectarDepotSitePosition
        self.nectarSources = nectarSources
        self.speed = speed
        self.nectarStock = nectarStock
        self.gatheringCooldown = gatheringCooldown
        self.goToDepositAmount = goToDepositAmount
    }
}

///  Bee foraging on a flower, it take some time to gather nectar.
struct NectarGatheringCooldownComponent: Component, Sendable {
    var remainingCooldown: TimeInterval
}
