//
//  ContentView.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import RealityKit
import RealityKitContent
import SwiftUI

struct MenuView: View {
    var body: some View {
        startMenu
    }
    
    var startMenu: some View {
        VStack {
            Text("Behavolve")

            ToggleImmersiveSpaceButtonView(forImmersiveView: .bee)
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    MenuView()
        .environment(AppModel())
}
