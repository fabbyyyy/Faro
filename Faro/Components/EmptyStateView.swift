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

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(FaroTheme.secondaryText)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(FaroTheme.secondaryText)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(FaroSecondaryButtonStyle(fullWidth: false))
                    .padding(.top, 6)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity)
    }
}
