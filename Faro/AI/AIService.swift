//
//  AIService.swift
//  Faro
//
//  IA en el dispositivo al servicio de la familia, no al centro del producto.
//  Implementación real con Foundation Models cuando el sistema la ofrece;
//  si no, un asistente local determinista (MockAIService) mantiene la demo
//  completa y honesta: la UI siempre dice qué motor está activo.
//
//  Regla innegociable: todo lo que produce este servicio entra al
//  expediente como "pendiente de revisar", nunca como confirmado.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Fábrica: elige el mejor motor disponible

enum AIServiceFactory {
    /// Devuelve Foundation Models si el dispositivo lo soporta;
    /// si no, el asistente local de demo.
    static func makeService() -> AIProcessingServiceProtocol {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if SystemLanguageModel.default.availability == .available {
                return FoundationModelsAIService()
            }
        }
        #endif
        return MockAIService()
    }
}

// MARK: - Implementación con Foundation Models (Apple Intelligence)

#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct FoundationModelsAIService: AIProcessingServiceProtocol {

    var engineName: String { "Foundation Models (en el dispositivo)" }
    var isOnDeviceModelAvailable: Bool { true }

    private static let instructions = """
    Eres un asistente que ayuda a una familia a organizar información durante \
    la posible desaparición de una persona. Responde siempre en español, con \
    tono sobrio, claro y empático. Nunca inventes datos. Nunca afirmes nada \
    como hecho confirmado. Nunca acuses a nadie ni especules sobre culpables. \
    Tu trabajo es organizar, resumir y clasificar, no concluir.
    """

    /// El mock comparte la lógica determinista como respaldo ante cualquier error.
    private let fallback = MockAIService()

    func classifyEvidence(text: String) async -> EvidenceClassificationSuggestion {
        let prompt = """
        Clasifica este texto de evidencia. Responde SOLO en este formato exacto:
        TIPO: [comunicacion|testimonio|ubicacion|documento|fotografia|medico|contacto|rumor|noconfirmado|otro]
        SENSIBILIDAD: [publica|privada|sensible|incompleta|urgente]
        RAZON: [una frase breve]

        Texto: \(text)
        """
        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(to: prompt)
            if let parsed = Self.parseClassification(response.content) {
                return parsed
            }
        } catch {
            // Cae al asistente local: la familia nunca se queda sin respuesta.
        }
        return await fallback.classifyEvidence(text: text)
    }

    func suggestTimelineEvents(from text: String, referenceDate: Date) async -> [TimelineEventSuggestion] {
        // La detección de horas es determinista (regex compartida);
        // el modelo solo redacta el título sugerido.
        var suggestions = await fallback.suggestTimelineEvents(from: text, referenceDate: referenceDate)
        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let prompt = """
            Resume en una sola frase corta (máximo 10 palabras) qué momento \
            describe este texto, sin afirmar que está confirmado:
            \(text)
            """
            let response = try await session.respond(to: prompt)
            let title = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty, !suggestions.isEmpty {
                suggestions[0].title = title
            }
        } catch { }
        return suggestions
    }

    func summarizeCase(_ caseFile: CaseFile) async -> String {
        let facts = await fallback.summarizeCase(caseFile)
        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let prompt = """
            Reescribe estos datos de un expediente como un párrafo breve en \
            prosa natural y humana, como si se lo contaras con calma a un \
            familiar. Reglas estrictas:
            - Un solo párrafo corrido, sin listas, sin números, sin viñetas, \
            sin encabezados.
            - Tono cálido pero sobrio; no dramatices ni minimices.
            - No agregues información nueva ni afirmes nada como confirmado.
            - Máximo 4 oraciones.

            Datos: \(facts)
            """
            let response = try await session.respond(to: prompt)
            let text = Self.flattenToParagraph(response.content)
            return text.isEmpty ? facts : text
        } catch {
            return facts
        }
    }

    func draftShareText(personName: String, age: Int?, zone: String,
                        date: Date?, clothing: String, contact: String,
                        tone: PosterTone) async -> String {
        // El texto de difusión usa la plantilla determinista del mock:
        // en difusión pública no se deja espacio a variación del modelo.
        await fallback.draftShareText(personName: personName, age: age, zone: zone,
                                      date: date, clothing: clothing, contact: contact,
                                      tone: tone)
    }

    /// Si el modelo devuelve listas o viñetas a pesar del prompt,
    /// las aplana a un párrafo corrido.
    private static func flattenToParagraph(_ raw: String) -> String {
        let lines = raw
            .components(separatedBy: .newlines)
            .map { line -> String in
                var cleaned = line.trimmingCharacters(in: .whitespaces)
                // Quita prefijos tipo "1.", "2)", "-", "•", "*"
                while let first = cleaned.first,
                      first.isNumber || "-•*.)".contains(first) {
                    cleaned.removeFirst()
                    cleaned = cleaned.trimmingCharacters(in: .whitespaces)
                }
                return cleaned
            }
            .filter { !$0.isEmpty }
        return lines.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Parsing

    private static func parseClassification(_ text: String) -> EvidenceClassificationSuggestion? {
        func value(after key: String) -> String? {
            text.components(separatedBy: .newlines)
                .first { $0.uppercased().contains(key) }?
                .components(separatedBy: ":").dropFirst().joined(separator: ":")
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
        }
        guard let kindText = value(after: "TIPO") else { return nil }

        let kind: EvidenceKind = switch true {
        case kindText.contains("comunic"):  .communication
        case kindText.contains("testimon"): .testimony
        case kindText.contains("ubicac"):   .locationInfo
        case kindText.contains("document"): .document
        case kindText.contains("foto"):     .photo
        case kindText.contains("medic"):    .medical
        case kindText.contains("contact"):  .contact
        case kindText.contains("rumor"):    .rumor
        case kindText.contains("noconfirm"): .unconfirmed
        default: .other
        }

        let sensText = value(after: "SENSIBILIDAD") ?? ""
        let sensitivity: SensitivityLevel = switch true {
        case sensText.contains("public"):  .publicSafe
        case sensText.contains("privad"):  .privateInfo
        case sensText.contains("sensib"):  .sensitive
        case sensText.contains("urgent"):  .urgent
        default: .incomplete
        }

        let rationale = value(after: "RAZON") ?? "Clasificación sugerida por el modelo en el dispositivo."

        return EvidenceClassificationSuggestion(kind: kind, sensitivity: sensitivity, rationale: rationale)
    }
}
#endif

