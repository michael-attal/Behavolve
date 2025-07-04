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
    @Environment(AppState.self) private var appState

    @State var currentSunIconSize = CGFloat(90)
    @State var selectedScene: ImmersiveViewAvailable = .bee

    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        startMenu
            .frame(width: 800, height: 600)
            .edgesIgnoringSafeArea(.all)
            .background(
                LinearGradient(gradient: Gradient(colors: [.blue, .cyan]), startPoint: .top, endPoint: .bottom)
            ).task {
                if AppState.skypStartScreen {
                    // Directly open the immersive space
                    try? await Task.sleep(for: .milliseconds(500))
                    if let step = AppState.skypToStep {
                        appState.beeSceneState.step.isCurrentStepConfirmed = false
                        appState.beeSceneState.step = step
                        if AppState.byPassConfirmationStep == true {
                            Task {
                                try? await Task.sleep(for: .milliseconds(2000))
                                appState.beeSceneState.step.isCurrentStepConfirmed = true
                            }
                        }
                    }
                    if AppState.skypSurveyStep == false {
                        openWindow(id: appState.BeeScenePreSessionAssessmentWindowID)
                    } else {
                        appState.handleBeginTherapy(immersiveView: .bee, researchKitQuestionnaireWindowID: appState.BeeScenePreSessionAssessmentWindowID, openImmersiveSpace: openImmersiveSpace, dismissImmersiveSpace: dismissImmersiveSpace, openWindow: openWindow, dismissWindow: dismissWindow)
                    }
                }
            }
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

                    Button {
                        switch selectedScene {
                        case .none:
                            print("Please select a scene")
                        case .bee:
                            if AppState.skypSurveyStep {
                                appState.handleBeginTherapy(immersiveView: .bee, researchKitQuestionnaireWindowID: appState.BeeScenePreSessionAssessmentWindowID, openImmersiveSpace: openImmersiveSpace, dismissImmersiveSpace: dismissImmersiveSpace, openWindow: openWindow, dismissWindow: dismissWindow)
                            } else {
                                openWindow(id: appState.BeeScenePreSessionAssessmentWindowID)
                            }
                        case .snake:
                            print("Not implemented yet")
                        }
                    } label: {
                        Text("Start")
                            .font(.title)
                            .frame(width: 200)
                    }.controlSize(.extraLarge)

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
        .environment(AppState())
}
