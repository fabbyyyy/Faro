//
//  TimelineEvent.swift
//  Faro
//
//  Un punto en la línea de tiempo del caso. Puede venir de respuestas
//  manuales, OCR, transcripciones o ubicaciones. Nunca entra como
//  "confirmado" si lo produjo un proceso automático.
//

import Foundation
import SwiftData

@Model
final class TimelineEvent {
    var id: UUID = UUID()

    /// Fecha y hora del evento (puede ser aproximada; ver validationState).
    var date: Date = Date.now

    var title: String = ""
    var details: String = ""

    var source: DataSource = DataSource.manual
    var confidence: ConfidenceLevel = ConfidenceLevel.medium
    var validationState: ValidationState = ValidationState.pending

    /// Marca los eventos que representan "última vez vista" para
    /// poder detectar contradicciones de horario entre ellos.
    var isLastSeenMarker: Bool = false

    var notes: String = ""

    /// Evidencia que respalda este evento.
    @Relationship(inverse: \EvidenceItem.linkedEvents)
    var relatedEvidence: [EvidenceItem] = []

    var caseFile: CaseFile?

    init(date: Date,
         title: String,
         details: String = "",
         source: DataSource = .manual,
         confidence: ConfidenceLevel = .medium,
         validationState: ValidationState = .pending) {
        self.id = UUID()
        self.date = date
        self.title = title
        self.details = details
        self.source = source
        self.confidence = confidence
        self.validationState = validationState
    }
}
