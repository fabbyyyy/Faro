//
//  TimelineEventCard.swift
//  Faro
//
//  Tarjeta de un evento del timeline con hora, fuente,
//  confianza y estado de validación.
//

import SwiftUI

struct TimelineEventCard: View {
    let event: TimelineEvent
    /// Verdadero cuando este evento participa en una contradicción de horario.
    var isConflicting: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Columna de hora
            VStack(spacing: 2) {
                Text(event.date, format: .dateTime.hour().minute())
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(event.date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(FaroTheme.secondaryText)
            }
            .frame(width: 58)

            RoundedRectangle(cornerRadius: 2)
                .fill(FaroTheme.color(for: event.validationState).opacity(0.5))
                .frame(width: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if !event.details.isEmpty {
                    Text(event.details)
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    ValidationBadge(state: event.validationState)
                    ConfidenceBadge(level: event.confidence)
                }

                Text("Fuente: \(event.source.displayName)")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)

                if isConflicting {
                    Label("Hay dos horarios distintos. Revisa cuál está confirmado.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(FaroTheme.amber)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FaroTheme.amber.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
                        .accessibilityLabel("Atención: hay dos horarios distintos para este momento. Revisa cuál está confirmado.")
                }
            }
        }
        .faroCard()
    }
}
