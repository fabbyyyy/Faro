//
//  ChatModels.swift
//  Faro
//
//  Modelos de la conversación de intake. Todo se persiste en SwiftData:
//  cada mensaje, cada pregunta y su estado. El usuario puede salir a
//  mitad de la conversación y retomar exactamente donde se quedó.
//

import Foundation
import SwiftData

// MARK: - Rol y tipo de mensaje

enum ChatRole: String, Codable {
    case assistant
    case user
    case system
}

enum ChatMessageKind: String, Codable {
    case normal             // Conversación regular
    case question           // El asistente hace una pregunta del banco
    case fieldConfirmation  // Microconfirmación: datos detectados esperando validación
    case resumeSummary      // Resumen al retomar la sesión
    case empathy            // Respuesta de contención (no sabe / estrés)
}

// MARK: - Estado de cada pregunta del flujo

/// Estados del ciclo de vida de una pregunta de intake.
enum IntakeQuestionStatus: String, Codable, CaseIterable {
    case pending       // Aún no se pregunta o no se responde
    case answered      // Respondida, dato extraído
    case dontKnow      // "No lo sé" — se vuelve a preguntar después, con suavidad
    case skipped       // Saltada explícitamente
    case needsReask    // Marcada para volver a preguntar
    case confirmed     // Dato validado por la persona
    case edited        // Respondida y luego editada

    var displayName: String {
        switch self {
        case .pending:     return "Pendiente"
        case .answered:    return "Respondida"
        case .dontKnow:    return "Aún no se sabe"
        case .skipped:     return "Saltada"
        case .needsReask:  return "Volver a preguntar"
        case .confirmed:   return "Confirmada"
        case .edited:      return "Editada"
        }
    }

    /// Preguntas que cuentan como "pendientes" para repreguntas y revisión.
    var isOpen: Bool {
        switch self {
        case .pending, .dontKnow, .skipped, .needsReask: return true
        case .answered, .confirmed, .edited:             return false
        }
    }
}

// MARK: - Sesión de conversación

@Model
final class ChatSession {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var isCompleted: Bool = false

    /// Pregunta activa al momento de salir: permite retomar exactamente
    /// donde se quedó la conversación.
    var activeQuestionKey: String?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage] = []

    var caseFile: CaseFile?

    init() {
        self.id = UUID()
    }

    var sortedMessages: [ChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }
}

// MARK: - Mensaje

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var roleRaw: String = ChatRole.assistant.rawValue
    var kindRaw: String = ChatMessageKind.normal.rawValue
    var text: String = ""

    /// Clave de la pregunta del banco a la que responde o pregunta este mensaje.
    var questionKey: String?

    /// Campos detectados esperando microconfirmación (codificados).
    /// Solo presente en mensajes de tipo fieldConfirmation.
    var pendingFieldsData: Data?

    var session: ChatSession?

    init(role: ChatRole, kind: ChatMessageKind = .normal, text: String, questionKey: String? = nil) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.kindRaw = kind.rawValue
        self.text = text
        self.questionKey = questionKey
    }

    var role: ChatRole { ChatRole(rawValue: roleRaw) ?? .assistant }
    var kind: ChatMessageKind { ChatMessageKind(rawValue: kindRaw) ?? .normal }

    var pendingFields: [DetectedField] {
        get {
            guard let data = pendingFieldsData else { return [] }
            return (try? JSONDecoder().decode([DetectedField].self, from: data)) ?? []
        }
        set {
            pendingFieldsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - Estado persistente de una pregunta del banco

@Model
final class IntakeQuestionRecord {
    var id: UUID = UUID()
    var questionKey: String = ""
    var statusRaw: String = IntakeQuestionStatus.pending.rawValue

    /// Lo que la persona escribió, tal cual (se conserva siempre).
    var rawAnswer: String = ""

    /// Redacción formal para la ficha técnica.
    var formalValue: String = ""

    /// Confianza del dato según cómo se expresó la persona.
    var confidenceRaw: String = ConfidenceLevel.medium.rawValue

    /// Validación humana del dato (aproximado, confirmado...).
    var validationRaw: String = ValidationState.pending.rawValue

    var askCount: Int = 0
    var lastAskedAt: Date?
    var updatedAt: Date = Date.now

    var caseFile: CaseFile?

    init(questionKey: String) {
        self.id = UUID()
        self.questionKey = questionKey
    }

    var status: IntakeQuestionStatus {
        get { IntakeQuestionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue; updatedAt = .now }
    }

    var confidence: ConfidenceLevel {
        get { ConfidenceLevel(rawValue: confidenceRaw) ?? .medium }
        set { confidenceRaw = newValue.rawValue }
    }

    var validation: ValidationState {
        get { ValidationState(rawValue: validationRaw) ?? .pending }
        set { validationRaw = newValue.rawValue }
    }
}

// MARK: - Campo detectado por la IA (estructura de transporte, Codable)

/// Un dato extraído de un mensaje del usuario. Es una sugerencia:
/// siempre pasa por microconfirmación antes de integrarse.
struct DetectedField: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    /// Clave del campo (coincide con IntakeQuestion.fieldKey).
    var key: String
    /// Etiqueta formal ("Vestimenta referida").
    var label: String
    /// Valor extraído, ya formalizado.
    var formalValue: String
    /// Lo que la persona dijo, tal cual.
    var rawText: String
    /// Confianza según los marcadores de lenguaje ("creo", "me dijeron"...).
    var confidence: ConfidenceLevel
    /// Estado sugerido: aproximado si hubo dudas, pendiente si es de terceros.
    var suggestedValidation: ValidationState
}
