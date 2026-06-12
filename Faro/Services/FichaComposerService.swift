//
//  FichaComposerService.swift
//  Faro
//
//  Composición determinista de la ficha técnica formal. No usa IA:
//  la redacción final de un documento de búsqueda debe ser predecible,
//  sobria y nunca inventar datos. Si un dato falta, se dice que falta.
//

import Foundation

struct FichaComposerService {

    private let notAvailable = "No disponible al momento de la elaboración de la ficha."
    private let pendingNote = "Pendiente de confirmar."

    /// Construye el contenido formal de la ficha desde el estado del caso.
    func composeFicha(for caseFile: CaseFile) -> String {
        let states = Dictionary(uniqueKeysWithValues: caseFile.questionStates.map { ($0.questionKey, $0) })
        let person = caseFile.person

        func value(for key: String, fallback: String? = nil) -> String {
            if let state = states[key], !state.formalValue.isEmpty, !state.status.isOpen {
                var text = state.formalValue
                if state.validation == .approximate && !text.lowercased().contains("aproximad") && !text.lowercased().contains("pendiente") {
                    text += " (dato aproximado)"
                }
                return text
            }
            if let state = states[key], state.status == .dontKnow {
                return notAvailable
            }
            if let fallback, !fallback.isEmpty { return fallback }
            return pendingNote
        }

        var sections: [String] = []

        sections.append("""
        FICHA TÉCNICA DE PERSONA REPORTADA COMO NO LOCALIZADA
        Documento de organización familiar de información. No constituye denuncia oficial.
        Elaborada con FARO el \(Date.now.formatted(date: .long, time: .shortened)).
        """)

        sections.append("""
        1. DATOS GENERALES DE LA PERSONA
        Nombre: \(value(for: "personName", fallback: person?.name))
        Edad: \(value(for: "age", fallback: person?.approximateAge.map { "\($0) años" }))
        """)

        sections.append("""
        2. ÚLTIMA VEZ VISTA / ÚLTIMO CONTACTO
        Referencia temporal: \(value(for: "lastSeenTime", fallback: person?.lastSeenAt.map { "Registrada el " + $0.formatted(date: .long, time: .shortened) }))
        Última ubicación conocida: \(value(for: "lastSeenPlace", fallback: person?.lastSeenPlace))
        """)

        sections.append("""
        3. DESCRIPCIÓN FÍSICA
        \(value(for: "physicalDescription", fallback: person?.physicalDescription))
        """)

        sections.append("""
        4. VESTIMENTA
        \(value(for: "clothing", fallback: person?.clothingDescription))
        """)

        sections.append("""
        5. SEÑAS PARTICULARES
        \(value(for: "distinguishingMarks"))
        """)

        let medicalValue = value(for: "medical", fallback: person?.medicalConditions)
        sections.append("""
        6. CONDICIÓN MÉDICA RELEVANTE (INFORMACIÓN SENSIBLE)
        \(medicalValue)
        """)

        sections.append("""
        7. LUGARES FRECUENTES
        \(value(for: "frequentPlaces", fallback: person?.frequentPlaces))
        """)

        let contactsList = caseFile.contacts.map { "• \($0.name) (\($0.relationship.isEmpty ? $0.role.displayName : $0.relationship))" }
        sections.append("""
        8. PERSONAS Y CONTACTOS RELEVANTES
        \(value(for: "companions", fallback: person?.possibleCompanions))
        \(contactsList.isEmpty ? "" : "Red de apoyo registrada:\n" + contactsList.joined(separator: "\n"))
        """)

        let evidenceList = caseFile.evidence.map {
            "• \($0.title) — \($0.kind.displayName), \($0.validationState.displayName)"
        }
        sections.append("""
        9. EVIDENCIA DISPONIBLE
        \(evidenceList.isEmpty ? value(for: "evidenceAvailable") : evidenceList.joined(separator: "\n"))
        """)

        let timeline = caseFile.sortedTimeline
            .filter { $0.validationState != .discarded }
            .prefix(8)
            .map { "• \($0.date.formatted(date: .abbreviated, time: .shortened)) — \($0.title) [\($0.validationState.displayName)]" }
        sections.append("""
        10. TIMELINE RESUMIDO
        \(timeline.isEmpty ? "Sin eventos registrados al momento." : timeline.joined(separator: "\n"))
        """)

        let openStates = caseFile.questionStates.filter { $0.status.isOpen }
        let pendingList = openStates.compactMap { state -> String? in
            guard let question = IntakeQuestionBank.question(for: state.questionKey) else { return nil }
            return "• \(question.formalLabel)"
        }
        sections.append("""
        11. INFORMACIÓN PENDIENTE DE CONFIRMAR
        \(pendingList.isEmpty ? "No hay campos pendientes registrados." : pendingList.joined(separator: "\n"))
        """)

        sections.append("""
        12. OBSERVACIONES
        \(caseFile.notes.isEmpty ? "Sin observaciones adicionales." : caseFile.notes)

        ―――
        Esta ficha organiza información proporcionada por la familia y debe ser
        revisada por ella antes de usarse. Los datos marcados como aproximados o
        pendientes no están confirmados. FARO no valida hechos ni sustituye
        procesos oficiales.
        """)

        return sections.joined(separator: "\n\n")
    }

    /// Campos de origen para guardar junto a la ficha (trazabilidad).
    func snapshotSourceFields(for caseFile: CaseFile) -> [FichaSourceField] {
        IntakeQuestionBank.sortedByPriority.map { question in
            let state = caseFile.questionStates.first { $0.questionKey == question.key }
            return FichaSourceField(
                key: question.key,
                label: question.formalLabel,
                value: state?.formalValue.isEmpty == false ? state!.formalValue : notAvailable,
                statusRaw: state?.statusRaw ?? IntakeQuestionStatus.pending.rawValue,
                validationRaw: state?.validationRaw ?? ValidationState.pending.rawValue
            )
        }
    }
}
