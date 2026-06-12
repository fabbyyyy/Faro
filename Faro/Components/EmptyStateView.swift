//
//  EmptyStateView.swift
//  Faro
//
//  Estado vacío empático: nunca culpa, siempre orienta el siguiente paso.
//

import SwiftUI

struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(FaroTheme.secondaryText.opacity(0.7))
                .accessibilityHidden(true)
                .faroEntrance(visible: appeared, delay: 0.0)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .faroEntrance(visible: appeared, delay: 0.06)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(FaroTheme.secondaryText)
                .multilineTextAlignment(.center)
                .faroEntrance(visible: appeared, delay: 0.10)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(FaroGlassActionButtonStyle(prominent: true, fullWidth: false))
                    .padding(.top, 6)
                    .faroEntrance(visible: appeared, delay: 0.15)
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity)
        .onAppear { withAnimation { appeared = true } }
    }
}
