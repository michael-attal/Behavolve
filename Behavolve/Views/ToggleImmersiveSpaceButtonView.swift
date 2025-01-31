//
//  ToggleImmersiveSpaceButton.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 28/10/2024.
//

import SwiftUI

struct ToggleImmersiveSpaceButtonView: View {
    @Environment(AppModel.self) private var appModel

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow

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
            appModel.currentImmersiveView = immersiveView
            Task { @MainActor in
                switch appModel.immersiveSpaceState {
                    case .open:
                        appModel.immersiveSpaceState = .inTransition
                        await dismissImmersiveSpace()

                    case .closed:
                        appModel.immersiveSpaceState = .inTransition
                        switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                            case .opened:
                                dismissWindow(id: appModel.MenuWindowID)

                            case .userCancelled, .error:
                                fallthrough

                            @unknown default:
                                appModel.immersiveSpaceState = .closed
                                appModel.currentImmersiveView = .none
                        }

                    case .inTransition:
                        break
                }
            }
        } label: {
            Text(appModel.immersiveSpaceState == .open ? endText : startText)
                .font(.title)
                .frame(width: sizeButton)
        }
        .controlSize(.extraLarge)
        .disabled(appModel.immersiveSpaceState == .inTransition)
        .animation(.none, value: 0)
        .fontWeight(.semibold)
    }
}
