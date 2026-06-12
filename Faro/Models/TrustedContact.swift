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

    /// Símbolo según el parentesco escrito; si no se reconoce, usa el del rol.
    var symbolName: String {
        let text = relationship
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_MX"))
            .lowercased()

        let matches: [(keywords: [String], symbol: String)] = [
            (["mama", "madre", "papa", "padre"], "figure.and.child.holdinghands"),
            (["hermana", "hermano"], "person.2"),
            (["hija", "hijo"], "figure.child"),
            (["abuela", "abuelo"], "figure.walk"),
            (["tia", "tio", "prima", "primo", "sobrina", "sobrino"], "person.3"),
            (["esposa", "esposo", "pareja", "novia", "novio"], "heart"),
            (["amiga", "amigo"], "hand.wave"),
            (["vecina", "vecino"], "house"),
            (["abogada", "abogado", "licenciada", "licenciado", "legal"], "briefcase"),
            (["maestra", "maestro", "profesora", "profesor", "escuela"], "graduationcap"),
            (["companera", "companero", "trabajo", "colega"], "person.crop.rectangle"),
        ]

        for entry in matches where entry.keywords.contains(where: { text.contains($0) }) {
            return entry.symbol
        }
        return role.symbolName
    }
}
