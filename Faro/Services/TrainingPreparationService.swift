//
//  TrainingPreparationService.swift
//  Faro
//
//  ════════════════════════════════════════════════════════════════════
//  ARQUITECTURA PREPARADA PARA APRENDIZAJE FUTURO — NO ENTRENA NADA HOY
//  ════════════════════════════════════════════════════════════════════
//
//  Visión: en el futuro, reportes históricos REALES (policiacos o de
//  colectivos) podrían ayudar a mejorar FARO: qué preguntas son más
//  útiles, en qué orden, cómo estructurar fichas, cómo detectar campos
//  faltantes y cómo redactar en lenguaje técnico.
//
//  Esa evolución SOLO es legítima bajo condiciones estrictas:
//
//  1. CONSENTIMIENTO explícito e informado de las familias.
//  2. ANONIMIZACIÓN completa: cero datos personales (nombres, teléfonos,
//     direcciones, fotos, texto libre). Solo estructura: qué campos se
//     llenaron, en qué orden, con qué nivel de confianza.
//  3. AUTORIZACIÓN INSTITUCIONAL: convenios con fiscalías, colectivos o
//     universidades que custodian los expedientes originales.
//  4. REVISIÓN ÉTICA independiente antes de cualquier uso de datos.
//  5. SEGURIDAD: los datos estructurales nunca deben permitir reidentificar
//     a una persona ni reconstruir un caso.
//
//  Por eso, en esta versión:
//  - NO se entrena ningún modelo en el dispositivo ni fuera de él.
//  - NO existe exportación habilitada en la interfaz.
//  - NO se usan reportes reales: el caso demo es 100 % ficticio.
//  - Lo que SÍ existe es el esquema (AnonymizedCaseSchema): la forma
//    exacta de los datos estructurales que un dataset futuro usaría,
//    demostrando que la app puede evolucionar sin rediseñarse.
//
//  El QuestionBank (IntakeQuestionBank) es la otra mitad de esta
//  arquitectura: como las preguntas son datos y no código, un análisis
//  futuro de reportes anonimizados podría reordenar prioridades o
//  ajustar redacciones sin tocar la interfaz.
//

import Foundation

// MARK: - Esquema anonimizado (estructura, nunca contenido)

/// Representación SIN DATOS PERSONALES de cómo se construyó un expediente.
/// Nota: no contiene valores, texto libre, nombres, fechas absolutas,
/// ubicaciones ni nada que permita identificar un caso real.
struct AnonymizedCaseSchema: Codable {
    /// Versión del esquema (para evolución del dataset).
    var schemaVersion: Int = 1

    /// Por cada campo del QuestionBank: cómo terminó, no qué decía.
    struct FieldOutcome: Codable {
        var fieldKey: String            // p. ej. "clothing"
        var category: String            // p. ej. "vestimenta"
        var finalStatus: String         // answered / dontKnow / skipped…
        var validation: String          // confirmed / approximate / pending
        var confidence: String          // high / medium / low
        var timesAsked: Int             // cuántas veces se preguntó
        var answeredOnReask: Bool       // ¿se resolvió en una repregunta?
    }

    var fieldOutcomes: [FieldOutcome]

    /// Métricas agregadas del flujo (sin contenido).
    var totalMessages: Int
    var unknownResponses: Int       // cuántas veces se respondió "no sé"
    var sessionsToComplete: Int     // cuántas sesiones tomó
    var fichaVersionsGenerated: Int
    var completenessPercent: Int
}

// MARK: - Servicio de preparación (deshabilitado por diseño)

/// Pipeline conceptual de aprendizaje. En esta versión solo puede
/// construir el esquema anonimizado EN MEMORIA para validar el diseño;
/// no exporta, no transmite y no persiste nada fuera de SwiftData.
struct TrainingPreparationService {

    /// Bandera de consentimiento. Siempre falsa en esta versión:
    /// no existe UI para activarla, a propósito. Una versión futura
    /// requeriría un flujo de consentimiento informado y revisable.
    static let exportConsentGranted = false

    /// Construye la estructura anonimizada de un caso (solo estructura).
    /// Útil hoy para validar el diseño del dataset; inerte por lo demás.
    func buildAnonymizedSchema(for caseFile: CaseFile) -> AnonymizedCaseSchema {
        let outcomes = caseFile.questionStates.compactMap { state -> AnonymizedCaseSchema.FieldOutcome? in
            guard let question = IntakeQuestionBank.question(for: state.questionKey) else { return nil }
            return AnonymizedCaseSchema.FieldOutcome(
                fieldKey: state.questionKey,
                category: question.category.rawValue,
                finalStatus: state.statusRaw,
                validation: state.validationRaw,
                confidence: state.confidenceRaw,
                timesAsked: state.askCount,
                answeredOnReask: state.askCount > 1 && !state.status.isOpen
            )
        }

        return AnonymizedCaseSchema(
            fieldOutcomes: outcomes,
            totalMessages: caseFile.chatSessions.reduce(0) { $0 + $1.messages.count },
            unknownResponses: caseFile.questionStates.filter { $0.status == .dontKnow }.count,
            sessionsToComplete: caseFile.chatSessions.count,
            fichaVersionsGenerated: caseFile.fichas.filter { $0.status != .draft }.count,
            completenessPercent: AppServices.shared.scoring.evaluate(caseFile).completenessPercent
        )
    }

    /// Punto de exportación futuro. Bloqueado por diseño: devuelve nil
    /// mientras no exista consentimiento, anonimización verificada,
    /// autorización institucional y revisión ética.
    func exportForFutureDataset(caseFile: CaseFile) -> Data? {
        guard Self.exportConsentGranted else { return nil }
        // Inalcanzable en esta versión. Si algún día se habilita, este
        // método solo serializaría AnonymizedCaseSchema (estructura,
        // nunca contenido) y requeriría revisión adicional de PII.
        return try? JSONEncoder().encode(buildAnonymizedSchema(for: caseFile))
    }
}
