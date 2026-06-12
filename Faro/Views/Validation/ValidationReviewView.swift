//
//  ValidationReviewView.swift
//  Faro
//
//  Pantalla de validación humana: ningún dato extraído por OCR,
//  transcripción o IA entra al expediente como hecho sin pasar por aquí.
//  Muestra el dato, la fuente, la clasificación sugerida y acciones claras.
//

import SwiftUI
import SwiftData

struct ValidationReviewView: View {
    @Bindable var evidence: EvidenceItem
    var caseFile: CaseFile
    /// Se llama al cerrar tras validar (para cerrar también el alta).
    var onFinished: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let services = AppServices.shared

    @State private var eventSuggestions: [TimelineEventSuggestion] = []
    @State private var acceptedSuggestionIDs: Set<Int> = []
    @State private var loadingSuggestions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FaroTheme.sectionSpacing) {
                    if evidence.classificationSuggestedByAI {
                        AISuggestionBadge()
                    }

                    sourceSection
                    extractedTextSection
                    classificationSection

                    if !evidence.extractedText.isEmpty {
                        suggestedEventsSection
                    }

                    validationActions
                }
                .padding(FaroTheme.screenPadding)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(FaroTheme.background)
            .navigationTitle("Revisar dato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Después") {
                        // Sin culpa: queda pendiente, no se pierde.
                        evidence.validationState = .pending
                        close()
                    }
                    .accessibilityHint("El dato queda guardado como pendiente de revisar")
                }
            }
            .task {
                await loadSuggestions()
            }
        }
    }

    // MARK: - Fuente

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            FaroSectionHeader(title: "Fuente")
            HStack {
                Image(systemName: evidence.kind.symbolName)
                    .foregroundStyle(FaroTheme.night)
                    .accessibilityHidden(true)
                Text(evidence.source.isEmpty ? "Sin fuente registrada" : evidence.source)
                    .font(.subheadline)
            }
            if let date = evidence.referenceDate {
                Text("Se refiere al \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
            }
        }
        .faroCard()
    }

    // MARK: - Texto detectado (editable)

    private var extractedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FaroSectionHeader(title: "Dato detectado",
                              subtitle: "Puedes corregirlo antes de confirmar. Los modelos locales pueden equivocarse.")
            TextEditor(text: $evidence.extractedText)
                .font(.body)
                .frame(minHeight: 110)
                .padding(8)
                .background(FaroTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
                .accessibilityLabel("Texto detectado, editable")
        }
        .faroCard()
    }

    // MARK: - Clasificación

    private var classificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FaroSectionHeader(title: "Clasificación",
                              subtitle: evidence.classificationSuggestedByAI
                                ? "Sugerida por IA. Confírmala o corrígela."
                                : nil)

            Picker("Tipo de evidencia", selection: $evidence.kind) {
                ForEach(EvidenceKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.menu)

            Picker("Sensibilidad", selection: $evidence.sensitivity) {
                ForEach(SensitivityLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 8) {
                SensitivityBadge(level: evidence.sensitivity)
                ValidationBadge(state: evidence.validationState)
            }

            if evidence.sensitivity == .sensitive {
                Text("Información sensible: no se incluirá en fichas públicas ni difusión.")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.amber)
            }
        }
        .faroCard()
    }

    // MARK: - Eventos sugeridos para el timeline

    private var suggestedEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FaroSectionHeader(title: "Posibles momentos detectados",
                              subtitle: "FARO detectó posibles horas en el texto. Agrega al timeline solo lo que reconozcas.")

            if loadingSuggestions {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Buscando horas y momentos…")
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.secondaryText)
                }
            } else if eventSuggestions.isEmpty {
                Text("No se detectaron horas en el texto.")
                    .font(.subheadline)
                    .foregroundStyle(FaroTheme.secondaryText)
            }

            ForEach(Array(eventSuggestions.enumerated()), id: \.offset) { index, suggestion in
                suggestionRow(index: index, suggestion: suggestion)
            }
        }
        .faroCard()
    }

    private func suggestionRow(index: Int, suggestion: TimelineEventSuggestion) -> some View {
        let accepted = acceptedSuggestionIDs.contains(index)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.medium))
                    if let raw = suggestion.rawTimeText {
                        Text("Hora detectada: \(raw)")
                            .font(.caption)
                            .foregroundStyle(FaroTheme.secondaryText)
                    }
                }
                Spacer()
                if accepted {
                    Label("Agregado", systemImage: "checkmark")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(FaroTheme.confirmedGreen)
                } else {
                    Button("Agregar al timeline") {
                        acceptSuggestion(index: index, suggestion: suggestion)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(10)
        .background(FaroTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
    }

    private func acceptSuggestion(index: Int, suggestion: TimelineEventSuggestion) {
        let event = TimelineEvent(
            date: suggestion.date ?? evidence.referenceDate ?? .now,
            title: suggestion.title,
            details: suggestion.details,
            source: .aiSuggestion,
            confidence: suggestion.confidence,
            validationState: .pending // Entra como pendiente: la familia lo confirma en el timeline.
        )
        event.relatedEvidence.append(evidence)
        caseFile.timeline.append(event)
        caseFile.touch()
        acceptedSuggestionIDs.insert(index)
        try? modelContext.save()
    }

    private func loadSuggestions() async {
        guard !evidence.extractedText.isEmpty else { return }
        loadingSuggestions = true
        eventSuggestions = await services.ai.suggestTimelineEvents(
            from: evidence.extractedText,
            referenceDate: evidence.referenceDate ?? caseFile.person?.lastSeenAt ?? .now
        )
        loadingSuggestions = false
    }

    // MARK: - Acciones de validación

    private var validationActions: some View {
        VStack(spacing: 10) {
            Button {
                validate(.confirmed)
            } label: {
                Label("Confirmar este dato", systemImage: "checkmark.seal")
            }
            .buttonStyle(FaroPrimaryButtonStyle())

            HStack(spacing: 10) {
                Button {
                    validate(.approximate)
                } label: {
                    Label("Aproximado", systemImage: "circle.dashed")
                }
                .buttonStyle(FaroSecondaryButtonStyle())

                Button {
                    validate(.discarded)
                } label: {
                    Label("Descartar", systemImage: "xmark.circle")
                }
                .buttonStyle(FaroSecondaryButtonStyle())
            }

            Button("Guardar como pendiente") {
                validate(.pending)
            }
            .buttonStyle(FaroQuietButtonStyle())
        }
    }

    private func validate(_ state: ValidationState) {
        evidence.validationState = state
        evidence.classificationSuggestedByAI = false
        caseFile.touch()
        try? modelContext.save()
        close()
    }

    private func close() {
        dismiss()
        onFinished?()
    }
}
