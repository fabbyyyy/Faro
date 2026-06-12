//
//  LocationRecord.swift
//  Faro
//
//  Ubicación dentro del mapa privado del expediente.
//  Los puntos precisos nunca pasan a la ficha pública por defecto:
//  ahí solo se comparte la zona general.
//

import Foundation
import SwiftData

@Model
final class LocationRecord {
    var id: UUID = UUID()
    var name: String = ""
    var details: String = ""

    var latitude: Double = 0
    var longitude: Double = 0

    var kind: LocationKind = LocationKind.mentioned
    var precision: LocationPrecision = LocationPrecision.approximate
    var source: String = ""
    var validationState: ValidationState = ValidationState.pending
    var createdAt: Date = Date.now

    /// Zona general que sí puede mencionarse públicamente
    /// ("zona universitaria norte"), en lugar de la dirección exacta.
    var generalZoneName: String = ""

    /// Evento del timeline al que corresponde, si existe.
    var relatedEvent: TimelineEvent?

    var caseFile: CaseFile?

    init(name: String,
         latitude: Double,
         longitude: Double,
         kind: LocationKind = .mentioned,
         precision: LocationPrecision = .approximate,
         source: String = "") {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.kind = kind
        self.precision = precision
        self.source = source
    }
}
