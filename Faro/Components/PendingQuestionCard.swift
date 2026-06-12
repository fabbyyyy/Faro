//
//  PendingQuestionCard.swift
//  Faro
//
//  Tarjeta de pregunta crítica con acciones de estado.
//

import SwiftUI

struct PendingQuestionCard: View {
    @Bindable var question: CaseQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.text)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .strikethrough(question.state == .notApplicable)

            if !question.whyItMatters.isEmpty {
                Text(question.whyItMatters)
                    .font(.subheadline)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if question.state == .resolved && !question.answer.isEmpty {
                Text("Respuesta: \(question.answer)")
                    .font(.subheadline)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FaroTheme.confirmedGreen.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
            }

            HStack {
                statusLabel
                Spacer()
                Menu {
                    Button("Marcar como resuelta") { question.state = .resolved }
                    Button("Marcar como pendiente") { question.state = .pending }
                    Button("No aplica") { question.state = .notApplicable }
                } label: {
                    Label("Cambiar estado", systemImage: "ellipsis.circle")
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.night)
                }
                .accessibilityLabel("Cambiar estado de la pregunta. Estado actual: \(question.state.displayName)")
            }
        }
        .faroCard()
        .opacity(question.state == .notApplicable ? 0.6 : 1)
    }

    private var statusLabel: some View {
        let (text, color): (String, Color) = {
            switch question.state {
            case .pending:       return ("Pendiente", FaroTheme.amber)
            case .resolved:      return ("Resuelta", FaroTheme.confirmedGreen)
            case .notApplicable: return ("No aplica", FaroTheme.secondaryText)
            }
        }()
        return Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
