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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                progressHeader
                    .padding(.bottom, 22)

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
                        .padding(.bottom, 24)
                } else {
                    Spacer().frame(height: 24)
                }

                content
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 32)

                skipActions
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Barra de progreso visual

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Paso \(step) de \(totalSteps)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(FaroTheme.secondaryText)
                Spacer()
                Text("\(Int(round(Double(step) / Double(totalSteps) * 100)))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(FaroTheme.secondaryText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Paso \(step) de \(totalSteps). Puedes saltar cualquier pregunta.")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FaroTheme.secondaryText.opacity(0.14))
                        .frame(height: 5)
                    Capsule()
                        .fill(FaroTheme.night)
                        .frame(
                            width: max(5, geo.size.width * CGFloat(step) / CGFloat(totalSteps)),
                            height: 5
                        )
                        .animation(FaroTheme.springSmooth, value: step)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Acciones de escape sin culpa

    private var skipActions: some View {
        VStack(spacing: 4) {
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
        .padding(.bottom, 8)
    }
}
