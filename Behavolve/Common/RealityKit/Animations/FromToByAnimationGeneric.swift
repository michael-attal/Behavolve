//
//  FromToByAnimationGeneric.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 27/03/2025.
//

import Foundation
import RealityFoundation

extension RealityKitHelper {
    static func fromToByAnimation(
        fromTransform startTransform: Transform = .init(),
        toTransform endTransform: Transform,
        toEntity entity: Entity,
        timing: AnimationTimingFunction = .linear,
        duration: TimeInterval = 5.0,
        loop: Bool = true,
        isAdditive: Bool = false,
        playAutomatically: Bool = true
    ) {
        let transformAction = FromToByAction<Transform>(
            from: startTransform,
            to: endTransform,
            mode: .parent,
            timing: timing,
            isAdditive: isAdditive
        )

        let transformAnimation = try? AnimationResource.makeActionAnimation(
            for: transformAction,
            duration: duration, bindTarget: .transform,
            repeatMode: loop ? .autoReverse : .none
        )

        if let transformAnimation, playAutomatically == true {
            entity.playAnimation(transformAnimation)
        }
    }
}
