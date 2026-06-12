//
//  OnboardingView.swift
//  Faro
//
//  Bienvenida al estilo de las hojas "What's New" de Apple.
//  Se muestra una sola vez, en el primer arranque de la app.
//

import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void
    @State private var appeared = false

    private let features: [(symbol: String, title: String, detail: String)] = [
        ("square.stack.3d.up",
         "Organiza las primeras horas",
         "Reúne datos, evidencia y línea de tiempo de una persona desaparecida en un solo expediente, paso a paso."),
        ("sparkles",
         "Con ayuda de IA en tu dispositivo",
         "Beacon te guía conversando y organiza lo que cuentes. Todo lo que sugiere queda pendiente hasta que tú lo confirmes."),
        ("lock.shield",
         "Tu información, solo tuya",
         "Todo se guarda únicamente en este dispositivo. Nada se sube a internet y tú decides qué se comparte y qué no."),
        ("building.columns",
         "No reemplaza a las autoridades",
         "FARO te ayuda a preparar carteles y reportes claros, pero la denuncia y la búsqueda oficial siguen siendo de las autoridades.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Te damos la bienvenida a FARO")
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 56)
                .padding(.bottom, 36)
                .accessibilityAddTraits(.isHeader)
                .faroEntrance(visible: appeared, delay: 0.0)

            VStack(alignment: .leading, spacing: 28) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    featureRow(feature)
                        .faroEntrance(visible: appeared, delay: Double(index) * 0.08 + 0.1)
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continuar")
            }
            .buttonStyle(FaroPrimaryButtonStyle())
            .padding(.bottom, 20)
            .faroEntrance(visible: appeared, delay: 0.45)
        }
        .padding(.horizontal, 28)
        .background(FaroTheme.background)
        .onAppear { withAnimation { appeared = true } }
    }

    private func featureRow(_ feature: (symbol: String, title: String, detail: String)) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: feature.symbol)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(FaroTheme.night)
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.headline)
                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