// MARK: - Asistente local de demo (determinista, sin red)

/// Clasificador por reglas: mantiene el flujo completo cuando
/// Foundation Models no está disponible. La UI lo identifica como
/// "Asistente local de demo" — honestidad técnica ante el jurado.
struct MockAIService: AIProcessingServiceProtocol {

    var engineName: String { "Asistente local de demo" }
    var isOnDeviceModelAvailable: Bool { false }

    func classifyEvidence(text: String) async -> EvidenceClassificationSuggestion {
        try? await Task.sleep(for: .milliseconds(500))
        let lower = text.lowercased()

        if lower.contains("dicen que") || lower.contains("alguien comentó") || lower.contains("rumor") {
            return .init(kind: .rumor, sensitivity: .sensitive,
                         rationale: "Parece información de terceros sin confirmar. Los rumores nunca se publican.")
        }
        if lower.contains("medicament") || lower.contains("tratamiento") || lower.contains("diagnóstic")
            || lower.contains("alergi") {
            return .init(kind: .medical, sensitivity: .sensitive,
                         rationale: "Contiene datos de salud. Se marcan como sensibles y no se comparten automáticamente.")
        }
        if lower.contains("vi a") || lower.contains("me dijo") || lower.contains("testig") {
            return .init(kind: .testimony, sensitivity: .privateInfo,
                         rationale: "Parece el relato de una persona. Los nombres de testigos se protegen.")
        }
        if lower.contains("ubicaci") || lower.contains("parada") || lower.contains("calle")
            || lower.contains("colonia") || lower.contains("metro") {
            return .init(kind: .locationInfo, sensitivity: .privateInfo,
                         rationale: "Menciona lugares. Las ubicaciones precisas se mantienen privadas por defecto.")
        }
        if TimeTextDetector.detectTimes(in: text).isEmpty == false || lower.contains("mensaje")
            || lower.contains("whatsapp") || lower.contains("✓") {
            return .init(kind: .communication, sensitivity: .privateInfo,
                         rationale: "Parece una conversación. Las conversaciones privadas no se publican.")
        }
        return .init(kind: .unconfirmed, sensitivity: .incomplete,
                     rationale: "No hay suficiente contexto. Revisa el tipo y la sensibilidad manualmente.")
    }

