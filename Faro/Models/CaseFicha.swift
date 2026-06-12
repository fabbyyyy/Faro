//
//  CaseFicha.swift
//  Faro
//
//  Ficha técnica del caso. Se construye de forma incremental durante
//  la conversación (borrador) y se versiona al generarse formalmente.
//  Las versiones anteriores nunca se borran automáticamente: trazabilidad.
//

import Foundation
import SwiftData

/// Estado de una ficha técnica.
enum FichaStatus: String, Codable, CaseIterable {
    case draft      // En construcción durante la conversación
    case final      // Generada y revisada
    case outdated   // El caso cambió después de generarla

    var displayName: String {
        switch self {
        case .draft:    return "En construcción"
        case .final:    return "Generada"
        case .outdated: return "Desactualizada"
        }
    }
}

/// Campo de origen de la ficha, con su estado al momento de generar.
struct FichaSourceField: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var key: String
    var label: String
    var value: String
    var statusRaw: String      // IntakeQuestionStatus
    var validationRaw: String  // ValidationState

    var status: IntakeQuestionStatus { IntakeQuestionStatus(rawValue: statusRaw) ?? .pending }
    var validation: ValidationState { ValidationState(rawValue: validationRaw) ?? .pending }
}

@Model
final class CaseFicha {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var versionNumber: Int = 1
    var statusRaw: String = FichaStatus.draft.rawValue

    /// Contenido formal completo de la ficha (texto estructurado).
    var content: String = ""

    /// Campos de origen codificados (clave, valor, estado al generar).
    var sourceFieldsData: Data?

    /// Revisión del caso al momento de generar. Si el caso avanza,
    /// la ficha se marca como desactualizada (nunca se borra sola).
    var sourceRevision: Int = 0

    /// ID del caso asociado (redundante con la relación, útil para export).
    var associatedCaseID: UUID = UUID()

    var caseFile: CaseFile?

    init(versionNumber: Int, associatedCaseID: UUID) {
        self.id = UUID()
        self.versionNumber = versionNumber
        self.associatedCaseID = associatedCaseID
    }

    var status: FichaStatus {
        get { FichaStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue; updatedAt = .now }
    }

    var sourceFields: [FichaSourceField] {
        get {
            guard let data = sourceFieldsData else { return [] }
            return (try? JSONDecoder().decode([FichaSourceField].self, from: data)) ?? []
        }
        set {
            sourceFieldsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
        }
    }

    /// Verdadero si el caso cambió después de generar esta ficha.
    func isOutdated(comparedTo caseFile: CaseFile) -> Bool {
        status == .final && caseFile.dataRevision > sourceRevision
    }
}
