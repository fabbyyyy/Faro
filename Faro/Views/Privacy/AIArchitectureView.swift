//
//  AIArchitectureView.swift
//  Faro
//
//  Arquitectura de IA, en lenguaje claro y visible para quien evalúa.
//  La idea central: la IA organiza y sugiere; nunca decide los hechos.
//  Cada módulo usa la herramienta correcta: modelo donde aporta lenguaje,
//  reglas deterministas donde está en juego la exactitud o la seguridad.
//

import SwiftUI

struct AIArchitectureView: View {

    private let services = AppServices.shared

    /// Tipo de motor de cada módulo. El color nunca es el único canal:
    /// siempre hay texto e ícono.
    private enum Engine {
        case rules
        case hybrid

        var label: String {
            switch self {
            case .rules:  return "Reglas deterministas"
            case .hybrid: return "Modelo + reglas"
            }
        }
        var symbol: String {
            switch self {
            case .rules:  return "function"
            case .hybrid: return "sparkles"
            }
        }
        var tint: Color {
            switch self {
            case .rules:  return FaroTheme.night
            case .hybrid: return FaroTheme.amber
            }
        }
    }

    private struct Module: Identifiable {
        let id = UUID()
        let symbol: String
        let name: String
        let role: String
        let engine: Engine
    }

    private let modules: [Module] = [
        Module(symbol: "ear", name: "Intake",
               role: "Entiende lo que escribes, incluso bajo estrés o un \"no sé\".",
               engine: .hybrid),
        Module(symbol: "text.append", name: "Formalizador",
               role: "Convierte lo informal en lenguaje técnico de ficha.",
               engine: .rules),
        Module(symbol: "lock.shield", name: "Sensibilidad",
               role: "Detecta datos sensibles (salud, testimonios, conversaciones).",
               engine: .hybrid),
        Module(symbol: "clock.arrow.circlepath", name: "Línea de tiempo",
               role: "Ordena momentos y detecta huecos sin información.",
               engine: .rules),
        Module(symbol: "exclamationmark.triangle", name: "Contradicciones",
               role: "Detecta respuestas en conflicto y pregunta cuál confirmar.",
               engine: .rules),
        Module(symbol: "questionmark.circle", name: "Preguntas",
               role: "Decide qué falta y qué conviene preguntar después.",
               engine: .rules),
        Module(symbol: "doc.text", name: "Documentos",
               role: "Compone la ficha técnica y el reporte formal.",
               engine: .hybrid),
        Module(symbol: "hand.raised", name: "Filtro ético",
               role: "Decide qué nunca se publica, con una razón visible.",
               engine: .rules)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FaroTheme.sectionSpacing) {
                principleCard
                layersCard
                modulesSection
                perceptionCard
                invariantCard
                engineCard
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Arquitectura de IA")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Principio

    private var principleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            FaroSectionHeader(title: "La IA organiza, no decide")
            Text("FARO usa inteligencia artificial **en el dispositivo** para entender lenguaje humano en crisis y convertirlo en información estructurada. Pero ningún dato crítico se trata como hecho sin tu validación.")
                .font(.subheadline)
                .foregroundStyle(FaroTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .faroCard()
    }

    // MARK: - Dos capas

    private var layersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            FaroSectionHeader(
                title: "Un sistema híbrido",
                subtitle: "Modelo generativo donde aporta lenguaje; reglas donde importa la exactitud."
            )
            Text("Cuando el sistema lo permite, FARO usa los modelos locales de Apple (Foundation Models). Si no están disponibles, un asistente local determinista mantiene la app completa, incluso sin conexión. **La extracción de datos siempre es determinista**: un modelo no debe inventar el dato de una familia, solo suaviza la redacción.")
                .font(.subheadline)
                .foregroundStyle(FaroTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .faroCard()
    }

    // MARK: - Módulos

    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FaroSectionHeader(
                title: "Ocho módulos especializados",
                subtitle: "Cada uno usa el motor correcto para su tarea."
            )
            ForEach(modules) { module in
                moduleRow(module)
            }
            legend
        }
    }

    private func moduleRow(_ module: Module) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: module.symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FaroTheme.night)
                .frame(width: 34, height: 34)
                .background(FaroTheme.night.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(module.name)
                    .font(.subheadline.weight(.semibold))
                Text(module.role)
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                engineTag(module.engine)
            }
            Spacer(minLength: 0)
        }
        .faroCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(module.name). \(module.role) Motor: \(module.engine.label).")
    }

    private func engineTag(_ engine: Engine) -> some View {
        Label(engine.label, systemImage: engine.symbol)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(engine.tint.opacity(0.14))
            .foregroundStyle(engine.tint)
            .clipShape(Capsule())
    }

    private var legend: some View {
        HStack(spacing: 14) {
            engineTag(.rules)
            engineTag(.hybrid)
            Spacer()
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    // MARK: - Percepción (OCR / Voz)

    private var perceptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            FaroSectionHeader(title: "Lectura de capturas y voz")
            Text("El texto de las capturas se extrae con **Vision OCR** y las notas de voz se transcriben con **Speech**, todo en el dispositivo. Lo detectado entra como sugerencia, siempre pendiente de tu revisión.")
                .font(.subheadline)
                .foregroundStyle(FaroTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .faroCard()
    }

    // MARK: - Regla no negociable

    private var invariantCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            FaroSectionHeader(title: "Regla no negociable")
            Text("Todo lo que produce la IA entra al expediente como **pendiente de revisar**. Solo una persona lo confirma, lo marca como aproximado, lo edita o lo descarta. Además, cada dato lleva su confianza por origen: una captura original pesa más que un rumor.")
                .font(.subheadline)
                .foregroundStyle(FaroTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            AISuggestionBadge()
        }
        .faroCard()
    }

    // MARK: - Motor activo (dato en vivo para la demo)

    private var engineCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cpu")
                .font(.title3)
                .foregroundStyle(FaroTheme.night)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Motor activo ahora")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FaroTheme.secondaryText)
                Text(services.ai.engineName)
                    .font(.subheadline.weight(.medium))
                Text(services.ai.isOnDeviceModelAvailable
                     ? "Modelos de Apple disponibles en este dispositivo."
                     : "Usando el asistente local determinista (sin Apple Intelligence).")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .faroCard()
        .accessibilityElement(children: .combine)
    }
}
