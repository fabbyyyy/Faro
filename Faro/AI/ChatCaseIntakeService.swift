//
//  ChatCaseIntakeService.swift
//  Faro
//
//  Capa de lenguaje natural del chatbot de intake.
//
//  Principios:
//  - Salida SIEMPRE estructurada (IntakeProcessingResult), nunca solo texto:
//    así los datos se guardan bien en SwiftData.
//  - La extracción de datos es determinista (reglas en español). Foundation
//    Models, cuando está disponible, solo pule la redacción empática; nunca
//    decide hechos. Un modelo no debe inventar el dato de una familia.
//  - "No sé" no bloquea: se clasifica, se contiene con calma y se agenda
//    una repregunta suave.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Clasificación de la respuesta del usuario

enum UserReplyClassification: String, Codable {
    case informative   // Contiene datos útiles
    case unknown       // "No sé", "no me acuerdo", "la neta no sé"…
    case stress        // "No puedo", "estoy desesperado", "tengo miedo"…
    case skip          // Pide saltar explícitamente
    case smalltalk     // Saludo o texto sin datos
}

// MARK: - Resultado estructurado del procesamiento

struct IntakeProcessingResult {
    /// Respuesta empática del asistente (sobria, sin promesas).
    var assistantReply: String
    /// Campos detectados, formalizados, con confianza y estado sugerido.
    var detectedFields: [DetectedField]
    /// Clasificación de la respuesta del usuario.
    var classification: UserReplyClassification
    /// Si los campos detectados deben pasar por microconfirmación humana.
    var requiresHumanConfirmation: Bool
    /// Siguiente pregunta sugerida del banco (nil = continuar flujo normal).
    var suggestedNextQuestionKey: String?
}

// MARK: - Protocolo del servicio de IA del caso

@MainActor
protocol CaseAIServiceProtocol {
    var engineName: String { get }

    /// Procesa un mensaje del usuario en el contexto de la pregunta activa.
    func processUserMessage(_ message: String,
                            activeQuestion: IntakeQuestion?,
                            caseFile: CaseFile,
                            recentHistory: [String]) async -> IntakeProcessingResult

    /// Convierte una respuesta informal en redacción formal de ficha.
    func formalizeForFicha(fieldKey: String, rawText: String) -> String

    /// Detecta si un texto es una respuesta de "no sé" / desconocimiento.
    func classifyUnknownResponse(_ text: String) -> Bool

    /// Sugiere la siguiente pregunta del banco según el estado del caso.
    func suggestNextQuestion(for caseFile: CaseFile) -> IntakeQuestion?

    /// Genera la ficha técnica formal completa (determinista).
    func generateTechnicalFicha(for caseFile: CaseFile) -> String

    /// Campos obligatorios que siguen abiertos.
    func detectMissingFields(in caseFile: CaseFile) -> [IntakeQuestion]

    /// Claves de campos que contienen información sensible.
    func validateSensitiveInformation(in fields: [DetectedField]) -> [DetectedField]
}

// MARK: - Fábrica

enum ChatAIServiceFactory {
    @MainActor
    static func makeService() -> CaseAIServiceProtocol {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if SystemLanguageModel.default.availability == .available {
                return FoundationModelsChatAIService()
            }
        }
        #endif
        return MockChatAIService()
    }
}

// MARK: - Motor determinista de lenguaje (compartido)

/// Reglas de español coloquial mexicano. Deterministas a propósito:
/// la demo es reproducible y el dato nunca se inventa.
enum SpanishIntakeEngine {

    // MARK: Marcadores

    static let unknownMarkers = [
        "no sé", "no se", "no lo sé", "no lo se", "no me acuerdo", "no recuerdo",
        "no sabemos", "creo que no", "nadie sabe", "la neta no", "no estoy seguro",
        "no estoy segura", "no tengo ese dato", "luego lo confirmo", "ni idea",
        "ahorita no puedo pensar", "no podría decirte", "quién sabe", "quien sabe"
    ]

