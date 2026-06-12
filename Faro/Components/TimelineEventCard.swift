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

    private var formattedTime: String {
        event.date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    }

    private var amPMLabel: String {
        Calendar.current.component(.hour, from: event.date) < 12 ? "a.m." : "p.m."
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Columna de hora
            VStack(spacing: 2) {
                Text(formattedTime)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .fixedSize()
                Text(amPMLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(FaroTheme.secondaryText)
                Text(event.date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(FaroTheme.secondaryText)
            }
            .frame(width: 54)

            // Línea de estado con indicador de color accesible
            Capsule()
                .fill(FaroTheme.color(for: event.validationState).opacity(0.55))
                .frame(width: 4)
                .padding(.horizontal, 8)
                .frame(maxHeight: .infinity)
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

                FlowLayout(spacing: 8, lineSpacing: 8) {
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
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                        .accessibilityLabel("Atención: hay dos horarios distintos para este momento. Revisa cuál está confirmado.")
                }
            }
        }
        .faroCard()
    }
}
