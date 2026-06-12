//
//  ValidationCenterView.swift
//  Faro
//
//  Cola de revisión: todo lo que espera validación humana en un solo
//  lugar, para que nada sugerido se quede sin confirmar.
//

import SwiftUI
import SwiftData

struct ValidationCenterView: View {
    @Bindable var caseFile: CaseFile

    @State private var reviewingEvidence: EvidenceItem?
    @State private var editingEvent: TimelineEvent?

    private var pendingEvidence: [EvidenceItem] {
        caseFile.evidence
            .filter { $0.validationState == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var pendingEvents: [TimelineEvent] {
        caseFile.timeline
            .filter { $0.validationState == .pending }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FaroTheme.sectionSpacing) {
                if pendingEvidence.isEmpty && pendingEvents.isEmpty {
                    EmptyStateView(
                        symbolName: "checkmark.seal",
                        title: "Todo está revisado",
                        message: "No hay datos esperando tu validación. Lo sugerido por IA o extraído de capturas siempre pasará por aquí."
                    )
                } else {
                    Text("Estos datos fueron sugeridos o extraídos automáticamente. Revísalos cuando puedas; mientras tanto no se tratan como hechos.")
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.secondaryText)

                    if !pendingEvidence.isEmpty {
                        FaroSectionHeader(title: "Evidencia por revisar")
                        ForEach(pendingEvidence) { item in
                            Button {
                                reviewingEvidence = item
                            } label: {
                                EvidenceCard(evidence: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !pendingEvents.isEmpty {
                        FaroSectionHeader(title: "Eventos por revisar")
                        ForEach(pendingEvents) { event in
                            Button {
                                editingEvent = event
                            } label: {
                                TimelineEventCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Por revisar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $reviewingEvidence) { item in
            ValidationReviewView(evidence: item, caseFile: caseFile)
        }
        .sheet(item: $editingEvent) { event in
            TimelineEventEditorView(event: event, caseFile: caseFile)
        }
    }
}
