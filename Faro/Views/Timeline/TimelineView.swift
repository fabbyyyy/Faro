//
//  TimelineView.swift
//  Faro
//
//  Línea de tiempo del caso: eventos ordenados, huecos detectados
//  y contradicciones señaladas con suavidad. Todo es editable.
//

import SwiftUI
import SwiftData

struct TimelineView: View {
    @Bindable var caseFile: CaseFile
    @Environment(\.modelContext) private var modelContext

    private let analysis = AppServices.shared.timelineAnalysis

    @State private var editingEvent: TimelineEvent?
    @State private var showingNewEvent = false

    private var events: [TimelineEvent] { caseFile.sortedTimeline }
    private var conflicts: [TimelineConflict] { analysis.detectConflicts(in: caseFile) }
    private var gaps: [TimelineGap] { analysis.detectGaps(in: caseFile) }

    private var conflictingIDs: Set<UUID> {
        Set(conflicts.flatMap(\.eventIDs))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let conflict = conflicts.first {
                    conflictBanner(conflict)
                }

                if events.isEmpty {
                    EmptyStateView(
                        symbolName: "clock.arrow.circlepath",
                        title: "Aún no hay eventos",
                        message: "Registra los momentos que conozcas. Pueden ser aproximados; después se pueden precisar.",
                        actionTitle: "Agregar evento",
                        action: { showingNewEvent = true }
                    )
                } else {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        Button {
                            editingEvent = event
                        } label: {
                            TimelineEventCard(event: event,
                                              isConflicting: conflictingIDs.contains(event.id))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Toca para revisar, confirmar o editar este evento")

                        if let gap = gapAfter(index: index) {
                            gapMarker(gap)
                        }
                    }
                }
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Línea de tiempo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewEvent = true
                } label: {
                    Label("Agregar evento", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editingEvent) { event in
            TimelineEventEditorView(event: event, caseFile: caseFile)
        }
        .sheet(isPresented: $showingNewEvent) {
            NewTimelineEventView(caseFile: caseFile)
        }
    }

    // MARK: - Huecos y contradicciones

    private func gapAfter(index: Int) -> TimelineGap? {
        guard index + 1 < events.count else { return nil }
        let current = events[index]
        let next = events[index + 1]
        return gaps.first { $0.start == current.date && $0.end == next.date }
    }

    private func gapMarker(_ gap: TimelineGap) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "ellipsis")
                .foregroundStyle(FaroTheme.secondaryText)
                .accessibilityHidden(true)
            Text("Hueco de \(gap.hours) horas sin información. ¿Alguien sabe algo de este periodo?")
                .font(.footnote)
                .foregroundStyle(FaroTheme.secondaryText)
        }
        .padding(.vertical, 6)
        .padding(.leading, 70)
        .accessibilityLabel("Hueco de \(gap.hours) horas sin información en la línea de tiempo")
    }

    private func conflictBanner(_ conflict: TimelineConflict) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(FaroTheme.amber)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Revisión sugerida")
                    .font(.subheadline.weight(.semibold))
                Text(conflict.message)
                    .font(.subheadline)
                    .foregroundStyle(FaroTheme.secondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FaroTheme.amber.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
    }
}

// MARK: - Editor de evento existente

struct TimelineEventEditorView: View {
    @Bindable var event: TimelineEvent
    var caseFile: CaseFile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                Section("Evento") {
                    TextField("Título", text: $event.title, axis: .vertical)
                    TextField("Detalles", text: $event.details, axis: .vertical)
                    DatePicker("Fecha y hora", selection: $event.date)
                    Toggle("Es la última vez vista", isOn: $event.isLastSeenMarker)
                }

                Section("Fuente y confianza") {
                    LabeledContent("Fuente", value: event.source.displayName)
                    Picker("Confianza", selection: $event.confidence) {
                        ForEach(ConfidenceLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }

                Section {
                    validationButtons
                } header: {
                    Text("Validación humana")
                } footer: {
                    Text("Estado actual: \(event.validationState.displayName). Nada queda como definitivo sin tu confirmación.")
                }

                Section {
                    Button("Eliminar evento", role: .destructive) {
                        modelContext.delete(event)
                        caseFile.touch()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Revisar evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        caseFile.touch()
                        dismiss()
                    }
                }
            }
        }
    }

    private var validationButtons: some View {
        VStack(spacing: 10) {
            validationButton("Confirmar", state: .confirmed, symbol: "checkmark.seal")
            validationButton("Marcar como aproximado", state: .approximate, symbol: "circle.dashed")
            validationButton("Dejar pendiente", state: .pending, symbol: "clock")
            validationButton("Descartar", state: .discarded, symbol: "xmark.circle")
        }
    }

    private func validationButton(_ title: String, state: ValidationState, symbol: String) -> some View {
        Button {
            event.validationState = state
            caseFile.touch()
        } label: {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                if event.validationState == state {
                    Image(systemName: "checkmark")
                        .foregroundStyle(FaroTheme.confirmedGreen)
                }
            }
        }
        .accessibilityAddTraits(event.validationState == state ? .isSelected : [])
    }
}

// MARK: - Nuevo evento manual

struct NewTimelineEventView: View {
    var caseFile: CaseFile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var details = ""
    @State private var date: Date = .now
    @State private var isLastSeen = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Nuevo evento") {
                    TextField("Qué pasó", text: $title, axis: .vertical)
                    TextField("Detalles (opcional)", text: $details, axis: .vertical)
                    DatePicker("Fecha y hora", selection: $date)
                    Toggle("Es la última vez vista", isOn: $isLastSeen)
                }
                Section {
                    EmptyView()
                } footer: {
                    Text("El evento se guardará como aproximado. Podrás confirmarlo cuando estés segura o seguro.")
                }
            }
            .navigationTitle("Agregar evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let event = TimelineEvent(
                            date: date,
                            title: title.isEmpty ? "Evento sin título" : title,
                            details: details,
                            source: .manual,
                            confidence: .medium,
                            validationState: .approximate
                        )
                        event.isLastSeenMarker = isLastSeen
                        caseFile.timeline.append(event)
                        caseFile.touch()
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
