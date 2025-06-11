//
//  FromToByAnimationScaling.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 27/03/2025.
//

import Foundation
import RealityKit

extension RealityKitHelper {
    static func fromToByAnimationScaling(
        fromScale initialScale: SIMD3<Float> = .one,
        toScale finalScale: SIMD3<Float>,
        toEntity entity: Entity,
        timing: AnimationTimingFunction = .linear,
        duration: TimeInterval = 5.0,
        loop: Bool = true,
        isAdditive: Bool = false,
        playAutomatically: Bool = true
    ) {
        let finalScaleTransform = Transform(scale: finalScale, rotation: entity.orientation, translation: entity.position)
        fromToByAnimation(fromTransform: entity.transform, toTransform: finalScaleTransform, toEntity: entity, timing: timing, duration: duration, loop: loop, isAdditive: isAdditive, playAutomatically: playAutomatically)
    }
}
