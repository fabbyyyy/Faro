//
//  PendingIntakePanel.swift
//  Faro
//
//  Panel de "Datos pendientes": las preguntas omitidas o respondidas
//  con "no sé" no desaparecen. Aquí la persona decide responder ahora,
//  dejar pendiente o editar una respuesta ya dada.
//

import SwiftUI

struct PendingIntakePanel: View {
    let viewModel: ChatIntakeViewModel
    let onSelect: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var answered: [(IntakeQuestion, IntakeQuestionRecord)] {
        IntakeQuestionBank.sortedByPriority.compactMap { question in
            guard let state = viewModel.questionStates.first(where: { $0.questionKey == question.key }),
                  !state.status.isOpen else { return nil }
            return (question, state)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.openQuestions.isEmpty {
                    Section {
                        ForEach(viewModel.openQuestions, id: \.0.key) { question, state in
                            Button {
                                viewModel.reask(question)
                                dismiss()
                                onSelect()
                            } label: {
                                pendingRow(question: question, state: state)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Pendientes")
                    } footer: {
                        Text("Tócalas para responder ahora. También puedes dejarlas pendientes: la ficha lo indicará sin inventar nada.")
                    }
                }

                if !answered.isEmpty {
                    Section("Ya registrados") {
                        ForEach(answered, id: \.0.key) { question, state in
                            Button {
                                viewModel.editAnswer(for: question)
                                dismiss()
                                onSelect()
                            } label: {
                                answeredRow(question: question, state: state)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Datos del caso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private func pendingRow(question: IntakeQuestion, state: IntakeQuestionRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "circle.dashed")
                .foregroundStyle(FaroTheme.amber)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(question.formalLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(state.status.displayName)
                    .font(.caption)
                    .foregroundStyle(FaroTheme.amber)
            }
            Spacer()
            Text("Responder")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FaroTheme.night)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Vuelve a hacer esta pregunta en el chat")
    }

    private func answeredRow(question: IntakeQuestion, state: IntakeQuestionRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: state.validation == .confirmed ? "checkmark.seal.fill" : "circle.dashed")
                .foregroundStyle(state.validation == .confirmed ? FaroTheme.confirmedGreen : FaroTheme.secondaryText)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(question.formalLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(state.formalValue.isEmpty ? state.rawAnswer : state.formalValue)
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Text("Editar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FaroTheme.night)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edita esta respuesta. La ficha se marcará para regenerar.")
    }
}
