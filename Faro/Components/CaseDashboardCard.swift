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
            iconView

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FaroTheme.amber)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .accessibilityLabel("\(badgeCount) elementos pendientes")
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FaroTheme.secondaryText.opacity(0.45))
            }
        }
        .padding(.horizontal, FaroTheme.cardPadding)
        .padding(.vertical, 14)
        .background(FaroTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var iconView: some View {
        Image(systemName: symbolName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 38, height: 38)
            .background(tint.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}
