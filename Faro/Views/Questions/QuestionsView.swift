//
//  QuestionsView.swift
//  Faro
//
//  Preguntas críticas pendientes: generadas según lo que falta
//  y editables por la familia.
//

import SwiftUI
import SwiftData

struct QuestionsView: View {
    @Bindable var caseFile: CaseFile
    @Environment(\.modelContext) private var modelContext

    @State private var newQuestionText = ""
    @State private var answeringQuestion: CaseQuestion?

    private var sortedQuestions: [CaseQuestion] {
        caseFile.questions.sorted { a, b in
            // Pendientes primero, luego por fecha.
            if (a.state == .pending) != (b.state == .pending) {
                return a.state == .pending
            }
            return a.createdAt < b.createdAt
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if sortedQuestions.isEmpty {
                    EmptyStateView(
                        symbolName: "questionmark.circle",
                        title: "Sin preguntas registradas",
                        message: "Aquí aparecerán las preguntas críticas que ayudan a completar el expediente.",
                        actionTitle: "Sugerir preguntas",
                        action: { suggestQuestions() }
                    )
                } else {
                    ForEach(sortedQuestions) { question in
                        Button {
                            answeringQuestion = question
                        } label: {
                            PendingQuestionCard(question: question)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Toca para responder o cambiar el estado")
                    }

                    Button {
                        suggestQuestions()
                    } label: {
                        Label("Sugerir más preguntas según lo que falta", systemImage: "sparkles")
                    }
                    .buttonStyle(FaroSecondaryButtonStyle())
                }

                addQuestionCard
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Preguntas pendientes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $answeringQuestion) { question in
            AnswerQuestionView(question: question, caseFile: caseFile)
                .presentationDetents([.medium])
        }
    }

    private var addQuestionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            FaroSectionHeader(title: "Agregar pregunta propia")
            HStack(spacing: 10) {
                TextField("¿Qué falta por averiguar?", text: $newQuestionText)
                    .textFieldStyle(.roundedBorder)
                Button("Agregar") {
                    let question = CaseQuestion(text: newQuestionText)
                    caseFile.questions.append(question)
                    caseFile.touch()
                    try? modelContext.save()
                    newQuestionText = ""
                }
                .disabled(newQuestionText.isEmpty)
            }
        }
        .faroCard()
    }

    /// Genera preguntas según las reglas de completitud no cumplidas.
    private func suggestQuestions() {
        let rules = AppServices.shared.scoring.evaluate(caseFile)
        let existing = Set(caseFile.questions.map(\.text))

        let candidates: [(String, String)] = [
            ("¿Quién fue la última persona que habló con ella o él?", "Ayuda a confirmar horario y estado de ánimo."),
            ("¿Llevaba identificación?", "Es de lo primero que preguntan las autoridades."),
            ("¿Tomó transporte? ¿Cuál ruta?", "Define la zona a revisar primero."),
            ("¿Hay cámaras cerca del último punto conocido?", "Comercios y edificios suelen tener cámaras."),
            ("¿Llevaba algún medicamento importante?", "Información médica clave para priorizar la búsqueda."),
            ("¿Hay una foto reciente de cuerpo completo?", "Mejora la ficha de búsqueda."),
            ("¿Ya se revisaron sus lugares frecuentes?", "A veces la respuesta está en la rutina.")
        ]

        var added = 0
        for (text, why) in candidates where !existing.contains(text) && added < 4 {
            let question = CaseQuestion(text: text, whyItMatters: why, suggestedAutomatically: true)
            caseFile.questions.append(question)
            added += 1
        }

        // Además, las reglas incumplidas se vuelven preguntas accionables.
        for rule in rules.unmet.prefix(2) {
            let text = "¿Puedes completar: \(rule.title.lowercased())?"
            if !existing.contains(text) {
                caseFile.questions.append(
                    CaseQuestion(text: text, whyItMatters: rule.suggestion, suggestedAutomatically: true)
                )
            }
        }

        caseFile.touch()
        try? modelContext.save()
    }
}

// MARK: - Responder pregunta

struct AnswerQuestionView: View {
    @Bindable var question: CaseQuestion
    var caseFile: CaseFile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var answerText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(question.text)
                        .font(.headline)
                    if !question.whyItMatters.isEmpty {
                        Text(question.whyItMatters)
                            .font(.subheadline)
                            .foregroundStyle(FaroTheme.secondaryText)
                    }
                }
                Section("Respuesta") {
                    TextField("Escribe lo que se sabe…", text: $answerText, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button("Guardar como resuelta") {
                        question.answer = answerText
                        question.state = .resolved
                        caseFile.touch()
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(answerText.isEmpty)

                    Button("Marcar como no aplica") {
                        question.state = .notApplicable
                        caseFile.touch()
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Responder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear { answerText = question.answer }
        }
    }
}
