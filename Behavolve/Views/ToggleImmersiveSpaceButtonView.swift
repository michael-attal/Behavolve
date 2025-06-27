//
//  ToggleImmersiveSpaceButton.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import SwiftUI

struct ToggleImmersiveSpaceButtonView: View {
    @Environment(AppState.self) private var appState

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow

    var immersiveView: ImmersiveViewAvailable = .none
    var startText: String
    var endText: String
    var sizeButton: CGFloat
    var fontButton: Font

    init(forImmersiveView: ImmersiveViewAvailable, startText: String = "Begin", endText: String = "End", sizeButton: CGFloat = 200, fontButton: Font = .title) {
        self.immersiveView = forImmersiveView
        self.startText = startText
        self.endText = endText
        self.sizeButton = sizeButton
        self.fontButton = fontButton
    }

    var body: some View {
        Button {
            appState.currentImmersiveView = immersiveView
            Task { @MainActor in
                switch appState.immersiveSpaceState {
                    case .open:
                        appState.immersiveSpaceState = .inTransition
                        await dismissImmersiveSpace()

                    case .closed:
                        appState.immersiveSpaceState = .inTransition
                        switch await openImmersiveSpace(id: appState.immersiveSpaceID) {
                            case .opened:
                                dismissWindow(id: appState.MenuWindowID)
                                openWindow(id: appState.ConversationWindowID)
                                appState.exitWordDetected = false

                            case .userCancelled, .error:
                                fallthrough

                            @unknown default:
                                appState.immersiveSpaceState = .closed
                                appState.currentImmersiveView = .none
                        }

                    case .inTransition:
                        break
                }
            }
        } label: {
            Text(appState.immersiveSpaceState == .open ? endText : startText)
                .font(.title)
                .frame(width: sizeButton)
        }
        .controlSize(.extraLarge)
        .disabled(appState.immersiveSpaceState == .inTransition)
        .animation(.none, value: 0)
        .fontWeight(.semibold)
    }
}
