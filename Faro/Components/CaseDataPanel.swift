//
//  CaseDataPanel.swift
//  Faro
//
//  Panel unificado de datos del caso: pendientes y ya registrados,
//  con los mismos datos del intake (IntakeQuestionRecord). Se usa
//  desde el chat y desde el resumen del caso.
//

import SwiftUI

struct CaseDataPanel: View {
    let caseFile: CaseFile
    /// Acción de editar un dato ya registrado. Si es nil, no se ofrece.
    var onEdit: ((IntakeQuestion) -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var pending: [(IntakeQuestion, IntakeQuestionRecord)] {
        IntakeQuestionBank.sortedByPriority.compactMap { question in
            guard let state = caseFile.questionStates.first(where: { $0.questionKey == question.key }),
                  state.status.isOpen else { return nil }
            return (question, state)
        }
    }

    private var answered: [(IntakeQuestion, IntakeQuestionRecord)] {
        IntakeQuestionBank.sortedByPriority.compactMap { question in
            guard let state = caseFile.questionStates.first(where: { $0.questionKey == question.key }),
                  !state.status.isOpen else { return nil }
            return (question, state)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !pending.isEmpty {
                        FaroSectionHeader(title: "Pendientes",
                                          subtitle: "Puedes completarlo cuando tengas el dato. No necesitas tener todo ahora.")
                        ForEach(pending, id: \.0.key) { question, state in
                            pendingCard(question: question, state: state)
                        }
                    }

                    if !answered.isEmpty {
                        FaroSectionHeader(title: "Ya registrados")
                            .padding(.top, pending.isEmpty ? 0 : 12)
                        ForEach(answered, id: \.0.key) { question, state in
                            answeredCard(question: question, state: state)
                        }
                    }

                    if pending.isEmpty && answered.isEmpty {
                        Text("Aún no hay datos registrados. El asistente te irá guiando paso a paso.")
                            .font(.subheadline)
                            .foregroundStyle(FaroTheme.secondaryText)
                    }
                }
                .padding(FaroTheme.screenPadding)
            }
            .background(FaroTheme.background)
            .navigationTitle("Datos del caso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private func pendingCard(question: IntakeQuestion, state: IntakeQuestionRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: question.symbolName)
                .font(.body)
                .foregroundStyle(FaroTheme.amber)
                .frame(width: 28)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(question.formalLabel)
                    .font(.subheadline.weight(.medium))
                Text(state.status.displayName)
                    .font(.caption)
                    .foregroundStyle(FaroTheme.amber)
            }
            Spacer()
        }
        .faroCard()
        .accessibilityElement(children: .combine)
    }

    private func answeredCard(question: IntakeQuestion, state: IntakeQuestionRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: question.symbolName)
                .font(.body)
                .foregroundStyle(state.validation == .confirmed
                                 ? FaroTheme.confirmedGreen
                                 : FaroTheme.night)
                .frame(width: 28)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(question.formalLabel)
                    .font(.subheadline.weight(.medium))
                Text(state.formalValue.isEmpty ? state.rawAnswer : state.formalValue)
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            if let onEdit {
                Button("Editar") { onEdit(question) }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FaroTheme.night)
                    .buttonStyle(.plain)
                    .accessibilityHint("Edita esta respuesta en el chat")
            }
        }
        .faroCard()
        .accessibilityElement(children: .combine)
    }
}