    func suggestTimelineEvents(from text: String, referenceDate: Date) async -> [TimelineEventSuggestion] {
        let times = TimeTextDetector.detectTimes(in: text)
        let calendar = Calendar.current

        guard !times.isEmpty else {
            return [TimelineEventSuggestion(
                date: nil,
                rawTimeText: nil,
                title: "Momento mencionado en la evidencia",
                details: String(text.prefix(160)),
                confidence: .low
            )]
        }

        return times.prefix(3).map { timeText in
            var date: Date?
            let cleaned = timeText.replacingOccurrences(of: " ", with: "").lowercased()
            let parts = cleaned.components(separatedBy: ":")
            if parts.count >= 2, var hour = Int(parts[0]),
               let minute = Int(parts[1].prefix(2)) {
                if cleaned.contains("p"), hour < 12 { hour += 12 }
                if cleaned.contains("a"), hour == 12 { hour = 0 }
                date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: referenceDate)
            }
            return TimelineEventSuggestion(
                date: date,
                rawTimeText: timeText,
                title: "Mensaje o actividad alrededor de las \(timeText)",
                details: String(text.prefix(160)),
                confidence: .medium
            )
        }
    }

    func summarizeCase(_ caseFile: CaseFile) async -> String {
        let person = caseFile.person
        let name = person?.displayName ?? "La persona"
        let confirmed = caseFile.timeline.filter { $0.validationState == .confirmed }.count
        let pending = caseFile.pendingReviewCount

        var parts: [String] = []
        if let lastSeen = person?.lastSeenAt {
            let formatted = lastSeen.formatted(date: .abbreviated, time: .shortened)
            let place = (person?.lastSeenPlace.isEmpty == false) ? " en \(person!.lastSeenPlace)" : ""
            parts.append("\(name) fue vista por última vez el \(formatted)\(place) (dato según el expediente).")
        } else {
            parts.append("Aún no se registra la última vez que se vio a \(name).")
        }
        parts.append("El expediente tiene \(confirmed) eventos confirmados y \(pending) elementos pendientes de revisión humana.")
        if !caseFile.pendingQuestions.isEmpty {
            parts.append("Hay \(caseFile.pendingQuestions.count) preguntas críticas sin resolver.")
        }
        return parts.joined(separator: " ")
    }

    func draftShareText(personName: String, age: Int?, zone: String,
                        date: Date?, clothing: String, contact: String,
                        tone: PosterTone) async -> String {
        let ageText = age.map { ", \($0) años" } ?? ""
        let dateText = date.map { " el \($0.formatted(date: .long, time: .shortened))" } ?? ""
        let zoneText = zone.isEmpty ? "" : " en \(zone)"
        let clothingText = clothing.isEmpty ? "" : " Vestía \(clothing)."
        let contactText = contact.isEmpty
            ? "Si tienes información, contacta a la familia."
            : "Si tienes información, comunícate al \(contact)."

        switch tone {
        case .formal:
            return "Buscamos a \(personName)\(ageText). Fue vista por última vez\(dateText)\(zoneText).\(clothingText) \(contactText) Gracias por compartir de manera responsable."
        case .community:
            return "Vecinas y vecinos: estamos buscando a \(personName)\(ageText). La última vez que se le vio fue\(dateText)\(zoneText).\(clothingText) Cualquier dato ayuda. \(contactText)"
        case .urgent:
            return "BÚSQUEDA ACTIVA: \(personName)\(ageText). Última vez vista\(dateText)\(zoneText).\(clothingText) \(contactText) Por favor comparte solo esta información verificada."
        }
    }
}
