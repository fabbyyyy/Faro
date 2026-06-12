//
//  EvidenceVaultView.swift
//  Faro
//
//  Vault de evidencia: capturas, notas, audios y ubicaciones.
//  Cada elemento muestra su tipo, sensibilidad y estado de validación.
//

import SwiftUI
import SwiftData

struct EvidenceVaultView: View {
    @Bindable var caseFile: CaseFile

    @State private var showingAddEvidence = false
    @State private var reviewingEvidence: EvidenceItem?

    private var sortedEvidence: [EvidenceItem] {
        caseFile.evidence.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if sortedEvidence.isEmpty {
                    EmptyStateView(
                        symbolName: "tray",
                        title: "El vault está vacío",
                        message: "Guarda aquí capturas, notas, audios y ubicaciones. Todo se queda en este dispositivo.",
                        actionTitle: "Agregar evidencia",
                        action: { showingAddEvidence = true }
                    )
                } else {
                    ForEach(sortedEvidence) { item in
                        Button {
                            reviewingEvidence = item
                        } label: {
                            EvidenceCard(evidence: item)
                        }
                        .buttonStyle(FaroCardButtonStyle())
                        .accessibilityHint("Toca para revisar y validar esta evidencia")
                    }
                }
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Evidencia")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddEvidence = true
                } label: {
                    Label("Agregar evidencia", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddEvidence) {
            AddEvidenceView(caseFile: caseFile)
        }
        .sheet(item: $reviewingEvidence) { item in
            ValidationReviewView(evidence: item, caseFile: caseFile)
        }
    }
}
