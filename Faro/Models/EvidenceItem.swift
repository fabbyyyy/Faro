//
//  EvidenceItem.swift
//  Faro
//
//  Una pieza de evidencia del Vault: captura, nota, audio,
//  documento o ubicación. La clasificación puede sugerirla la IA,
//  pero la sensibilidad y validez final siempre las decide una persona.
//

import Foundation
import SwiftData

@Model
final class EvidenceItem {
    var id: UUID = UUID()
    var kind: EvidenceKind = EvidenceKind.other
    var createdAt: Date = Date.now

    /// Fecha a la que se refiere la evidencia (p. ej. hora del mensaje),
    /// distinta de la fecha en que se capturó en la app.
    var referenceDate: Date?

    var title: String = ""
    var details: String = ""

    /// De dónde viene: "Captura de WhatsApp", "Relato de vecina", etc.
    var source: String = ""

    var sensitivity: SensitivityLevel = SensitivityLevel.incomplete
    var validationState: ValidationState = ValidationState.pending

    /// Verdadero cuando la clasificación actual fue sugerida por IA
    /// y la familia aún no la revisa.
    var classificationSuggestedByAI: Bool = false

    /// Texto extraído por OCR o transcripción, ya validado o pendiente.
    var extractedText: String = ""

    /// Archivo local opcional (imagen de la captura, etc.).
    @Attribute(.externalStorage)
    var fileData: Data?

    /// Eventos del timeline que se apoyan en esta evidencia.
    var linkedEvents: [TimelineEvent] = []

    var caseFile: CaseFile?

    init(kind: EvidenceKind, title: String, details: String = "", source: String = "") {
        self.id = UUID()
        self.kind = kind
        self.title = title
        self.details = details
        self.source = source
    }
}
