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
    @Environment(AppModel.self) private var appModel

    @State var currentSunIconSize = CGFloat(90)
    @State var selectedScene: ImmersiveViewAvailable = .bee

    var body: some View {
        Group {
            if appModel.currentImmersiveView == .none {
                startMenu.frame(width: 800, height: 600)
            } else {
                // TODO: Do each menu for each scene
                beeMenu.frame(width: 350, height: 400)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .background(
            LinearGradient(gradient: Gradient(colors: [.blue, .cyan]), startPoint: .top, endPoint: .bottom)
        )
    }

    var startMenu: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    Text("Selected scene")
                        .font(.largeTitle)
                    VStack {
                        Menu(content: {
                            Picker("Selected scene", selection: $selectedScene) {
                                ForEach(ImmersiveViewAvailable.getAllImmersiveViews(), id: \.self) { scene in
                                    Text(scene.rawValue.capitalized)
                                        .font(.largeTitle)
                                }
                            }
                        }, label: {
                            HStack {
                                Spacer()
                                Text(selectedScene.rawValue.capitalized)
                                    .font(.title)
                                Spacer()
                                Image(systemName: "chevron.down.circle")
                                    .font(.title2)
                            }.frame(width: 200)
                        }).controlSize(.extraLarge)
                    }

                    ToggleImmersiveSpaceButtonView(forImmersiveView: selectedScene, sizeButton: 200, fontButton: .title)

                    Button(action: {}) {
                        Text("Settings")
                            .font(.title)
                            .frame(width: 200)
                    }.controlSize(.extraLarge)
                }
                .padding()

                // Sun image at the top-left corner
                Image(systemName: "sun.max")
                    .resizable()
                    .frame(width: currentSunIconSize, height: currentSunIconSize)
                    .position(x: 110, y: 110)
                    .foregroundStyle(.yellow)

                // Wave image at position top-right
                WaveView(symbolEffect: .variableColor, symbolEffectOptions: .speed(0.2), color: .blue)
                    .position(x: geometry.size.width - 120, y: 80)

                // Wave image at position middle-left
                WaveView(symbolEffect: .breathe, symbolEffectOptions: .speed(0.2))
                    .position(x: 80, y: geometry.size.height / 2)

                // Wave image at position bottom-left
                WaveView(symbolEffect: .breathe, symbolEffectOptions: .speed(0.2), color: .blue)
                    .position(x: 120, y: geometry.size.height - 120)

                // Wave image at position bottom-right
                WaveView(symbolEffect: .variableColor, symbolEffectOptions: .speed(0.2))
                    .position(x: geometry.size.width - 80, y: geometry.size.height - 80)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: true)) {
                currentSunIconSize += 40
            }
        }
    }

    var beeMenu: some View {
        GeometryReader { geometry in
            ZStack {
                Button(action: {
                    appModel.currentImmersiveView = .none
                }) {
                    Text("Exit")
                }.position(x: geometry.size.width - 60, y: 40)
                VStack {
                    Button(action: {}) {
                        Text("I'm ready")
                    }
                }
            }
        }
    }
}

struct WaveView<Effect: SymbolEffect & IndefiniteSymbolEffect>: View {
    var symbolEffect: Effect
    var symbolEffectOptions: SymbolEffectOptions = .default

    var color: Color = .cyan

    var body: some View {
        Image(systemName: "water.waves")
            .resizable()
            .frame(width: 50, height: 50)
            .symbolEffect(symbolEffect, options: symbolEffectOptions)
            .padding()
            .foregroundStyle(color)
    }
}

#Preview(windowStyle: .automatic) {
    MenuView()
        .environment(AppModel())
}
