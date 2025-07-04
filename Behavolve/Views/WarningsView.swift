//
//  WarningsView.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 04/07/2025.
//

import RealityKit
import SwiftUI

struct WarningsView: View {
    @Environment(AppState.self) private var appState

    let warningsText: String
    let warningsTextID: UUID

    @State private var timer: Timer?
    @State private var isVisible: Bool = false

    var body: some View {
        VStack {
            Text(warningsText)
                .frame(maxWidth: 1000, alignment: .leading)
                .font(.extraLargeTitle2)
                .fontWeight(.regular)
                .padding(40)
                .foregroundStyle(.red)
                .glassBackgroundEffect()
        }
        .opacity(isVisible ? 1 : 0)
        .onChange(of: warningsTextID) { _, _ in // <- React to ID change
            timer?.invalidate()

            guard !warningsText.isEmpty else {
                isVisible = false
                return
            }

            isVisible = true

            timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                withAnimation {
                    isVisible = false
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
}
