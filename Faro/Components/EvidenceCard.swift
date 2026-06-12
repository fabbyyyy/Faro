//
//  EvidenceCard.swift
//  Faro
//
//  Tarjeta de una evidencia del Vault, con tipo, sensibilidad
//  y estado de validación siempre visibles.
//

import SwiftUI

struct EvidenceCard: View {
    let evidence: EvidenceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: evidence.kind.symbolName)
                    .font(.system(size: 17)) // Tamaño fijo: el ícono decorativo no debe desbordar su recuadro con texto grande.
                    .foregroundStyle(FaroTheme.night)
                    .frame(width: 32, height: 32)
                    .background(FaroTheme.night.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(evidence.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(evidence.kind.displayName + (evidence.source.isEmpty ? "" : " · \(evidence.source)"))
                        .font(.caption)
                        .foregroundStyle(FaroTheme.secondaryText)
                }
                Spacer()
            }

            if !evidence.details.isEmpty {
                Text(evidence.details)
                    .font(.subheadline)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                SensitivityBadge(level: evidence.sensitivity)
                ValidationBadge(state: evidence.validationState)
                ConfidenceBadge(level: evidence.kind.sourceConfidence)
                if evidence.classificationSuggestedByAI {
                    AISuggestionBadge()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .faroCard()
    }
}
