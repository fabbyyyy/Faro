//
//  PublicPoster.swift
//  Faro
//
//  Ficha pública ética. Guarda qué se incluyó, qué se excluyó
//  y por qué. La explicación de cada exclusión es parte del producto:
//  proteger a la familia también es informarla.
//

import Foundation
import SwiftData

/// Campo excluido de la ficha pública con su razón.
struct ExcludedField: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var fieldName: String
    var reason: String
}

@Model
final class PublicPoster {
    var id: UUID = UUID()
    var createdAt: Date = Date.now

    /// Texto corto de difusión (WhatsApp / redes), sobrio y sin amarillismo.
    var shareText: String = ""
    var tone: PosterTone = PosterTone.formal

    /// Campos visibles en la ficha (nombre, edad, zona general...).
    var includedFields: [String] = []

    /// Campos excluidos con su explicación de seguridad.
    var excludedFields: [ExcludedField] = []

    /// La familia revisó y aprobó la ficha antes de compartirla.
    var approvedByFamily: Bool = false

    /// Contacto que se muestra públicamente (definido por la familia).
    var publicContact: String = ""

    // MARK: Sobrescrituras editables (vacío = usar el dato del expediente)
    // Permiten ajustar la ficha pública sin alterar los datos del caso.

    var overrideName: String = ""
    var overrideAgeText: String = ""
    var overrideZone: String = ""
    var overrideDescription: String = ""

    /// Foto específica para la ficha pública (si la familia elige otra).
    @Attribute(.externalStorage)
    var overridePhotoData: Data?

    var caseFile: CaseFile?

    init(tone: PosterTone = .formal) {
        self.id = UUID()
        self.tone = tone
    }

    // MARK: Valores efectivos (sobrescritura si existe, si no el del caso)

    func effectiveName(_ person: MissingPerson?) -> String {
        overrideName.isEmpty ? (person?.displayName ?? "") : overrideName
    }

    func effectiveAgeText(_ person: MissingPerson?) -> String {
        overrideAgeText.isEmpty
            ? (person?.approximateAge.map { "\($0) años" } ?? "")
            : overrideAgeText
    }

    func effectiveDescription(_ person: MissingPerson?) -> String {
        overrideDescription.isEmpty ? (person?.physicalDescription ?? "") : overrideDescription
    }

    func effectivePhoto(_ person: MissingPerson?) -> Data? {
        overridePhotoData ?? person?.photoData
    }
}