    static let stressMarkers = [
        "no puedo", "estoy desesperad", "estoy desesperado", "estoy desesperada",
        "no sé qué hacer", "no se que hacer", "tengo miedo", "ayúdame", "ayudame",
        "me siento mal", "estoy muy mal", "ya no aguanto", "estoy en shock"
    ]

    static let skipMarkers = ["saltar", "siguiente pregunta", "pasa a la siguiente", "luego", "después te digo", "despues te digo"]

    static let uncertaintyMarkers = [
        "creo", "como a", "más o menos", "mas o menos", "tal vez", "talvez",
        "quizá", "quiza", "a lo mejor", "puede que", "posiblemente", "parece",
        "no estoy segur", "aprox", "como las", "tipo"
    ]

    static let thirdPartyMarkers = [
        "me dijeron", "dicen que", "alguien vio", "alguien la vio", "me contaron",
        "según", "segun", "una vecina", "un vecino", "comentaron"
    ]

    static let certaintyMarkers = [
        "yo la vi", "yo lo vi", "estoy segur", "tengo captura", "tengo el chat",
        "tengo la conversación", "tengo la conversacion", "me consta"
    ]

    static let clothingKeywords = [
        "sudadera", "hoodie", "playera", "camisa", "blusa", "pantalón", "pantalon",
        "jeans", "mezclilla", "tenis", "zapatos", "falda", "vestido", "chamarra",
        "gorra", "mochila", "shorts", "uniforme", "abrigo", "botas"
    ]

    static let placeKeywords = [
        "uni", "universidad", "escuela", "prepa", "trabajo", "parada", "metro",
        "camión", "camion", "biblioteca", "casa de", "parque", "centro", "café",
        "cafetería", "cafeteria", "gimnasio", "iglesia", "mercado", "plaza"
    ]

    // MARK: Clasificación

    static func contains(_ text: String, anyOf markers: [String]) -> Bool {
        let lower = " " + text.lowercased() + " "
        return markers.contains { lower.contains($0) }
    }

