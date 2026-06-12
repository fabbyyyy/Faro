//
//  GeneratedReport.swift
//  Faro
//
//  Reporte formal generado a partir del expediente.
//  Se guarda con versión y estado de edición: la familia
//  siempre puede revisarlo y ajustarlo antes de usarlo.
//

import Foundation
import SwiftData

@Model
final class GeneratedReport {
    var id: UUID = UUID()
    var kind: ReportKind = ReportKind.authority

    /// Contenido del reporte en texto estructurado (Markdown ligero).
    var content: String = ""

    var createdAt: Date = Date.now

    /// Verdadero si la familia editó el contenido después de generarlo.
    var wasEdited: Bool = false

    var version: Int = 1

    var caseFile: CaseFile?

    init(kind: ReportKind, content: String, version: Int = 1) {
        self.id = UUID()
        self.kind = kind
        self.content = content
        self.version = version
    }
}
