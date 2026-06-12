//
//  SpeechService.swift
//  Faro
//
//  Transcripción de notas de voz con el framework Speech (en el dispositivo
//  cuando el sistema lo permite). Si no hay permisos o disponibilidad,
//  la app usa el mock y lo dice claramente en pantalla: honestidad técnica.
//

import Foundation
import Speech

// MARK: - Implementación real (transcripción de archivos)

final class SpeechFileTranscriptionService: SpeechTranscriptionServiceProtocol {

    enum SpeechError: LocalizedError {
        case notAuthorized
        case recognizerUnavailable
        case transcriptionFailed

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "FARO no tiene permiso para usar reconocimiento de voz. Puedes escribir la nota manualmente."
            case .recognizerUnavailable:
                return "El reconocimiento de voz no está disponible en este momento. Puedes escribir la nota manualmente."
            case .transcriptionFailed:
                return "No se pudo transcribir el audio. Puedes escribir la nota manualmente."
            }
        }
    }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))

    var isAvailable: Bool {
        recognizer?.isAvailable == true
            && SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribeAudio(at url: URL) async throws -> TranscriptionResult {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw SpeechError.notAuthorized
        }
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        // Preferir procesamiento en el dispositivo cuando está soportado.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                continuation.resume(returning: TranscriptionResult(
                    text: result.bestTranscription.formattedString,
                    confidence: .medium,
                    isSimulated: false
                ))
            }
        }
    }
}

// MARK: - Mock para demo

struct MockSpeechService: SpeechTranscriptionServiceProtocol {
    var isAvailable: Bool { true }

    func transcribeAudio(at url: URL) async throws -> TranscriptionResult {
        try? await Task.sleep(for: .milliseconds(900))
        return TranscriptionResult(
            text: "Hola ma, ya voy a la parada del camión, se me hizo tarde en la biblioteca. Te marco llegando.",
            confidence: .medium,
            isSimulated: true
        )
    }
}
