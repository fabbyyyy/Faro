//
//  OCRService.swift
//  Faro
//
//  Extracción de texto de capturas con Vision (100% en el dispositivo).
//  Incluye un mock para la demo y para previews.
//

import Foundation
import Vision

// MARK: - Detección de horas compartida

enum TimeTextDetector {
    /// Encuentra horas tipo "21:47", "9:05 pm", "9:05 PM" en un texto.
    static func detectTimes(in text: String) -> [String] {
        let pattern = #"\b([01]?\d|2[0-3]):[0-5]\d(\s?[apAP]\.?[mM]\.?)?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}

// MARK: - Implementación real con Vision

struct VisionOCRService: OCRServiceProtocol {

    enum OCRError: LocalizedError {
        case invalidImage
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "No se pudo leer la imagen. Intenta con otra captura."
            case .noTextFound:  return "No se encontró texto en la imagen. Puedes escribir la información manualmente."
            }
        }
    }

    func extractText(from imageData: Data) async throws -> OCRResult {
        guard !imageData.isEmpty else { throw OCRError.invalidImage }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["es-MX", "es", "en"]

        let handler = VNImageRequestHandler(data: imageData)
        try await Task.detached(priority: .userInitiated) {
            try handler.perform([request])
        }.value

        let observations = request.results ?? []
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        guard !lines.isEmpty else { throw OCRError.noTextFound }

        let fullText = lines.joined(separator: "\n")
        let avgConfidence = observations
            .compactMap { $0.topCandidates(1).first?.confidence }
            .reduce(Float(0), +) / Float(max(observations.count, 1))

        return OCRResult(
            fullText: fullText,
            detectedTimes: TimeTextDetector.detectTimes(in: fullText),
            confidence: avgConfidence > 0.8 ? .high : (avgConfidence > 0.5 ? .medium : .low)
        )
    }
}

// MARK: - Mock para demo y previews

struct MockOCRService: OCRServiceProtocol {
    func extractText(from imageData: Data) async throws -> OCRResult {
        // Pequeña pausa para que la demo muestre el estado de procesamiento.
        try? await Task.sleep(for: .milliseconds(700))
        let text = """
        Mariana: voy saliendo de la biblioteca
        ya casi llego a la parada
        21:47 ✓✓
        """
        return OCRResult(
            fullText: text,
            detectedTimes: TimeTextDetector.detectTimes(in: text),
            confidence: .medium
        )
    }
}
