//
//  AppServices.swift
//  Faro
//
//  Punto único de acceso a los servicios. Las implementaciones reales
//  se eligen en tiempo de ejecución según disponibilidad del sistema;
//  los mocks garantizan que la demo funcione sin permisos ni internet.
//

import Foundation

@MainActor
final class AppServices {
    static let shared = AppServices()

    let ai: AIProcessingServiceProtocol
    let ocr: OCRServiceProtocol
    /// OCR simulado para la evidencia de demo (no requiere imagen real).
    let demoOCR: OCRServiceProtocol
    let speech: SpeechTranscriptionServiceProtocol
    /// Transcripción simulada para la demo (claramente etiquetada en la UI).
    let demoSpeech: SpeechTranscriptionServiceProtocol
    let scoring: CaseScoringServiceProtocol
    let timelineAnalysis: TimelineAnalysisService
    let posterBuilder: PosterBuilderService
    let reportBuilder: ReportBuilderService
    let pdfExport: PDFExportService

    private init() {
        ai = AIServiceFactory.makeService()
        ocr = VisionOCRService()
        demoOCR = MockOCRService()
        speech = SpeechFileTranscriptionService()
        demoSpeech = MockSpeechService()
        scoring = CaseScoringService()
        timelineAnalysis = TimelineAnalysisService()
        posterBuilder = PosterBuilderService()
        reportBuilder = ReportBuilderService()
        pdfExport = PDFExportService()
    }
}
