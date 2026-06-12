//
//  PendingIntakePanel.swift
//  Faro
//
//  Panel de datos del caso abierto desde el chat. Usa el panel
//  unificado; "Editar" precarga la respuesta en el chat.
//

import SwiftUI

struct PendingIntakePanel: View {
    let viewModel: ChatIntakeViewModel
    let onSelect: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CaseDataPanel(caseFile: viewModel.caseFile) { question in
            viewModel.editAnswer(for: question)
            dismiss()
            onSelect()
        }
    }
}
