//
//  MissingPerson.swift
//  Faro
//
//  Datos de la persona que falta. Cada campo puede estar vacío:
//  el Modo Crisis permite saltar cualquier pregunta y completar después.
//

import Foundation
import SwiftData

@Model
final class MissingPerson {
    var id: UUID = UUID()
    var name: String = ""

    /// Edad aproximada. Nil cuando la familia aún no la confirma.
    var approximateAge: Int?

    var physicalDescription: String = ""
    var clothingDescription: String = ""

    /// Foto local opcional (no se sube a ningún servidor).
    @Attribute(.externalStorage)
    var photoData: Data?

    /// Última vez vista: fecha/hora y descripción del lugar.
    var lastSeenAt: Date?
    var lastSeenPlace: String = ""

    /// Si llevaba celular, condición médica relevante, etc.
    var carriedPhone: Bool?
    var medicalConditions: String = ""
    var frequentPlaces: String = ""
    var possibleCompanions: String = ""

    /// Estado general de la información de la persona.
    var infoState: ValidationState = ValidationState.pending

    var notes: String = ""

    var caseFile: CaseFile?

    init(name: String = "") {
        self.id = UUID()
        self.name = name
    }

    var displayName: String {
        name.isEmpty ? "Sin nombre todavía" : name
    }
}
