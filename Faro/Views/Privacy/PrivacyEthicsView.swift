//
//  PrivacyEthicsView.swift
//  Faro
//
//  Compromisos de privacidad y límites éticos, en lenguaje claro.
//  Decir lo que la app NO hace es parte del diseño.
//

import SwiftUI

struct PrivacyEthicsView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FaroTheme.sectionSpacing) {

                FaroSectionHeader(
                    title: "Tu información, tus reglas",
                    subtitle: "FARO está diseñada para proteger a tu familia, no para recolectar datos."
                )

                VStack(spacing: 12) {
                    promiseCard(
                        symbol: "iphone.and.arrow.down",
                        title: "Todo se guarda en este dispositivo",
                        text: "El expediente vive en la base de datos local (SwiftData). No hay servidores de FARO, no hay cuentas, no hay nube obligatoria."
                    )
                    promiseCard(
                        symbol: "hand.raised",
                        title: "Tú controlas qué se comparte",
                        text: "Nada sale de la app sin una acción tuya. La ficha pública requiere aprobación explícita de la familia."
                    )
                    promiseCard(
                        symbol: "sparkles",
                        title: "La IA asiste, no decide",
                        text: "Los modelos trabajan en el dispositivo. Sugieren, resumen y clasifican, pero cada dato importante requiere tu validación."
                    )
                    promiseCard(
                        symbol: "eye.slash",
                        title: "Sin venta de datos, sin publicidad",
                        text: "FARO no monetiza la información de las familias. Nunca."
                    )
                    promiseCard(
                        symbol: "scalemass",
                        title: "FARO no acusa ni predice",
                        text: "La app no identifica culpables, no predice ubicaciones y no valida pruebas legalmente. Organiza información, nada más."
                    )
                    promiseCard(
                        symbol: "building.columns",
                        title: "No sustituye procesos oficiales",
                        text: "Denuncias, protocolos de búsqueda y acompañamiento legal corresponden a autoridades, colectivos y profesionales. FARO prepara la información para que ese camino sea menos pesado."
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    FaroSectionHeader(title: "Protección de campos sensibles")
                    Text("Los datos marcados como sensibles (información médica, testimonios, conversaciones privadas) se excluyen automáticamente de fichas y difusión. La arquitectura está preparada para cifrar estos campos con CryptoKit en una versión futura; en este MVP la protección se basa en separación estricta de lo público y lo privado, y en que nada sale del dispositivo.")
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .faroCard()

                VStack(alignment: .leading, spacing: 8) {
                    FaroSectionHeader(title: "Uso responsable")
                    Text("No publiques rumores ni datos sin confirmar. No difundas información de testigos. Revisa cada documento antes de compartirlo. FARO te acompaña a hacerlo con cuidado, pero la decisión siempre es de la familia.")
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .faroCard()
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Privacidad y ética")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func promiseCard(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(FaroTheme.night)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .faroCard()
        .accessibilityElement(children: .combine)
    }
}
