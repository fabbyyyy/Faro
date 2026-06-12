//
//  DraftFichaView.swift
//  Faro
//
//  Ficha en construcción: visible en cualquier momento. Muestra qué
//  datos ya están listos, cuáles están pendientes y cuáles necesitan
//  confirmación. Se actualiza de forma incremental con la conversación.
//

import SwiftUI
import SwiftData

struct DraftFichaView: View {
    let caseFile: CaseFile
    /// Compacto: para la columna lateral del iPad.
    var compact: Bool = false

    @State private var showingReview = false

    private var fields: [FichaSourceField] {
        FichaComposerService().snapshotSourceFields(for: caseFile)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                if !compact {
                    FaroSectionHeader(
                        title: "Ficha en construcción",
                        subtitle: "Se actualiza mientras conversas. Nada se inventa: lo que falta se dice que falta."
                    )
                }

                ForEach(fields) { field in
                    fieldRow(field)
                }

                Button {
                    showingReview = true
                } label: {
                    Label("Revisar y generar ficha técnica", systemImage: "doc.text")
                }
                .buttonStyle(FaroPrimaryButtonStyle())
                .padding(.top, 6)
            }
            .padding(compact ? 14 : FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle(compact ? "" : "Ficha en construcción")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingReview) {
            ReviewBeforeGenerateView(caseFile: caseFile, onGenerate: nil)
        }
    }

    private func fieldRow(_ field: FichaSourceField) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol(for: field))
                .font(.subheadline)
                .foregroundStyle(color(for: field))
                .frame(width: 22)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(field.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FaroTheme.secondaryText)
                Text(field.value)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(field.status.isOpen ? FaroTheme.secondaryText : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                statusLabel(field)
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? 10 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FaroTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(field.label): \(field.value). Estado: \(field.status.displayName)")
    }

    @ViewBuilder
    private func statusLabel(_ field: FichaSourceField) -> some View {
        let text: String = field.status.isOpen
            ? field.status.displayName
            : field.validation == .confirmed ? "Confirmado" : "Aproximado · por confirmar"
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color(for: field))
    }

    private func symbol(for field: FichaSourceField) -> String {
        if field.status.isOpen { return "circle.dashed" }
        return field.validation == .confirmed ? "checkmark.seal.fill" : "clock.badge.questionmark"
    }

    private func color(for field: FichaSourceField) -> Color {
        if field.status.isOpen { return FaroTheme.secondaryText }
        return field.validation == .confirmed ? FaroTheme.confirmedGreen : FaroTheme.amber
    }
}
