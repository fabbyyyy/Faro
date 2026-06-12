//
//  PosterBuilderService.swift
//  Faro
//
//  Filtro ético de la ficha pública. Es código determinista a propósito:
//  qué se comparte y qué se protege no puede depender de un modelo.
//  Cada exclusión se explica a la familia.
//

import Foundation

struct PosterBuilderService {

    /// Construye la ficha pública del caso aplicando el filtro de seguridad.
    /// Los campos sensibles quedan excluidos por defecto con su razón.
    func buildPoster(for caseFile: CaseFile, tone: PosterTone) -> PublicPoster {
        let poster = PublicPoster(tone: tone)
        let person = caseFile.person

        var included: [String] = []
        var excluded: [ExcludedField] = []

        // MARK: Información adecuada para difusión

        if person?.name.isEmpty == false { included.append("Nombre") }
        if person?.approximateAge != nil { included.append("Edad") }
        if person?.photoData != nil { included.append("Foto autorizada por la familia") }
        if person?.lastSeenAt != nil { included.append("Fecha de última vez vista") }
        if person?.physicalDescription.isEmpty == false { included.append("Descripción física") }
        if person?.clothingDescription.isEmpty == false { included.append("Ropa que llevaba") }

        // Zona general en lugar de ubicación precisa.
        let zone = generalZone(for: caseFile)
        if !zone.isEmpty { included.append("Zona general de última vez vista") }

        // MARK: Exclusiones de seguridad (siempre explicadas)

        if caseFile.locations.contains(where: { $0.precision == .exact }) {
            excluded.append(ExcludedField(
                fieldName: "Dirección exacta",
                reason: "Una dirección precisa puede poner en riesgo a la familia. Se comparte solo la zona general."
            ))
        }
        if caseFile.evidence.contains(where: { $0.kind == .testimony }) {
            excluded.append(ExcludedField(
                fieldName: "Nombres de testigos",
                reason: "Es información sensible que puede exponer a quienes ayudan."
            ))
        }
        if person?.medicalConditions.isEmpty == false
            || caseFile.evidence.contains(where: { $0.kind == .medical }) {
            excluded.append(ExcludedField(
                fieldName: "Datos médicos",
                reason: "Los datos de salud son privados. Compártelos solo con autoridades o personal médico."
            ))
        }
        if caseFile.evidence.contains(where: { $0.kind == .communication }) {
            excluded.append(ExcludedField(
                fieldName: "Conversaciones privadas",
                reason: "Publicar mensajes privados puede distorsionar la búsqueda y exponer a la persona."
            ))
        }
        if person?.frequentPlaces.isEmpty == false {
            excluded.append(ExcludedField(
                fieldName: "Rutinas y lugares frecuentes",
                reason: "Las rutinas personales pueden ser usadas con malas intenciones."
            ))
        }
        if caseFile.evidence.contains(where: { $0.kind == .rumor || $0.kind == .unconfirmed }) {
            excluded.append(ExcludedField(
                fieldName: "Rumores y datos no confirmados",
                reason: "Difundir información sin confirmar puede dañar la búsqueda. Solo se comparte lo validado."
            ))
        }

        poster.includedFields = included
        poster.excludedFields = excluded
        poster.publicContact = caseFile.contacts.first { $0.role == .familyAdmin }?.phone ?? ""
        return poster
    }

    /// Zona general que sí puede mencionarse en público.
    func generalZone(for caseFile: CaseFile) -> String {
        if let zone = caseFile.locations
            .first(where: { $0.kind == .lastKnown && !$0.generalZoneName.isEmpty })?
            .generalZoneName {
            return zone
        }
        return caseFile.person?.lastSeenPlace ?? ""
    }
}
