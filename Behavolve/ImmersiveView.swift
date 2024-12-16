//
//  ImmersiveView.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import RealityKit
import RealityKitContent
import SwiftUI

struct ImmersiveView: View {
    var body: some View {
        RealityView { content in
            if let immersiveContentEntity = try? await Entity(named: "Scenes/Bee Scene", in: realityKitContentBundle) {
                guard let bee = immersiveContentEntity.findEntity(named: "Flying_Bee") else {
                    print("Could not find Flying_Bee entity")
                    return
                }

                bee.scale = [0.001, 0.001, 0.001]
                bee.position = [0, 1.5, -1.5]

                guard let beeAnimResource = bee.availableAnimations.first else { return }
                let beeFlyingAnim = try! AnimationResource.generate(with: beeAnimResource.repeat().definition)

                bee.playAnimation(beeFlyingAnim)

                content.add(immersiveContentEntity)
            }
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
