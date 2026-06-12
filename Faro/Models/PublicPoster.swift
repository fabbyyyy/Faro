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

    var caseFile: CaseFile?

    init(tone: PosterTone = .formal) {
        self.id = UUID()
        self.tone = tone
    }
}
