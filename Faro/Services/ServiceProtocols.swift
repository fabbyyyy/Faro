//
//  ServiceProtocols.swift
//  Faro
//
//  Contratos de los servicios. Todo va detrás de un protocolo para
//  poder usar implementaciones reales (Vision, Speech, Foundation Models)
//  o mocks locales cuando el entorno no las soporte. La demo nunca
//  depende de internet ni de permisos concedidos.
//

import Foundation
import SwiftUI

// MARK: - OCR

/// Resultado de extraer texto de una captura.
struct OCRResult {
    var fullText: String
    /// Horas detectadas en el texto ("21:47", "9:05 pm"...): candidatas
    /// a evento de timeline, siempre sujetas a validación humana.
    var detectedTimes: [String]
    var confidence: ConfidenceLevel
}

protocol OCRServiceProtocol {
    /// Extrae texto de una imagen local. Lanza si Vision no puede procesarla.
    func extractText(from imageData: Data) async throws -> OCRResult
}

// MARK: - Transcripción de voz

struct TranscriptionResult {
    var text: String
    var confidence: ConfidenceLevel
    /// Verdadero cuando el resultado viene de un mock (se muestra en la UI).
    var isSimulated: Bool
}

protocol SpeechTranscriptionServiceProtocol {
    /// Transcribe un audio local. Las implementaciones reales pueden
    /// requerir permisos; si no están disponibles, la app usa el mock.
    func transcribeAudio(at url: URL) async throws -> TranscriptionResult
    var isAvailable: Bool { get }
}

// MARK: - IA de procesamiento

/// Clasificación sugerida para una evidencia. Solo es una sugerencia:
/// la pantalla de validación la muestra como "Sugerido por IA".
struct EvidenceClassificationSuggestion {
    var kind: EvidenceKind
    var sensitivity: SensitivityLevel
    var rationale: String
}

/// Evento de timeline sugerido a partir de texto extraído.
struct TimelineEventSuggestion {
    var date: Date?
    var rawTimeText: String?
    var title: String
    var details: String
    var confidence: ConfidenceLevel
}

@MainActor
protocol AIProcessingServiceProtocol {
    /// Nombre legible del motor ("Foundation Models" o "Asistente local de demo").
    var engineName: String { get }
    var isOnDeviceModelAvailable: Bool { get }

    /// Sugiere tipo y sensibilidad para un texto de evidencia.
    func classifyEvidence(text: String) async -> EvidenceClassificationSuggestion

    /// Sugiere eventos de timeline a partir de texto extraído (OCR/transcripción).
    func suggestTimelineEvents(from text: String, referenceDate: Date) async -> [TimelineEventSuggestion]

    /// Resume el estado del caso en lenguaje claro y sobrio.
    func summarizeCase(_ caseFile: CaseFile) async -> String

    /// Redacta el texto corto de difusión en el tono elegido,
    /// usando solo los campos ya aprobados como públicos.
    func draftShareText(personName: String, age: Int?, zone: String,
                        date: Date?, clothing: String, contact: String,
                        tone: PosterTone) async -> String
}

// MARK: - Puntaje de completitud

/// Una regla de completitud del expediente con su estado.
struct CompletenessRule: Identifiable {
    var id: String { title }
    var title: String
    var isMet: Bool
    /// Acción sugerida cuando falta ("Agrega una foto reciente").
    var suggestion: String
}

protocol CaseScoringServiceProtocol {
    /// Calcula reglas cumplidas y faltantes. El puntaje es orientativo,
    /// nunca un valor oficial.
    func evaluate(_ caseFile: CaseFile) -> [CompletenessRule]
}

// MARK: - Exportación PDF

protocol PDFExportServiceProtocol {
    /// Renderiza una vista SwiftUI como PDF en un archivo temporal.
    @MainActor func exportPDF<Content: View>(view: Content, fileName: String) -> URL?
}
