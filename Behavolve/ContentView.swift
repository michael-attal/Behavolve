//
//  ContentView.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import RealityKit
import RealityKitContent
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Model3D(named: "Models/Bee/Flying_Bee", bundle: realityKitContentBundle) { phase in
                phase.model?.resizable()
            }
            .scaledToFit()
            .frame(height: 100)
            .padding(.bottom, 50)

            Text("Behavolve")

            ToggleImmersiveSpaceButton()
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
