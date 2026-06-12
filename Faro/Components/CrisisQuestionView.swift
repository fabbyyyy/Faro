//
//  CrisisQuestionView.swift
//  Faro
//
//  Una sola pregunta por pantalla. Tipografía grande, opciones claras,
//  y siempre dos salidas sin culpa: "No lo sé todavía" y "Saltar por ahora".
//

import SwiftUI

/// Contenedor visual de cada paso del Modo Crisis.
struct CrisisQuestionView<Content: View>: View {
    let step: Int
    let totalSteps: Int
    let question: String
    var hint: String?
    let onSkip: () -> Void
    var onDontKnow: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progreso discreto: orienta sin presionar.
            Text("Paso \(step) de \(totalSteps)")
                .font(.footnote)
                .foregroundStyle(FaroTheme.secondaryText)
                .padding(.bottom, 10)
                .accessibilityLabel("Paso \(step) de \(totalSteps). Puedes saltar cualquier pregunta.")

            Text(question)
                .font(.largeTitle.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)

            if let hint {
                Text(hint)
                    .font(.body)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)
            } else {
                Spacer().frame(height: 18)
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 16)

            VStack(spacing: 6) {
                if let onDontKnow {
                    Button("No lo sé todavía", action: onDontKnow)
                        .buttonStyle(FaroQuietButtonStyle())
                        .accessibilityHint("Guarda esta pregunta como pendiente y continúa")
                }
                Button("Saltar por ahora", action: onSkip)
                    .buttonStyle(FaroQuietButtonStyle())
                    .accessibilityHint("Continúa sin responder. Puedes completar esto después.")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(FaroTheme.screenPadding)
    }
}
