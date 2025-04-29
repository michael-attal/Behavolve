//
//  RealityKitHelper.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 27/03/2025.
//

import RealityKit

class RealityKitHelper {
    @available(*, unavailable) private init() {}

    static func snapParentToModel(_ entity: Entity, to model: Entity) {
        entity.transform.translation = model.position(relativeTo: nil)
        entity.transform.rotation = model.orientation(relativeTo: nil)
        let scale = model.transform.scale
        model.transform = Transform(scale: scale,
                                    rotation: .init(),
                                    translation: .zero)
    }

    static func snapParentToPositionWithPosition(_ entity: Entity, to model: Entity, with position: SIMD3<Float>) {
        entity.transform.translation = position
        entity.transform.rotation = model.orientation(relativeTo: nil)

        let scale = model.transform.scale
        model.transform = Transform(scale: scale, rotation: .init(), translation: .zero)
    }
}
