//
//  ChatIntakeViewModel.swift
//  Faro
//
//  Estado del chatbot de intake. Reglas de oro:
//  - Autosave en cada paso: nada espera al final para guardarse.
//  - Memoria persistente: salir y volver retoma exactamente donde quedó.
//  - "No sé" nunca bloquea: se agenda repregunta suave.
//  - Ningún dato entra a la ficha sin microconfirmación humana.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class ChatIntakeViewModel {

    /// Estado visible del autosave, para dar confianza de que nada se pierde.
    enum SaveStatus: Equatable {
        case idle
        case saving
        case saved
        case failed
    }

    // MARK: Estado

    private(set) var caseFile: CaseFile
    private(set) var session: ChatSession
    private let context: ModelContext
    private let ai: CaseAIServiceProtocol
    private let fichaComposer = FichaComposerService()

    private(set) var messages: [ChatMessage] = []
    private(set) var isProcessing = false

    /// Mensaje de confirmación pendiente (microvalidación humana).
    private(set) var awaitingConfirmation: ChatMessage?

    /// Error de guardado, mostrado en lenguaje humano.
    var saveErrorMessage: String?

    /// Estado del autosave para el indicador visible ("Guardando…/Guardado").
    private(set) var saveStatus: SaveStatus = .idle
    /// Oculta el "Guardado" tras un momento para que el indicador sea discreto.
    private var saveStatusResetTask: Task<Void, Never>?

    /// Texto en edición cuando la persona toca "Editar" en una confirmación.
    var inputPrefill: String?

    /// Respuestas dadas desde la última repregunta (para espaciar repreguntas).
    private var answersSinceReask = 0

    /// Campos donde un dato nuevo puede contradecir uno ya registrado.
    private let conflictProneKeys: Set<String> = ["clothing", "lastSeenPlace", "physicalDescription"]

    var engineName: String { ai.engineName }

    // MARK: Init

    /// Si caseFile es nil, crea un caso nuevo como borrador (autosave inmediato).
    init(caseFile: CaseFile?, context: ModelContext) {
        self.context = context
        self.ai = ChatAIServiceFactory.makeService()

        let resolvedCase: CaseFile
        if let caseFile {
            resolvedCase = caseFile
        } else {
            let newCase = CaseFile(title: "Nuevo caso")
            newCase.status = .draft
            newCase.person = MissingPerson()
            context.insert(newCase)
            resolvedCase = newCase
        }
        self.caseFile = resolvedCase

        // Sesión: retoma la última no completada o crea una nueva.
        if let existing = resolvedCase.sessions
            .filter({ !$0.isCompleted })
            .sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            self.session = existing
        } else {
            let newSession = ChatSession()
            resolvedCase.sessions.append(newSession)
            self.session = newSession
        }

        ensureQuestionStates()
        syncStatesFromExistingCase()
        removeDuplicateAssistantMessages()
        persist()
        loadMessages()
    }

    /// Limpia duplicados de mensajes del asistente acumulados por sesiones
    /// previas (resumen/pregunta repetidos). Conserva la primera aparición de
    /// cada mensaje generado por el flujo; nunca toca mensajes del usuario ni
    /// las tarjetas de confirmación.
    private func removeDuplicateAssistantMessages() {
        var seen = Set<String>()
        var toDelete: [ChatMessage] = []
        for message in session.sortedMessages where message.role == .assistant {
            guard message.kind == .resumeSummary || message.kind == .question
                    || message.kind == .normal || message.kind == .empathy else { continue }
            let signature = "\(message.kindRaw)|\(message.questionKey ?? "")|\(message.text)"
            if seen.contains(signature) {
                toDelete.append(message)
            } else {
                seen.insert(signature)
            }
        }
        guard !toDelete.isEmpty else { return }
        for message in toDelete { context.delete(message) }
    }

    /// Garantiza que cada pregunta del banco tenga su IntakeQuestionRecord persistido.
    private func ensureQuestionStates() {
        let existingKeys = Set(caseFile.questionStates.map(\.questionKey))
        for question in IntakeQuestionBank.all where !existingKeys.contains(question.key) {
            caseFile.questionStates.append(IntakeQuestionRecord(questionKey: question.key))
        }
    }

    /// Pre-marca como respondidas las preguntas cuyo dato ya existe en el caso
    /// (p.ej. casos creados con Modo Crisis, el caso demo o casos importados).
    private func syncStatesFromExistingCase() {
        guard let person = caseFile.person else { return }

        func mark(_ key: String, value: String) {
            guard !value.isEmpty else { return }
            updateState(for: key) { state in
                guard state.status.isOpen else { return }
                state.status = .answered
                state.formalValue = value
            }
        }

        mark("personName",        value: person.name)
        mark("lastSeenPlace",     value: person.lastSeenPlace)
        mark("clothing",          value: person.clothingDescription)
        mark("physicalDescription", value: person.physicalDescription)
        mark("medical",           value: person.medicalConditions)
        mark("frequentPlaces",    value: person.frequentPlaces)
        mark("companions",        value: person.possibleCompanions)

        if let age = person.approximateAge {
            mark("age", value: "\(age) años")
        }
        if let date = person.lastSeenAt {
            let f = DateFormatter()
            f.locale = Locale(identifier: "es_MX")
            f.dateStyle = .medium
            f.timeStyle = .short
            mark("lastSeenTime", value: f.string(from: date))
        }
        if let hasPhone = person.carriedPhone {
            mark("phone", value: hasPhone ? "Sí, llevaba celular" : "No llevaba celular")
        }
        if !caseFile.evidence.isEmpty {
            mark("evidenceAvailable", value: "Sí")
        }
        if let contact = caseFile.contacts.first {
            let contactStr = contact.phone.isEmpty ? contact.name : "\(contact.name) — \(contact.phone)"
            mark("trustedContact", value: contactStr)
        }
    }

    private func loadMessages() {
        messages = session.sortedMessages
        awaitingConfirmation = messages.last(where: { $0.kind == .fieldConfirmation && !$0.pendingFields.isEmpty })
        if awaitingConfirmation?.id != messages.last?.id { awaitingConfirmation = nil }
    }

    // MARK: Lectura del estado del caso

    var questionStates: [IntakeQuestionRecord] { caseFile.questionStates }

    var activeQuestion: IntakeQuestion? {
        session.activeQuestionKey.flatMap { IntakeQuestionBank.question(for: $0) }
    }

    var openQuestions: [(IntakeQuestion, IntakeQuestionRecord)] {
        IntakeQuestionBank.sortedByPriority.compactMap { question in
            guard let state = caseFile.questionStates.first(where: { $0.questionKey == question.key }),
                  state.status.isOpen else { return nil }
            return (question, state)
        }
    }

    var answeredCount: Int {
        caseFile.questionStates.filter { !$0.status.isOpen }.count
    }

    var knownFieldLabels: [String] {
        IntakeQuestionBank.sortedByPriority.compactMap { question in
            guard let state = caseFile.questionStates.first(where: { $0.questionKey == question.key }),
                  !state.status.isOpen else { return nil }
            return question.formalLabel
        }
    }

    /// El recorrido base terminó: toda pregunta fue planteada al menos una vez.
    var baseFlowFinished: Bool {
        caseFile.questionStates
            .filter { state in IntakeQuestionBank.question(for: state.questionKey) != nil }
            .allSatisfy { $0.askCount > 0 || !$0.status.isOpen }
    }

    // MARK: Arranque / reanudación

    func start() {
        guard messages.isEmpty else {
            resumeIfNeeded()
            return
        }

        let known = answeredCount
        let remaining = openQuestions.count
        let personName = caseFile.person?.name ?? ""

        if known > 0 {
            // El caso ya tiene datos (Modo Crisis, caso demo, importado…).
            var greeting: String
            if !personName.isEmpty {
                greeting = "El expediente de **\(personName)** ya tiene \(known) dato\(known == 1 ? "" : "s") registrado\(known == 1 ? "" : "s")."
            } else {
                greeting = "Este expediente ya tiene \(known) dato\(known == 1 ? "" : "s") registrado\(known == 1 ? "" : "s")."
            }
            if remaining > 0 {
                greeting += " Puedo ayudarte a completar lo que falta (\(remaining) campo\(remaining == 1 ? "" : "s")). Puedes saltar cualquier pregunta o responder \"no sé\" sin problema."
            } else {
                greeting += " El expediente está bastante completo. Puedes agregar detalles o correcciones cuando quieras."
            }
            appendAssistant(greeting, kind: .resumeSummary)
        } else {
            appendAssistant(
                "Estoy aquí para ayudarte a ordenar la información, paso a paso. Puedes saltar cualquier pregunta o responder \"no sé\": nada se pierde y todo se puede completar después.",
                kind: .normal
            )
        }

        askNextQuestion()
    }

    /// Al volver a una sesión existente: resume desde SwiftData, no de memoria.
    private func resumeIfNeeded() {
        guard !session.isCompleted else { return }
        // Si el asistente ya tiene la última palabra (pregunta, resumen o nota),
        // no hay nada que reanudar: el usuario solo continúa. Esto evita que se
        // dupliquen mensajes cada vez que se entra y sale del asistente
        // (en iPad la vista se recrea al cambiar de sección).
        if let last = messages.last, last.role == .assistant { return }

        let known = knownFieldLabels
        let pendingCount = openQuestions.count
        var summary = "Retomamos donde nos quedamos."
        if !known.isEmpty {
            summary += " Ya tenemos: \(known.prefix(4).joined(separator: ", ").lowercased())."
        }
        if pendingCount > 0 {
            summary += " Hay \(pendingCount) dato\(pendingCount == 1 ? "" : "s") pendiente\(pendingCount == 1 ? "" : "s")."
        }
        appendAssistant(summary, kind: .resumeSummary)

        if let active = activeQuestion {
            appendAssistant(active.humanQuestion, kind: .question, questionKey: active.key)
        } else {
            askNextQuestion()
        }
    }

    // MARK: Envío de mensajes del usuario

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessing else { return }

        // Intento de navegación: "volver a X" → saltar a esa pregunta directamente.
        if let navKey = SpanishIntakeEngine.detectNavigationRequest(trimmed) {
            appendUser(trimmed)
            if navKey == "unknown" {
                appendAssistant(
                    "¿A qué campo quieres volver? Puedes decirme, por ejemplo, 'volver a ropa' o 'volver a nombre'.",
                    kind: .normal
                )
            } else if let question = IntakeQuestionBank.question(for: navKey) {
                reask(question)
            } else {
                appendAssistant("Entendido. ¿Puedes decirme exactamente qué dato quieres corregir?", kind: .normal)
            }
            return
        }

        appendUser(trimmed)
        isProcessing = true

        let active = activeQuestion
        let history = messages.suffix(6).map(\.text)

        Task { @MainActor in
            let result = await ai.processUserMessage(trimmed,
                                                     activeQuestion: active,
                                                     caseFile: caseFile,
                                                     recentHistory: Array(history))
            handle(result, userText: trimmed)
            isProcessing = false
        }
    }

    private func handle(_ result: IntakeProcessingResult, userText: String) {
        switch result.classification {
        case .unknown:
            // "No sé" → contención, marcar pendiente y avanzar sin presión.
            appendAssistant(result.assistantReply, kind: .empathy)
            if let active = activeQuestion {
                updateState(for: active.key) { state in
                    state.status = .dontKnow
                    state.rawAnswer = userText
                }
            }
            advanceFlow()

        case .stress:
            // Contención breve, sin consejos clínicos; misma pregunta, sin culpa.
            appendAssistant(result.assistantReply, kind: .empathy)
            if let active = activeQuestion {
                appendAssistant(active.humanQuestion + " (Puedes responder \"saltar\" si prefieres.)",
                                kind: .question, questionKey: active.key)
            }

        case .skip:
            appendAssistant(result.assistantReply, kind: .empathy)
            if let active = activeQuestion {
                updateState(for: active.key) { $0.status = .skipped }
            }
            advanceFlow()

        case .smalltalk:
            appendAssistant(result.assistantReply, kind: .normal)
            if let active = activeQuestion {
                appendAssistant(active.humanQuestion, kind: .question, questionKey: active.key)
            }

        case .informative:
            guard !result.detectedFields.isEmpty else {
                appendAssistant("Lo registré como nota. ¿Seguimos con la siguiente pregunta?", kind: .normal)
                advanceFlow()
                return
            }
            applyDirectly(fields: result.detectedFields, reply: result.assistantReply)
        }
        persist()
    }

    // MARK: Guardado directo (sin confirmación)

    /// Aplica los campos detectados inmediatamente, sin paso de confirmación.
    /// Datos con marcadores de incertidumbre ("creo", "tal vez"…) se guardan
    /// como `.approximate` y se marcan para repregunta posterior.
    private func applyDirectly(fields: [DetectedField], reply: String) {
        appendAssistant(reply, kind: .normal)
        var hasUncertain = false
        for field in fields {
            let conflicted = flagConflictIfNeeded(for: field)
            apply(field: field, validation: field.suggestedValidation)
            if conflicted {
                // El conflicto manda: el dato queda por confirmar, no como hecho.
                updateState(for: field.key) { $0.validation = .contradictory }
            }
            if field.suggestedValidation != .confirmed {
                hasUncertain = true
                updateState(for: field.key) { state in
                    if state.status == .answered || state.status == .edited {
                        state.status = .needsReask
                    }
                }
            }
        }
        // Si hay datos inciertos, acercamos el umbral de repregunta para revisarlos pronto.
        if hasUncertain { answersSinceReask = max(answersSinceReask, 2) }
        answersSinceReask += 1
        caseFile.promoteStatus(to: .inProgress)
        caseFile.touch()
        refreshDraftFicha()
        advanceFlow()
    }

    // MARK: Detección de contradicciones (ropa, lugar, descripción)

    /// Si un dato nuevo contradice uno ya registrado para el mismo campo,
    /// no bloquea ni descarta: registra el nuevo, lo marca como contradictorio
    /// y deja una pregunta pendiente para que la familia confirme cuál vale.
    private func flagConflictIfNeeded(for field: DetectedField) -> Bool {
        guard conflictProneKeys.contains(field.key),
              let state = caseFile.questionStates.first(where: { $0.questionKey == field.key }),
              !state.status.isOpen,
              !state.formalValue.isEmpty,
              let question = IntakeQuestionBank.question(for: field.key) else { return false }

        let existingRaw = state.rawAnswer.isEmpty ? state.formalValue : state.rawAnswer
        guard isMaterialConflict(existing: existingRaw, new: field.rawText) else { return false }

        let label = question.formalLabel.lowercased()
        let previousValue = state.formalValue
        let conflictText = "Hay dos respuestas distintas para \(label): «\(previousValue)» y «\(field.formalValue)». ¿Cuál confirmas?"
        let alreadyNoted = caseFile.questions.contains { $0.text == conflictText && $0.state == .pending }
        if !alreadyNoted {
            caseFile.questions.append(CaseQuestion(
                text: conflictText,
                whyItMatters: "Confirmar una sola versión evita difundir información incorrecta.",
                suggestedAutomatically: true
            ))
        }
        appendAssistant(
            "Antes tenía registrado «\(previousValue)» para \(label). Anoté el dato nuevo y lo dejé por confirmar, para que elijas cuál es el correcto.",
            kind: .normal
        )
        return true
    }

    /// Dos valores se contradicen si ninguno contiene al otro (no es un
    /// detalle agregado ni una reformulación, sino una respuesta distinta).
    private func isMaterialConflict(existing: String, new: String) -> Bool {
        let a = existing.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let b = new.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !a.isEmpty, !b.isEmpty, a != b else { return false }
        return !a.contains(b) && !b.contains(a)
    }

    // MARK: Microconfirmación humana (no usada en flujo normal — queda para uso futuro)

    /// Muestra los datos detectados para validación antes de integrarlos.
    private func presentConfirmation(for fields: [DetectedField], reply: String) {
        // Aviso si algún dato ya se había mencionado antes.
        let alreadyAnswered = fields.filter { field in
            guard let state = caseFile.questionStates.first(where: { $0.questionKey == field.key }) else { return false }
            return !state.status.isOpen
        }
        var text = reply
        if let repeated = alreadyAnswered.first,
           let state = caseFile.questionStates.first(where: { $0.questionKey == repeated.key }) {
            text = "Ya tenía registrado \(repeated.label.lowercased()) (\(state.formalValue)). Si confirmas, lo actualizo con lo nuevo."
        }

        let message = ChatMessage(role: .assistant, kind: .fieldConfirmation, text: text)
        message.pendingFields = fields
        session.messages.append(message)
        session.updatedAt = .now
        loadMessages()
        awaitingConfirmation = message
    }

    /// La persona confirma los datos detectados (todos) con un estado.
    func confirmPendingFields(as validation: ValidationState) {
        guard let message = awaitingConfirmation else { return }
        let fields = message.pendingFields

        for field in fields {
            apply(field: field, validation: validation)
        }

        message.pendingFields = []
        awaitingConfirmation = nil
        answersSinceReask += 1

        caseFile.promoteStatus(to: .inProgress)
        caseFile.touch()
        refreshDraftFicha()
        persist()

        appendAssistant("Guardado. " + progressNote(), kind: .normal)
        advanceFlow()
    }

    /// Descartar los datos detectados: no se integran y la pregunta sigue abierta.
    func discardPendingFields() {
        guard let message = awaitingConfirmation else { return }
        message.pendingFields = []
        awaitingConfirmation = nil
        appendAssistant("Descartado. No lo integraré al expediente.", kind: .normal)
        if let active = activeQuestion {
            appendAssistant(active.humanQuestion, kind: .question, questionKey: active.key)
        }
        persist()
    }

    /// Editar: precarga el texto original en el campo de entrada.
    func editPendingFields() {
        guard let message = awaitingConfirmation else { return }
        inputPrefill = message.pendingFields.first?.rawText
        message.pendingFields = []
        awaitingConfirmation = nil
        appendAssistant("Claro, corrige el dato y lo vuelvo a registrar.", kind: .normal)
        persist()
    }

    /// Integra un campo validado al caso: QuestionState + entidades del expediente.
    private func apply(field: DetectedField, validation: ValidationState) {
        updateState(for: field.key) { state in
            let wasAnswered = !state.status.isOpen
            state.status = wasAnswered ? .edited : .answered
            state.rawAnswer = field.rawText
            state.formalValue = field.formalValue
            state.confidence = field.confidence
            state.validation = validation
        }

        let person = caseFile.person ?? {
            let newPerson = MissingPerson()
            caseFile.person = newPerson
            return newPerson
        }()

        switch field.key {
        case "personName":
            person.name = field.formalValue
            caseFile.title = "Caso · \(field.formalValue)"
        case "age":
            person.approximateAge = Int(field.rawText.filter(\.isNumber))
        case "lastSeenPlace":
            person.lastSeenPlace = field.formalValue
        case "clothing":
            person.clothingDescription = field.formalValue
        case "physicalDescription":
            person.physicalDescription = field.formalValue
        case "distinguishingMarks":
            if !person.physicalDescription.contains(field.formalValue) {
                person.physicalDescription += (person.physicalDescription.isEmpty ? "" : " ") + "Señas particulares: \(field.formalValue)"
            }
        case "medical":
            person.medicalConditions = field.formalValue
        case "frequentPlaces":
            person.frequentPlaces = field.formalValue
        case "companions":
            person.possibleCompanions = field.formalValue
        case "phone":
            let lower = field.rawText.lowercased()
            person.carriedPhone = !(lower.contains("no llevaba") || lower == "no")
        case "lastSeenTime":
            applyLastSeenTime(field, validation: validation)
        case "trustedContact":
            applyTrustedContact(field)
        default:
            break
        }
    }

    private func applyLastSeenTime(_ field: DetectedField, validation: ValidationState) {
        let person = caseFile.person
        // Construye fecha si la formalización contiene HH:mm (sobre ayer/hoy).
        if let timeText = SpanishIntakeEngine.formalizeTime(from: field.rawText),
           let hour = Int(timeText.prefix(2)),
           let minute = Int(timeText.suffix(2)) {
            let base = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
            let date = base > .now ? Calendar.current.date(byAdding: .day, value: -1, to: base)! : base
            person?.lastSeenAt = date

            // Evento de timeline: SIEMPRE como aproximado/pendiente, nunca confirmado.
            let alreadyExists = caseFile.timeline.contains { $0.isLastSeenMarker && abs($0.date.timeIntervalSince(date)) < 60 }
            if !alreadyExists {
                let event = TimelineEvent(
                    date: date,
                    title: "Última vez vista (referencia del intake)",
                    details: field.formalValue,
                    source: .aiSuggestion,
                    confidence: field.confidence,
                    validationState: validation == .confirmed ? .approximate : validation
                )
                event.isLastSeenMarker = true
                caseFile.timeline.append(event)
            }
        }
    }

    private func applyTrustedContact(_ field: DetectedField) {
        let raw = field.rawText
        let phone = SpanishIntakeEngine.firstMatch(in: raw, pattern: #"((?:\d[\s-]?){8,12})"#) ?? ""
        var name = raw
        if !phone.isEmpty { name = name.replacingOccurrences(of: phone, with: "") }
        name = name.replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "mi hermana", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "mi hermano", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let exists = caseFile.contacts.contains { $0.name.lowercased() == name.lowercased() }
        if !exists {
            caseFile.contacts.append(TrustedContact(name: name.capitalized,
                                                    relationship: "Registrado en intake",
                                                    phone: phone.trimmingCharacters(in: .whitespaces),
                                                    role: .familyAdmin))
        }
    }

    // MARK: Avance del flujo y repreguntas inteligentes

    private func advanceFlow() {
        // Repregunta suave cada 3 respuestas si hay pendientes acumulados.
        if answersSinceReask >= 3, let (question, state) = reaskCandidate() {
            answersSinceReask = 0
            state.status = .needsReask
            state.askCount += 1
            state.lastAskedAt = .now
            session.activeQuestionKey = question.key
            appendAssistant(question.reaskQuestion + " Si aún no lo sabes, lo dejamos pendiente sin problema.",
                            kind: .question, questionKey: question.key)
            persist()
            return
        }
        askNextQuestion()
    }

    private func reaskCandidate() -> (IntakeQuestion, IntakeQuestionRecord)? {
        openQuestions.first { question, state in
            (state.status == .dontKnow || state.status == .skipped || state.status == .needsReask) && state.askCount <= 2
        }
    }

    private func askNextQuestion() {
        if let next = ai.suggestNextQuestion(for: caseFile) {
            session.activeQuestionKey = next.key
            updateState(for: next.key) { state in
                state.askCount += 1
                state.lastAskedAt = .now
            }
            var text = next.humanQuestion
            if let hint = next.hint { text += "\n\(hint)" }
            if let rationale = next.rationale { text += "\n\(rationale)" }
            appendAssistant(text, kind: .question, questionKey: next.key)
        } else {
            finishBaseFlow()
        }
        persist()
    }

    /// Cierre del recorrido base: ofrece pendientes o generar la ficha.
    private func finishBaseFlow() {
        session.activeQuestionKey = nil
        let pending = openQuestions.count
        if pending > 0 {
            appendAssistant(
                "Hemos terminado el recorrido base. Hay \(pending) dato\(pending == 1 ? "" : "s") que dejamos pendiente\(pending == 1 ? "" : "s"). Podemos intentar uno ahora, o puedes revisar y generar la ficha con esos campos marcados como pendientes.",
                kind: .normal
            )
        } else {
            appendAssistant(
                "Gracias. Tenemos la información del recorrido base. Puedes revisar los datos y generar la ficha técnica cuando quieras.",
                kind: .normal
            )
        }
    }

    /// La persona elige responder ahora una pregunta pendiente concreta.
    func reask(_ question: IntakeQuestion) {
        session.activeQuestionKey = question.key
        updateState(for: question.key) { state in
            state.status = .needsReask
            state.askCount += 1
            state.lastAskedAt = .now
        }
        appendAssistant(question.reaskQuestion, kind: .question, questionKey: question.key)
        persist()
    }

    /// Editar una respuesta ya dada desde el panel de datos.
    func editAnswer(for question: IntakeQuestion) {
        if let state = caseFile.questionStates.first(where: { $0.questionKey == question.key }) {
            inputPrefill = state.rawAnswer.isEmpty ? nil : state.rawAnswer
        }
        session.activeQuestionKey = question.key
        appendAssistant("Editemos \(question.formalLabel.lowercased()). Escribe el dato corregido.",
                        kind: .question, questionKey: question.key)
        persist()
    }

    private func progressNote() -> String {
        let pending = openQuestions.count
        if pending == 0 { return "No quedan datos pendientes." }
        return "Llevamos \(answeredCount) dato\(answeredCount == 1 ? "" : "s"); \(pending) pendiente\(pending == 1 ? "" : "s")."
    }

    // MARK: Ficha en construcción (incremental)

    /// Mantiene un borrador de ficha actualizado en SwiftData en todo momento.
    func refreshDraftFicha() {
        let draft = caseFile.fichas.first { $0.status == .draft } ?? {
            let newDraft = CaseFicha(versionNumber: 0, associatedCaseID: caseFile.id)
            newDraft.status = .draft
            caseFile.fichas.append(newDraft)
            return newDraft
        }()
        draft.content = fichaComposer.composeFicha(for: caseFile)
        draft.sourceFields = fichaComposer.snapshotSourceFields(for: caseFile)
        draft.sourceRevision = caseFile.dataRevision
        draft.updatedAt = .now
    }

    /// Genera la ficha técnica formal como nueva versión (no borra anteriores).
    @discardableResult
    func generateFinalFicha() -> CaseFicha {
        let version = (caseFile.fichas.filter { $0.status != .draft }.map(\.versionNumber).max() ?? 0) + 1
        let ficha = CaseFicha(versionNumber: version, associatedCaseID: caseFile.id)
        ficha.status = .final
        ficha.content = fichaComposer.composeFicha(for: caseFile)
        ficha.sourceFields = fichaComposer.snapshotSourceFields(for: caseFile)
        ficha.sourceRevision = caseFile.dataRevision
        caseFile.fichas.append(ficha)
        caseFile.promoteStatus(to: .fichaGenerated)
        caseFile.touchDocumentsOnly()
        session.isCompleted = openQuestions.isEmpty
        persist()
        appendAssistant("Ficha técnica v\(version) generada y guardada en Documentos. Puedes regenerarla si los datos cambian; las versiones anteriores se conservan.", kind: .normal)
        return ficha
    }

    // MARK: Persistencia (autosave)

    private func appendAssistant(_ text: String, kind: ChatMessageKind, questionKey: String? = nil) {
        let message = ChatMessage(role: .assistant, kind: kind, text: text, questionKey: questionKey)
        session.messages.append(message)
        session.updatedAt = .now
        loadMessages()
        persist()
    }

    private func appendUser(_ text: String) {
        let message = ChatMessage(role: .user, text: text, questionKey: session.activeQuestionKey)
        session.messages.append(message)
        session.updatedAt = .now
        loadMessages()
        persist()
    }

    private func updateState(for key: String, _ mutate: (IntakeQuestionRecord) -> Void) {
        if let state = caseFile.questionStates.first(where: { $0.questionKey == key }) {
            mutate(state)
        } else {
            let state = IntakeQuestionRecord(questionKey: key)
            mutate(state)
            caseFile.questionStates.append(state)
        }
    }

    /// Autosave con mensaje humano si algo falla. Sin pérdidas silenciosas.
    /// Refleja el estado en `saveStatus` para el indicador visible.
    func persist() {
        saveStatus = .saving
        do {
            try context.save()
            saveStatus = .saved
            scheduleSaveStatusReset()
        } catch {
            saveStatus = .failed
            saveErrorMessage = "No pudimos guardar este cambio. Intenta de nuevo antes de cerrar."
        }
    }

    /// Vuelve a `.idle` tras unos segundos para no dejar el "Guardado" fijo.
    /// El error sí permanece hasta el siguiente guardado correcto.
    private func scheduleSaveStatusReset() {
        saveStatusResetTask?.cancel()
        saveStatusResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled, self.saveStatus == .saved else { return }
            self.saveStatus = .idle
        }
    }
}
