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

    @State var currentTopLeftIconSize = CGFloat(140)
    @State var selectedScene: ImmersiveViewAvailable = .bee
    @State private var showingSettings = false

    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if showingSettings {
                SettingsKeysView(onClose: {
                    showingSettings = false
                })
            } else {
                startMenu
            }
        }
        .frame(width: 800, height: 600)
        .edgesIgnoringSafeArea(.all)
        .background(LinearGradient(gradient: Gradient(colors: [.blue, .cyan]), startPoint: .top, endPoint: .bottom))
        .task {
            if AppState.skypStartScreen {
                // Directly open the immersive space
                try? await Task.sleep(for: .milliseconds(500))
                if let step = AppState.skypToStep {
                    // TODO: Refactor the code to make it more generic for future therapies, such as treating ophidiophobia (fear of snakes) ...
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
                    Text("Select your therapy")
                        .font(.largeTitle)
                    VStack {
                        Menu(content: {
                            Picker("Select your therapy", selection: $selectedScene) {
                                ForEach(ImmersiveViewAvailable.getAllImmersiveViews(), id: \.self) { scene in
                                    Text(scene.getFormattedImmersiveViewName())
                                        .font(.largeTitle)
                                }
                            }
                        }, label: {
                            HStack {
                                Spacer()
                                Text(selectedScene.getFormattedImmersiveViewName())
                                    .font(.title)
                                Spacer()
                                Image(systemName: "chevron.down.circle")
                                    .font(.title2)
                            }.frame(width: 225)
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
                            .frame(width: 225)
                    }
                    .controlSize(.extraLarge)
                    .disabled(!(selectedScene == .bee)) // Ftm only bee scene is available

                    Button(action: {
                        showingSettings = true
                    }) {
                        Text("Settings")
                            .font(.title)
                            .frame(width: 225)
                    }.controlSize(.extraLarge)
                }
                .padding()

                // Images at the top-left corner
                Group {
                    Image(systemName: "brain.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 30)
                        // .font(.system(size: 30, weight: .thin))
                        .position(x: 50, y: 50)
                        .foregroundStyle(.white)

                    Image("chamomile-transparent-fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: currentTopLeftIconSize)
                        .position(x: 110, y: 110)
                        .foregroundStyle(.white)

                    Image(systemName: "cross.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 30)
                        // .font(.system(size: 30, weight: .thin))
                        .position(x: 170, y: 50)
                        .foregroundStyle(.white)

                    Image(systemName: "suit.heart.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 30)
                        // .font(.system(size: 30, weight: .thin))
                        .position(x: 170, y: 170)
                        .foregroundStyle(.white)
                }

                // Wave image at position top-right
                WaveView(symbolEffect: .variableColor, symbolEffectOptions: .speed(0.2))
                    .position(x: geometry.size.width - 120, y: 80)

                // Wave image at position middle-left
                WaveView(symbolEffect: .breathe, symbolEffectOptions: .speed(0.2))
                    .position(x: 80, y: geometry.size.height / 2)

                // Wave image at position bottom-left
                WaveView(symbolEffect: .breathe, symbolEffectOptions: .speed(0.2))
                    .position(x: 120, y: geometry.size.height - 120)

                // Wave image at position bottom-right
                WaveView(symbolEffect: .variableColor, symbolEffectOptions: .speed(0.2))
                    .position(x: geometry.size.width - 80, y: geometry.size.height - 80)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: true)) {
                currentTopLeftIconSize += 40
            }
        }
    }
}

struct WaveView<Effect: SymbolEffect & IndefiniteSymbolEffect>: View {
    var symbolEffect: Effect
    var symbolEffectOptions: SymbolEffectOptions = .default
    var width: CGFloat = 40
    var color: Color = .white // .cyan
    var weight: Font.Weight? = .bold // .thin

    var body: some View {
        Image(systemName: "water.waves")
            .resizable()
            .scaledToFit()
            .frame(height: width)
            .font(.system(size: width, weight: weight))
            .symbolEffect(symbolEffect, options: symbolEffectOptions)
            .padding()
            .foregroundStyle(color)
    }
}

struct SettingsKeysView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    @State private var openAIToken: String
    @State private var organizationID: String

    var onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        _openAIToken = State(initialValue:
            UserDefaults.standard.string(forKey: "OPENAI_TOKEN") ?? AppState.OPENAI_TOKEN
        )
        _organizationID = State(initialValue:
            UserDefaults.standard.string(forKey: "OPENAI_ORGANIZATION_ID") ?? AppState.OPENAI_ORGANIZATION_ID
        )
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("API Configuration")
                .font(.largeTitle)
                .bold()

            TextField("OpenAI Token", text: $openAIToken)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Organization ID", text: $organizationID)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                openURL(URL(string: "https://platform.openai.com/account/api-keys")!)
            } label: {
                Text("Get your key at platform.openai.com")
                    .font(.callout)
                    .underline()
            }

            HStack(spacing: 40) {
                Button("Back") {
                    onClose()
                }
                .controlSize(.large)

                Button("Save") {
                    AppState.OPENAI_TOKEN = openAIToken
                    AppState.OPENAI_ORGANIZATION_ID = organizationID
                    UserDefaults.standard.set(openAIToken, forKey: "OPENAI_TOKEN")
                    UserDefaults.standard.set(organizationID, forKey: "OPENAI_ORGANIZATION_ID")
                    onClose()
                }
                .controlSize(.large)
                .disabled(openAIToken.isEmpty || organizationID.isEmpty)
            }
        }
        .padding(40)
        .frame(minWidth: 450)
    }
}

#Preview(windowStyle: .automatic) {
    MenuView()
        .environment(AppState())
}
