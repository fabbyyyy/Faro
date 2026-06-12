//
//  CaseScoringService.swift
//  Faro
//
//  Completitud orientativa del expediente. Reglas simples y transparentes.
//  Nunca se presenta como un valor oficial: solo guía qué falta.
//

import Foundation

struct CaseScoringService: CaseScoringServiceProtocol {

    func evaluate(_ caseFile: CaseFile) -> [CompletenessRule] {
        let person = caseFile.person

        return [
            CompletenessRule(
                title: "Foto reciente",
                isMet: person?.photoData != nil,
                suggestion: "Agrega una foto reciente. Ayuda mucho en la ficha de búsqueda."
            ),
            CompletenessRule(
                title: "Nombre",
                isMet: person?.name.isEmpty == false,
                suggestion: "Registra el nombre de la persona."
            ),
            CompletenessRule(
                title: "Edad aproximada",
                isMet: person?.approximateAge != nil,
                suggestion: "Agrega la edad aproximada."
            ),
            CompletenessRule(
                title: "Descripción física",
                isMet: person?.physicalDescription.isEmpty == false,
                suggestion: "Describe estatura, complexión o señas particulares."
            ),
            CompletenessRule(
                title: "Última ubicación",
                isMet: person?.lastSeenPlace.isEmpty == false || caseFile.locations.contains { $0.kind == .lastKnown },
                suggestion: "Registra dónde se le vio o se supo de la persona por última vez."
            ),
            CompletenessRule(
                title: "Última hora vista",
                isMet: person?.lastSeenAt != nil,
                suggestion: "Registra cuándo fue la última vez. Puede ser aproximado."
            ),
            CompletenessRule(
                title: "Ropa que llevaba",
                isMet: person?.clothingDescription.isEmpty == false,
                suggestion: "Describe la ropa que llevaba, si la recuerdas."
            ),
            CompletenessRule(
                title: "Contacto de confianza",
                isMet: !caseFile.contacts.isEmpty,
                suggestion: "Agrega al menos una persona de confianza a la red del caso."
            ),
            CompletenessRule(
                title: "Evidencia inicial",
                isMet: !caseFile.evidence.isEmpty,
                suggestion: "Guarda el último mensaje, captura o nota que tengas."
            ),
            CompletenessRule(
                title: "Línea de tiempo iniciada",
                isMet: !caseFile.timeline.isEmpty,
                suggestion: "Registra al menos un momento del día en la línea de tiempo."
            ),
            CompletenessRule(
                title: "Ficha pública preparada",
                isMet: !caseFile.posters.isEmpty,
                suggestion: "Cuando estés lista o listo, genera la ficha pública ética."
            )
        ]
    }
}

extension Array where Element == CompletenessRule {
    /// Porcentaje orientativo de completitud (0–100).
    var completenessPercent: Int {
        guard !isEmpty else { return 0 }
        return Int((Double(filter(\.isMet).count) / Double(count)) * 100)
    }

    var unmet: [CompletenessRule] { filter { !$0.isMet } }
}