    static func classify(_ text: String) -> UserReplyClassification {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .smalltalk }
        if contains(trimmed, anyOf: stressMarkers) { return .stress }
        if contains(trimmed, anyOf: skipMarkers) { return .skip }
        // "No sé" gana solo si el mensaje no trae también datos.
        if contains(trimmed, anyOf: unknownMarkers) {
            let stripped = stripUnknownPhrases(from: trimmed)
            if stripped.count < 6 { return .unknown }
        }
        return .informative
    }

    static func stripUnknownPhrases(from text: String) -> String {
        var result = text.lowercased()
        for marker in unknownMarkers {
            result = result.replacingOccurrences(of: marker, with: "")
        }
        return result.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }

    /// Confianza y validación sugerida según cómo se expresó la persona.
    static func assessConfidence(of text: String) -> (ConfidenceLevel, ValidationState) {
        if contains(text, anyOf: thirdPartyMarkers) { return (.low, .pending) }
        if contains(text, anyOf: uncertaintyMarkers) { return (.medium, .approximate) }
        if contains(text, anyOf: certaintyMarkers) { return (.high, .approximate) }
        return (.medium, .approximate) // Aun lo dicho con seguridad se valida.
    }

    // MARK: Extracción de campos

    /// Extrae todos los campos posibles de un mensaje. Si hay pregunta
    /// activa y no se detecta nada específico, el texto completo se
    /// interpreta como respuesta a esa pregunta.
    static func extractFields(from text: String, activeQuestion: IntakeQuestion?) -> [DetectedField] {
        var fields: [DetectedField] = []
        let (confidence, validation) = assessConfidence(of: text)

        func add(_ key: String, _ value: String) {
            guard let question = IntakeQuestionBank.question(for: key),
                  !value.isEmpty,
                  !fields.contains(where: { $0.key == key }) else { return }
            fields.append(DetectedField(
                key: key,
                label: question.formalLabel,
                formalValue: formalize(fieldKey: key, rawText: value, sourceText: text),
                rawText: value,
                confidence: confidence,
                suggestedValidation: validation
            ))
        }

        // Nombre: "se llama X", "su nombre es X", "es X"
        if let name = firstMatch(in: text, pattern: #"(?:se llama|su nombre es|mi hij[ao])\s+([A-ZÁÉÍÓÚÑ][\wáéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][\wáéíóúñ]+)?)"#) {
            add("personName", name)
        }

        // Edad: "tiene 22", "22 años"
        if let age = firstMatch(in: text, pattern: #"(?:tiene\s+)?(\d{1,2})\s*años"#)
            ?? firstMatch(in: text, pattern: #"tiene\s+(\d{1,2})\b"#) {
            add("age", age)
        }

        // Hora: "como a las 8", "a las 20:30", "tipo 9 de la noche"
        if let timePhrase = firstMatch(in: text, pattern: #"((?:como\s+)?(?:a\s+las|tipo)\s+\d{1,2}(?::\d{2})?(?:\s+de\s+la\s+(?:noche|tarde|mañana|madrugada))?(?:\s*[ap]m)?)"#, group: 1) {
            add("lastSeenTime", timePhrase)
        } else if !TimeTextDetector.detectTimes(in: text).isEmpty {
            add("lastSeenTime", TimeTextDetector.detectTimes(in: text).first!)
        }

        // Lugar: "saliendo de la uni", "en la parada", "iba a casa de…"
        if contains(text, anyOf: placeKeywords) {
            if let place = firstMatch(in: text, pattern: #"((?:salía de|saliendo de|iba a|estaba en|en la|en el|cerca de|por la|por el)\s+[\wáéíóúñ\s]{3,40})"#, group: 1) {
                add("lastSeenPlace", place.trimmingCharacters(in: .whitespaces))
            } else if activeQuestion?.key == "lastSeenPlace" {
                add("lastSeenPlace", text)
            }
        }

        // Ropa
        if contains(text, anyOf: clothingKeywords) {
            // Toma la parte de la frase que menciona ropa.
            if let clothing = firstMatch(in: text, pattern: #"((?:llevaba|traía|traia|vestía|vestia|con)\s+[\wáéíóúñ,\s]{4,80})"#, group: 1) {
                add("clothing", clothing)
            } else {
                add("clothing", text)
            }
        }

        // Teléfono / dispositivos
        if activeQuestion?.key == "phone" || text.lowercased().contains("celular") || text.lowercased().contains("teléfono") || text.lowercased().contains("telefono") {
            if activeQuestion?.key == "phone" || fields.isEmpty {
                add("phone", text)
            }
        }

        // Si nada específico se detectó, el texto responde a la pregunta activa.
        if fields.isEmpty, let activeQuestion, classify(text) == .informative {
            add(activeQuestion.key, text)
        }

        return fields
    }

    static func firstMatch(in text: String, pattern: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > group,
              let matchRange = Range(match.range(at: group), in: text) else { return nil }
        return String(text[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Formalización (informal → lenguaje técnico de ficha)

    static func formalize(fieldKey: String, rawText: String, sourceText: String) -> String {
        let uncertain = contains(sourceText, anyOf: uncertaintyMarkers)
        let thirdParty = contains(sourceText, anyOf: thirdPartyMarkers)
        let cleaned = cleanColloquialisms(rawText)

        switch fieldKey {
        case "personName":
            return cleaned.capitalized

        case "age":
            let digits = rawText.filter(\.isNumber)
            return digits.isEmpty ? cleaned : "\(digits) años" + (uncertain ? " (edad aproximada)" : "")

        case "lastSeenTime":
            if let formal = formalizeTime(from: rawText) {
                return "Aproximadamente a las \(formal) horas. Dato pendiente de confirmación."
            }
            return "Referencia horaria: \(cleaned). Dato pendiente de confirmación."

        case "lastSeenPlace":
            var place = cleaned
            place = place.replacingOccurrences(of: "la uni", with: "una zona universitaria")
            place = place.replacingOccurrences(of: "saliendo de", with: "al salir de")
            place = place.replacingOccurrences(of: "salía de", with: "al salir de")
            let suffix = (uncertain || thirdParty) ? " Dato pendiente de confirmación." : ""
            return place.prefix(1).capitalized + place.dropFirst() + "." + suffix

        case "clothing":
            var clothing = cleaned
            for verb in ["llevaba ", "traía ", "traia ", "vestía ", "vestia ", "con "] {
                if clothing.lowercased().hasPrefix(verb) {
                    clothing = String(clothing.dropFirst(verb.count))
                    break
                }
            }
            let note = uncertain ? " Dato pendiente de confirmación parcial." : ""
            return clothing.prefix(1).capitalized + clothing.dropFirst() + "." + note

        case "medical":
            return cleaned.prefix(1).capitalized + cleaned.dropFirst() + ". Información sensible: no se difunde."

        default:
            let suffix = (uncertain || thirdParty) ? " Dato pendiente de confirmación." : ""
            return cleaned.prefix(1).capitalized + cleaned.dropFirst() + (cleaned.hasSuffix(".") ? "" : ".") + suffix
        }
    }

    /// "como a las 8 de la noche" → "20:00"
    static func formalizeTime(from text: String) -> String? {
        let lower = text.lowercased()
        guard let hourText = firstMatch(in: lower, pattern: #"(\d{1,2})(?::(\d{2}))?"#) ,
              var hour = Int(hourText) else { return nil }
        let minutes = firstMatch(in: lower, pattern: #"\d{1,2}:(\d{2})"#) ?? "00"
        let isEvening = lower.contains("noche") || lower.contains("pm") || lower.contains("tarde")
        if isEvening && hour < 12 { hour += 12 }
        // Heurística suave: sin indicación, 1–7 suele ser tarde/noche en
        // este contexto, pero NO adivinamos: se deja tal cual y el estado
        // queda aproximado para que la persona lo confirme.
        guard (0...23).contains(hour) else { return nil }
        return String(format: "%02d:%@", hour, minutes)
    }

    static func cleanColloquialisms(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            ("hoodie", "sudadera"),
            ("la neta ", ""),
            ("creo que unos ", "posiblemente "),
            ("creo que ", "posiblemente "),
            ("como a las", "aproximadamente a las"),
            ("más o menos", "aproximadamente"),
            ("mas o menos", "aproximadamente"),
            ("ahorita", "en este momento")
        ]
        for (from, to) in replacements {
            result = result.replacingOccurrences(of: from, with: to, options: .caseInsensitive)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Respuestas empáticas (sobrias, sin promesas)

    static func empatheticReply(for classification: UserReplyClassification,
                                fieldCount: Int) -> String {
        switch classification {
        case .unknown:
            return "Está bien, no necesitas saberlo todo ahora. Lo dejamos pendiente y podemos volver a esto más adelante."
        case .stress:
            return "Entiendo. Vamos a hacerlo por partes. No necesitas resolver todo ahora. Te haré una sola pregunta y puedes saltarla si no sabes."
        case .skip:
            return "De acuerdo, la saltamos por ahora. Puedes volver a ella cuando quieras."
        case .smalltalk:
            return "Aquí estoy. Cuando quieras seguimos con la siguiente pregunta."
        case .informative:
            if fieldCount > 1 {
                return "Gracias, esto ayuda a ordenar la información. Detecté varios datos; revísalos antes de que los guarde."
            }
            return "Gracias. Te propongo guardarlo así; tú confirmas si es correcto."
        }
    }
}

// MARK: - Implementación local determinista (siempre disponible)

struct MockChatAIService: CaseAIServiceProtocol {

    var engineName: String { "Asistente local (reglas en el dispositivo)" }

    func processUserMessage(_ message: String,
                            activeQuestion: IntakeQuestion?,
                            caseFile: CaseFile,
                            recentHistory: [String]) async -> IntakeProcessingResult {
        // Pausa breve: el ritmo calmado es parte del diseño.
        try? await Task.sleep(for: .milliseconds(450))

        let classification = SpanishIntakeEngine.classify(message)
        let fields = classification == .informative
            ? SpanishIntakeEngine.extractFields(from: message, activeQuestion: activeQuestion)
            : []

        return IntakeProcessingResult(
            assistantReply: SpanishIntakeEngine.empatheticReply(for: classification, fieldCount: fields.count),
            detectedFields: fields,
            classification: classification,
            requiresHumanConfirmation: !fields.isEmpty,
            suggestedNextQuestionKey: nil
        )
    }

    func formalizeForFicha(fieldKey: String, rawText: String) -> String {
        SpanishIntakeEngine.formalize(fieldKey: fieldKey, rawText: rawText, sourceText: rawText)
    }

    func classifyUnknownResponse(_ text: String) -> Bool {
        SpanishIntakeEngine.classify(text) == .unknown
    }

    func suggestNextQuestion(for caseFile: CaseFile) -> IntakeQuestion? {
        let states = Dictionary(uniqueKeysWithValues: caseFile.questionStates.map { ($0.questionKey, $0) })
        return IntakeQuestionBank.sortedByPriority.first { question in
            guard let state = states[question.key] else { return true }
            return state.status == .pending
        }
    }

    func generateTechnicalFicha(for caseFile: CaseFile) -> String {
        FichaComposerService().composeFicha(for: caseFile)
    }

    func detectMissingFields(in caseFile: CaseFile) -> [IntakeQuestion] {
        let states = Dictionary(uniqueKeysWithValues: caseFile.questionStates.map { ($0.questionKey, $0) })
        return IntakeQuestionBank.sortedByPriority.filter { question in
            guard question.isRequired else { return false }
            guard let state = states[question.key] else { return true }
            return state.status.isOpen
        }
    }

    func validateSensitiveInformation(in fields: [DetectedField]) -> [DetectedField] {
        fields.filter { field in
            field.key == "medical"
                || field.formalValue.lowercased().contains("medicament")
                || field.formalValue.lowercased().contains("diagnóstic")
        }
    }
}

// MARK: - Implementación con Foundation Models

#if canImport(FoundationModels)
/// Usa el modelo del sistema SOLO para pulir la redacción empática.
/// La extracción y formalización de datos siguen siendo deterministas:
/// un modelo generativo no debe decidir los hechos de un expediente.
@available(iOS 26.0, *)
struct FoundationModelsChatAIService: CaseAIServiceProtocol {

    var engineName: String { "Foundation Models (en el dispositivo)" }

    private let base = MockChatAIService()

    private static let instructions = """
    Eres un asistente que acompaña con calma a una familia que reporta la \
    posible desaparición de una persona. Respondes en español, en una o dos \
    frases sobrias y empáticas. Prohibido: prometer resultados, dramatizar, \
    usar emojis, dar consejos psicológicos, inventar datos o afirmar hechos.
    """

    func processUserMessage(_ message: String,
                            activeQuestion: IntakeQuestion?,
                            caseFile: CaseFile,
                            recentHistory: [String]) async -> IntakeProcessingResult {
        var result = await base.processUserMessage(message,
                                                   activeQuestion: activeQuestion,
                                                   caseFile: caseFile,
                                                   recentHistory: recentHistory)
        // Pulido de tono con el modelo, con respaldo silencioso.
        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let prompt = """
            La persona escribió: "\(message)"
            Tu respuesta planeada es: "\(result.assistantReply)"
            Reescríbela manteniendo el mismo significado, en máximo 2 frases, \
            sin prometer nada y sin agregar información.
            """
            let response = try await session.respond(to: prompt)
            let polished = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !polished.isEmpty && polished.count < 300 {
                result.assistantReply = polished
            }
        } catch { }
        return result
    }

    func formalizeForFicha(fieldKey: String, rawText: String) -> String {
        base.formalizeForFicha(fieldKey: fieldKey, rawText: rawText)
    }

    func classifyUnknownResponse(_ text: String) -> Bool {
        base.classifyUnknownResponse(text)
    }

    func suggestNextQuestion(for caseFile: CaseFile) -> IntakeQuestion? {
        base.suggestNextQuestion(for: caseFile)
    }

    func generateTechnicalFicha(for caseFile: CaseFile) -> String {
        base.generateTechnicalFicha(for: caseFile)
    }

    func detectMissingFields(in caseFile: CaseFile) -> [IntakeQuestion] {
        base.detectMissingFields(in: caseFile)
    }

    func validateSensitiveInformation(in fields: [DetectedField]) -> [DetectedField] {
        base.validateSensitiveInformation(in: fields)
    }
}
#endif
