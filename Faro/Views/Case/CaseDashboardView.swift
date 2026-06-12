//
//  CaseDashboardView.swift
//  Faro
//
//  Estado general del expediente: persona, completitud orientativa,
//  acciones recomendadas y acceso a cada módulo.
//

import SwiftUI
import SwiftData
import PhotosUI

struct CaseDashboardView: View {
    @Bindable var caseFile: CaseFile
    /// En iPad la navegación cambia la selección del split view;
    /// en iPhone se usan NavigationLink con value.
    var onNavigate: ((CaseSection) -> Void)?

    private let services = AppServices.shared
    @State private var aiSummary: String?
    @State private var appeared = false
    @State private var skeletonPulsing = false
    @State private var selectedPhoto: PhotosPickerItem?

    private var rules: [CompletenessRule] { services.scoring.evaluate(caseFile) }

    // Agrupación semántica de secciones
    private let coreSections:  [CaseSection] = [.chat, .timeline, .evidence, .validation, .questions]
    private let systemSections:[CaseSection] = [.privacy, .settings]

    var body: some View {
        ScrollView {
            VStack(spacing: FaroTheme.sectionSpacing) {
                personHeader
                    .faroEntrance(visible: appeared, delay: 0.0)

                aiSummarySection
                    .faroEntrance(visible: appeared, delay: 0.02)

                // Siguiente paso recomendado: una sola acción clara, siempre
                // visible. En crisis, la app decide qué sigue, no la familia.
                if let step = nextStep {
                    nextStepCard(step)
                        .faroEntrance(visible: appeared, delay: 0.03)
                }

                // Acciones urgentes: difundir y reportar — al tope para que la
                // familia las encuentre de inmediato, sin tener que desplazarse.
                urgentActions
                    .faroEntrance(visible: appeared, delay: 0.05)

                if !rules.unmet.isEmpty {
                    missingInfoSection
                        .faroEntrance(visible: appeared, delay: 0.12)
                }

                sectionGroup(
                    title: "Expediente",
                    subtitle: "Registra y organiza los datos del caso",
                    sections: coreSections,
                    startDelay: 0.18
                )

                sectionGroup(
                    title: "Más herramientas",
                    subtitle: nil,
                    sections: [.trust, .map],
                    startDelay: 0.32
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                progressOrb
            }
        }
        .onAppear { withAnimation { appeared = true } }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        if caseFile.person == nil { caseFile.person = MissingPerson() }
                        caseFile.person?.photoData = data
                    }
                }
            }
        }
    }

    // MARK: - Siguiente paso recomendado

    private struct NextStep {
        let section: CaseSection
        let title: String
        let detail: String
        let symbol: String
    }

    /// La acción más importante según el estado del caso. Prioridad:
    /// revisar pendientes → completar datos → ficha pública → reporte.
    private var nextStep: NextStep? {
        let pending = caseFile.pendingReviewCount
        if pending > 0 {
            return NextStep(
                section: .validation,
                title: "Revisa los pendientes con Beacon",
                detail: "\(pending) dato\(pending == 1 ? "" : "s") sugerido\(pending == 1 ? "" : "s") espera\(pending == 1 ? "" : "n") tu confirmación.",
                symbol: "checkmark.seal"
            )
        }
        if rules.completenessPercent < 60 {
            return NextStep(
                section: .chat,
                title: "Continuar con el asistente",
                detail: "Completa la información del caso conversando, paso a paso.",
                symbol: "bubble.left.and.text.bubble.right"
            )
        }
        if caseFile.posters.isEmpty {
            return NextStep(
                section: .poster,
                title: "Generar ficha pública",
                detail: "Crea una ficha segura para difundir, con filtro ético.",
                symbol: "doc.richtext"
            )
        }
        if caseFile.reports.isEmpty {
            return NextStep(
                section: .report,
                title: "Preparar reporte formal",
                detail: "Organiza el documento para autoridad o colectivo.",
                symbol: "doc.text.below.ecg"
            )
        }
        return nil
    }

    @ViewBuilder
    private func nextStepCard(_ step: NextStep) -> some View {
        let card = HStack(spacing: 14) {
            Image("BeaconHi")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FaroTheme.secondaryText.opacity(0.5))
                .accessibilityHidden(true)
        }
        .padding(FaroTheme.cardPadding)
        .background(
            LinearGradient(
                colors: [FaroTheme.amber.opacity(0.10), FaroTheme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(FaroTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous)
                .strokeBorder(FaroTheme.amber.opacity(0.25), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Siguiente paso recomendado: \(step.title). \(step.detail)")
        .accessibilityHint("Toca para continuar")

        if let onNavigate {
            Button { onNavigate(step.section) } label: { card }
                .buttonStyle(FaroCardButtonStyle())
        } else {
            NavigationLink(value: step.section) { card }
                .buttonStyle(FaroCardButtonStyle())
        }
    }

    // MARK: - Persona

    private var personHeader: some View {
        HStack(spacing: 16) {
            personPhotoButton

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
        .accessibilityElement(children: .combine)
    }

    /// Foto de la persona — toca para agregar o cambiar.
    private var personPhotoButton: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                if let data = caseFile.person?.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous)
                        .fill(FaroTheme.secondaryText.opacity(0.08))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "person.crop.rectangle.badge.plus")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(FaroTheme.secondaryText)
                        )
                }
                // Insignia de cámara
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(FaroTheme.night)
                    .background(FaroTheme.background, in: Circle())
                    .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(caseFile.person?.photoData != nil
            ? "Cambiar foto de \(caseFile.person?.displayName ?? "la persona")"
            : "Agregar foto de la persona")
    }

    // MARK: - Acciones urgentes

    private var urgentActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            FaroSectionHeader(title: "Difundir y reportar",
                              subtitle: "Las dos acciones más urgentes cuando falta una persona")
            HStack(spacing: 10) {
                urgentActionButton(section: .poster,
                                   label: "Cartel para difundir",
                                   symbol: "doc.richtext",
                                   accent: FaroTheme.amber)
                urgentActionButton(section: .report,
                                   label: "Reporte a autoridades",
                                   symbol: "doc.text.below.ecg",
                                   accent: FaroTheme.night)
            }
        }
    }

    @ViewBuilder
    private func urgentActionButton(section: CaseSection,
                                    label: String,
                                    symbol: String,
                                    accent: Color) -> some View {
        let button = VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(accent)
                .frame(height: 32)
            Text(label)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(accent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))

        if let onNavigate {
            Button { onNavigate(section) } label: { button }
                .buttonStyle(FaroCardButtonStyle())
        } else {
            NavigationLink(value: section) { button }
                .buttonStyle(FaroCardButtonStyle())
        }
    }

    // MARK: - Completitud

    /// Anillo de progreso en la barra, como el del chat: información
    /// reunida de forma orientativa. Toca para continuar con el asistente.
    @ViewBuilder
    private var progressOrb: some View {
        let percent = rules.completenessPercent
        let orb = ZStack {
            Circle()
                .stroke(FaroTheme.secondaryText.opacity(0.24), lineWidth: 4)
                .frame(width: 28, height: 28)
            Circle()
                .trim(from: 0, to: Double(percent) / 100)
                .stroke(percent >= 100 ? FaroTheme.confirmedGreen : FaroTheme.amber,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 28, height: 28)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: percent)
            Text("\(percent)")
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundStyle(FaroTheme.night)
        }
        .frame(width: 40, height: 40)
        .contentShape(Circle())

        Group {
            if let onNavigate {
                Button { onNavigate(.chat) } label: { orb }
                    .buttonStyle(.plain)
            } else {
                NavigationLink(value: CaseSection.chat) { orb }
                    .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Información reunida: \(percent) por ciento. Guía orientativa, no es un valor oficial.")
        .accessibilityHint("Continúa completando datos con el asistente")
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

    /// Resumen generado automáticamente al abrir el caso.
    /// Texto directo sobre el fondo, sin tarjeta.
    private var aiSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let aiSummary {
                Text(aiSummary)
                    .font(.subheadline)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                summarySkeleton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(FaroTheme.springSmooth, value: aiSummary == nil)
        .task {
            guard aiSummary == nil else { return }
            aiSummary = await services.ai.summarizeCase(caseFile)
        }
    }

    /// Skeleton de carga: líneas que imitan el párrafo del resumen,
    /// con un pulso suave mientras la IA local lo redacta.
    private var summarySkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(FaroTheme.secondaryText.opacity(0.15))
                    .frame(height: 13)
                    .frame(maxWidth: index == 2 ? 180 : .infinity, alignment: .leading)
            }
        }
        .opacity(skeletonPulsing ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                   value: skeletonPulsing)
        .onAppear { skeletonPulsing = true }
        .accessibilityLabel("Preparando resumen del expediente")
        .transition(.opacity)
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
        case .chat:
            let count = caseFile.sessions.count
            return count == 0 ? "Registra datos conversando con la IA" : "\(count) sesión\(count == 1 ? "" : "es") previas"
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
