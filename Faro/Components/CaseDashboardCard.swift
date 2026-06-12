//
//  CaseDashboardCard.swift
//  Faro
//
//  Tarjeta de acción o estado dentro del dashboard del caso.
//

import SwiftUI

struct CaseDashboardCard: View {
    let symbolName: String
    let title: String
    let subtitle: String
    var badgeCount: Int = 0
    var tint: Color = FaroTheme.night

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(FaroTheme.amber.opacity(0.16))
                    .foregroundStyle(FaroTheme.amber)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(badgeCount) elementos pendientes")
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FaroTheme.secondaryText.opacity(0.6))
                .accessibilityHidden(true)
        }
        .faroCard()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
