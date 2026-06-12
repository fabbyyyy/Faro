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
                    FaroSectionHeader(
                        title: "Por qué esta tecnología",
                        subtitle: "Una decisión de diseño, no un detalle técnico."
                    )
                    Text("FARO usa inteligencia artificial **en el dispositivo** porque los datos de una familia son sensibles y no deben viajar a servidores. Cuando el sistema lo permite, usamos los modelos locales de Apple (Foundation Models) para entender lenguaje en crisis y redactar con calma. Si no están disponibles, un **asistente local determinista** mantiene la app completa y funcional, incluso sin conexión. La interfaz siempre indica qué motor está activo.")
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("La extracción de datos es determinista a propósito: un modelo generativo puede sugerir y organizar, pero **no decide los hechos de un expediente**. Por eso todo lo que produce la IA entra como pendiente y requiere tu validación antes de tratarse como confirmado.")
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .faroCard()

                NavigationLink {
                    AIArchitectureView()
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "cpu")
                            .font(.title3)
                            .foregroundStyle(FaroTheme.night)
                            .frame(width: 34)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arquitectura de IA")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Cómo funciona la IA de FARO: qué decide un modelo y qué deciden reglas auditables.")
                                .font(.subheadline)
                                .foregroundStyle(FaroTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(FaroTheme.secondaryText.opacity(0.5))
                            .accessibilityHidden(true)
                    }
                    .faroCard()
                    .contentShape(Rectangle())
                }
                .buttonStyle(FaroCardButtonStyle())
                .accessibilityHint("Abre la explicación de la arquitectura de IA")

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
