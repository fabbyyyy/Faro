//
//  ReviewBeforeGenerateView.swift
//  Faro
//
//  Revisión antes de generar: todos los datos con su estado
//  (confirmado, aproximado, pendiente, no disponible, sensible),
//  editables. Solo después de esta revisión se genera la ficha formal.
//

import SwiftUI
import SwiftData

struct ReviewBeforeGenerateView: View {
    let caseFile: CaseFile
    /// Si se provee, el llamador genera la ficha (p. ej. desde el chat).
    var onGenerate: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var editingKey: String?
    @State private var editText = ""
    @State private var generatedFicha: CaseFicha?
    @State private var saveError = false

    private var states: [(IntakeQuestion, IntakeQuestionRecord?)] {
        IntakeQuestionBank.sortedByPriority.map { question in
            (question, caseFile.questionStates.first { $0.questionKey == question.key })
        }
    }

    private var pendingCount: Int {
        states.filter { $0.1?.status.isOpen ?? true }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(states, id: \.0.key) { question, state in
                        row(question: question, state: state)
                    }
                } header: {
                    Text("Datos detectados")
                } footer: {
                    if pendingCount > 0 {
                        Text("Hay \(pendingCount) campo\(pendingCount == 1 ? "" : "s") pendiente\(pendingCount == 1 ? "" : "s"). La ficha los marcará como \"pendiente de confirmar\" sin inventar información.")
                    }
                }

                Section {
                    Button {
                        generate()
                    } label: {
                        Label("Generar ficha técnica", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FaroTheme.night)
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("La ficha se guarda como nueva versión en Documentos. Las versiones anteriores se conservan.")
                }
            }
            .navigationTitle("Revisión antes de generar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .alert("No se pudo guardar", isPresented: $saveError) {
                Button("Entendido", role: .cancel) { }
            } message: {
                Text("No pudimos guardar este cambio. Intenta de nuevo antes de cerrar.")
            }
            .sheet(item: Binding(
                get: { editingKey.map { EditingKey(key: $0) } },
                set: { editingKey = $0?.key })
            ) { editing in
                editSheet(for: editing.key)
                    .presentationDetents([.medium])
            }
            .sheet(item: $generatedFicha) { ficha in
                NavigationStack {
                    GeneratedFichaDetailView(ficha: ficha, caseFile: caseFile)
                }
            }
        }
    }

    private struct EditingKey: Identifiable {
        let key: String
        var id: String { key }
    }

    // MARK: - Fila de campo

    private func row(question: IntakeQuestion, state: IntakeQuestionRecord?) -> some View {
        Button {
            editText = state?.formalValue.isEmpty == false ? state!.formalValue : ""
            editingKey = question.key
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.formalLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(displayValue(state))
                        .font(.caption)
                        .foregroundStyle(FaroTheme.secondaryText)
                        .lineLimit(3)
                    statusBadge(question: question, state: state)
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Toca para editar este campo")
    }

    private func displayValue(_ state: IntakeQuestionRecord?) -> String {
        guard let state, !state.status.isOpen, !state.formalValue.isEmpty else {
            return "No disponible al momento"
        }
        return state.formalValue
    }

    @ViewBuilder
    private func statusBadge(question: IntakeQuestion, state: IntakeQuestionRecord?) -> some View {
        let isSensitive = question.category == .health
        let (text, color): (String, Color) = {
            if isSensitive { return ("Sensible · no se difunde", FaroTheme.amber) }
            guard let state, !state.status.isOpen else { return ("Pendiente", FaroTheme.secondaryText) }
            switch state.validation {
            case .confirmed:   return ("Confirmado", FaroTheme.confirmedGreen)
            case .approximate: return ("Aproximado", FaroTheme.amber)
            default:           return ("Por confirmar", FaroTheme.amber)
            }
        }()
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Edición de campo

    private func editSheet(for key: String) -> some View {
        NavigationStack {
            Form {
                Section(IntakeQuestionBank.question(for: key)?.formalLabel ?? "Campo") {
                    TextField("Valor del campo", text: $editText, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section {
                    Button("Guardar como confirmado") { saveEdit(key: key, validation: .confirmed) }
                    Button("Guardar como aproximado") { saveEdit(key: key, validation: .approximate) }
                    Button("Marcar como pendiente") { saveEdit(key: key, validation: .pending, reopen: true) }
                }
            }
            .navigationTitle("Editar campo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { editingKey = nil }
                }
            }
        }
    }

    private func saveEdit(key: String, validation: ValidationState, reopen: Bool = false) {
        let state = caseFile.questionStates.first { $0.questionKey == key } ?? {
            let newState = IntakeQuestionRecord(questionKey: key)
            caseFile.questionStates.append(newState)
            return newState
        }()

        if reopen {
            state.status = .needsReask
            state.formalValue = ""
        } else {
            state.status = state.status.isOpen ? .answered : .edited
            state.formalValue = editText
            state.validation = validation
        }
        // Cambió un dato importante: las fichas generadas quedan marcadas
        // como desactualizadas (touch incrementa la revisión del caso).
        caseFile.touch()
        do { try modelContext.save() } catch { saveError = true }
        editingKey = nil
    }

    // MARK: - Generación

    private func generate() {
        if let onGenerate {
            onGenerate()
            return
        }
        let composer = FichaComposerService()
        let version = (caseFile.fichas.filter { $0.status != .draft }.map(\.versionNumber).max() ?? 0) + 1
        let ficha = CaseFicha(versionNumber: version, associatedCaseID: caseFile.id)
        ficha.status = .final
        ficha.content = composer.composeFicha(for: caseFile)
        ficha.sourceFields = composer.snapshotSourceFields(for: caseFile)
        ficha.sourceRevision = caseFile.dataRevision
        caseFile.fichas.append(ficha)
        caseFile.promoteStatus(to: .fichaGenerated)
        caseFile.touchDocumentsOnly()
        do {
            try modelContext.save()
            generatedFicha = ficha
        } catch {
            saveError = true
        }
    }
}
