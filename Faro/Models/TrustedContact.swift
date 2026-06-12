//
//  TrustedContact.swift
//  Faro
//
//  Red de confianza del caso. No toda persona debe ver todo:
//  el rol define qué información le corresponde.
//  (MVP local-first; la sincronización segura es trabajo futuro.)
//

import Foundation
import SwiftData

@Model
final class TrustedContact {
    var id: UUID = UUID()
    var name: String = ""
    var relationship: String = ""
    var phone: String = ""
    var role: ContactRole = ContactRole.observer

    /// Notas sobre el apoyo que da esta persona.
    var notes: String = ""

    var caseFile: CaseFile?

    init(name: String, relationship: String = "", phone: String = "", role: ContactRole = .observer) {
        self.id = UUID()
        self.name = name
        self.relationship = relationship
        self.phone = phone
        self.role = role
    }
}
