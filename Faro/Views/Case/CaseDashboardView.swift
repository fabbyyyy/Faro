//
//  CaseDashboardView.swift
//  Faro
//
//  Estado general del expediente: persona, completitud orientativa,
//  acciones recomendadas y acceso a cada módulo.
//

import SwiftUI
import SwiftData

struct CaseDashboardView: View {
    @Bindable var caseFile: CaseFile
    /// En iPad la navegación cambia la selección del split view;
    /// en iPhone se usan NavigationLink con value.
    var onNavigate: ((CaseSection) -> Void)?

    private let services = AppServices.shared
    @State private var aiSummary: String?
    @State private var appeared = false

    private var rules: [CompletenessRule] { services.scoring.evaluate(caseFile) }

    // Agrupación semántica de secciones
    private let coreSections:  [CaseSection] = [.timeline, .evidence, .validation, .questions]
    private let toolSections:  [CaseSection] = [.poster, .report, .trust, .map]
    private let systemSections:[CaseSection] = [.privacy, .settings]

    var body: some View {
        ScrollView {
            VStack(spacing: FaroTheme.sectionSpacing) {
                personHeader
                    .faroEntrance(visible: appeared, delay: 0.0)

                completenessCard
                    .faroEntrance(visible: appeared, delay: 0.05)

                if !rules.unmet.isEmpty {
                    missingInfoSection
                        .faroEntrance(visible: appeared, delay: 0.10)
                }

                aiSummaryCard
                    .faroEntrance(visible: appeared, delay: 0.12)

                sectionGroup(
                    title: "Expediente",
                    subtitle: "Registra y organiza los datos del caso",
                    sections: coreSections,
                    startDelay: 0.16
                )

                sectionGroup(
                    title: "Herramientas",
                    subtitle: "Genera documentos y localiza zonas",
                    sections: toolSections,
                    startDelay: 0.28
                )

                sectionGroup(
                    title: "Sistema",
                    subtitle: nil,
                    sections: systemSections,
                    startDelay: 0.38
                )
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Resumen del caso")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { withAnimation { appeared = true } }
    }

    // MARK: - Persona

    private var personHeader: some View {
        HStack(spacing: 16) {
            personPhoto

            VStack(alignment: .leading, spacing: 5) {
                Text(caseFile.person?.displayName ?? "Sin nombre todavía")
                    .font(.title2.weight(.semibold))
                if let age = caseFile.person?.approximateAge {
                    Text("\(age) años (aprox.)")
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.secondaryText)
                }
                Text("Última actualización: \(caseFile.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
                if caseFile.isDemo {
                    Text("Caso demo · datos ficticios")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FaroTheme.amber.opacity(0.15))
                        .foregroundStyle(FaroTheme.amber)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .faroCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var personPhoto: some View {
        if let data = caseFile.person?.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
                .accessibilityLabel("Foto de \(caseFile.person?.displayName ?? "la persona")")
        } else {
            Image(systemName: "person.crop.circle.dashed")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(FaroTheme.secondaryText)
                .frame(width: 72, height: 72)
                .background(FaroTheme.secondaryText.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
                .accessibilityLabel("Sin foto todavía")
        }
    }

    // MARK: - Completitud

    private var completenessCard: some View {
        let percent = rules.completenessPercent
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Información reunida")
                    .font(.headline)
                Spacer()
                Text("\(percent)%")
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(FaroTheme.night)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FaroTheme.secondaryText.opacity(0.12))
                        .frame(height: 7)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [FaroTheme.amber, FaroTheme.amber.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(7, geo.size.width * CGFloat(percent) / 100),
                            height: 7
                        )
                        .animation(FaroTheme.springSmooth.delay(0.15), value: percent)
                }
            }
            .frame(height: 7)

            Text("Guía orientativa de qué falta por reunir. No es un valor oficial.")
                .font(.caption)
                .foregroundStyle(FaroTheme.secondaryText)
        }
        .faroCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Información reunida: \(percent) por ciento. Guía orientativa, no es un valor oficial.")
    }

    // MARK: - Información faltante

    private var missingInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FaroSectionHeader(title: "Qué falta por reunir",
                              subtitle: "Puedes completarlo cuando tengas el dato. No necesitas tener todo ahora.")
            ForEach(rules.unmet.prefix(4)) { rule in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(FaroTheme.amber)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.title).font(.subheadline.weight(.medium))
                        Text(rule.suggestion)
                            .font(.caption)
                            .foregroundStyle(FaroTheme.secondaryText)
                    }
                    Spacer()
                }
                .faroCard()
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Resumen de IA (siempre marcado como sugerencia)

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                FaroSectionHeader(title: "Resumen del expediente")
                Spacer()
            }
            if let aiSummary {
                Text(aiSummary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                AISuggestionBadge()
                Text("Motor: \(services.ai.engineName)")
                    .font(.caption2)
                    .foregroundStyle(FaroTheme.secondaryText)
            } else {
                Button {
                    Task { aiSummary = await services.ai.summarizeCase(caseFile) }
                } label: {
                    Label("Generar resumen con IA local", systemImage: "sparkles")
                }
                .buttonStyle(FaroSecondaryButtonStyle(fullWidth: false))
                Text("El resumen se genera en el dispositivo y es solo una ayuda de lectura.")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
            }
        }
        .faroCard()
    }

    // MARK: - Grupos de secciones

    private func sectionGroup(
        title: String,
        subtitle: String?,
        sections: [CaseSection],
        startDelay: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FaroSectionHeader(title: title, subtitle: subtitle)
                .faroEntrance(visible: appeared, delay: startDelay)

            ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                sectionLink(section)
                    .faroEntrance(visible: appeared, delay: startDelay + Double(index) * 0.04 + 0.04)
            }
        }
    }

    @ViewBuilder
    private func sectionLink(_ section: CaseSection) -> some View {
        let card = CaseDashboardCard(
            symbolName: section.symbolName,
            title: section.title,
            subtitle: subtitle(for: section),
            badgeCount: badgeCount(for: section)
        )

        if let onNavigate {
            Button { onNavigate(section) } label: { card }
                .buttonStyle(FaroCardButtonStyle())
        } else {
            NavigationLink(value: section) { card }
                .buttonStyle(FaroCardButtonStyle())
        }
    }

    private func subtitle(for section: CaseSection) -> String {
        switch section {
        case .timeline:
            return "\(caseFile.timeline.count) eventos registrados"
        case .evidence:
            return "\(caseFile.evidence.count) elementos en el vault"
        case .validation:
            let count = caseFile.pendingReviewCount
            return count == 0 ? "Todo revisado" : "\(count) datos esperan tu revisión"
        case .questions:
            let count = caseFile.pendingQuestions.count
            return count == 0 ? "Sin preguntas pendientes" : "\(count) preguntas por resolver"
        case .poster:
            return caseFile.posters.isEmpty ? "Genera una ficha segura para compartir" : "Ficha lista para revisar"
        case .report:
            return caseFile.reports.isEmpty ? "Prepara un documento para autoridad o colectivo" : "Reporte generado"
        case .trust:
            return "\(caseFile.contacts.count) personas en la red"
        case .map:
            return "\(caseFile.locations.count) ubicaciones privadas"
        case .privacy:
            return "Cómo protege FARO tu información"
        case .settings:
            return "Demo, datos y opciones del caso"
        case .dashboard:
            return ""
        }
    }

    private func badgeCount(for section: CaseSection) -> Int {
        switch section {
        case .validation: return caseFile.pendingReviewCount
        case .questions:  return caseFile.pendingQuestions.count
        default:          return 0
        }
    }
}
