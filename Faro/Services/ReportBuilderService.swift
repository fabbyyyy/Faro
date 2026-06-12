//
//  ReportBuilderService.swift
//  Faro
//
//  Genera el reporte formal para autoridad o colectivo a partir del
//  expediente. Separa explícitamente hechos confirmados de pendientes:
//  esa distinción es el valor del documento.
//

import Foundation

struct ReportBuilderService {

    func buildReport(for caseFile: CaseFile, kind: ReportKind) -> String {
        let person = caseFile.person
        let dateFormatter: (Date) -> String = { $0.formatted(date: .long, time: .shortened) }

        var lines: [String] = []

        lines.append("REPORTE DE ORGANIZACIÓN DE INFORMACIÓN")
        lines.append(kind == .authority
                     ? "Preparado para presentación ante autoridad"
                     : "Preparado para colectivo de búsqueda o acompañamiento")
        lines.append("Generado el \(dateFormatter(.now)) con FARO")
        lines.append("")

        // MARK: Datos de la persona
        lines.append("1. DATOS DE LA PERSONA")
        lines.append("Nombre: \(person?.displayName ?? "Sin registrar")")
        if let age = person?.approximateAge {
            lines.append("Edad aproximada: \(age) años")
        }
        if let desc = person?.physicalDescription, !desc.isEmpty {
            lines.append("Descripción física: \(desc)")
        }
        if let clothing = person?.clothingDescription, !clothing.isEmpty {
            lines.append("Ropa la última vez vista: \(clothing)")
        }
        if let medical = person?.medicalConditions, !medical.isEmpty {
            lines.append("Condición médica relevante (información sensible): \(medical)")
        }
        lines.append("")

        // MARK: Última vez vista
        lines.append("2. ÚLTIMA VEZ VISTA")
        if let lastSeen = person?.lastSeenAt {
            lines.append("Fecha y hora: \(dateFormatter(lastSeen))")
        } else {
            lines.append("Fecha y hora: pendiente de confirmar")
        }
        if let place = person?.lastSeenPlace, !place.isEmpty {
            lines.append("Lugar: \(place)")
        }
        lines.append("")

        // MARK: Hechos confirmados vs pendientes
        let confirmed = caseFile.sortedTimeline.filter { $0.validationState == .confirmed }
        let unconfirmed = caseFile.sortedTimeline.filter {
            $0.validationState == .pending || $0.validationState == .approximate || $0.validationState == .contradictory
        }

        lines.append("3. HECHOS CONFIRMADOS POR LA FAMILIA")
        if confirmed.isEmpty {
            lines.append("Aún no hay hechos confirmados.")
        }
        for event in confirmed {
            lines.append("• \(dateFormatter(event.date)) — \(event.title) (fuente: \(event.source.displayName))")
        }
        lines.append("")

        lines.append("4. INFORMACIÓN PENDIENTE O APROXIMADA")
        if unconfirmed.isEmpty {
            lines.append("No hay información pendiente de revisión.")
        }
        for event in unconfirmed {
            lines.append("• \(dateFormatter(event.date)) — \(event.title) [\(event.validationState.displayName)]")
        }
        lines.append("")

        // MARK: Evidencia
        lines.append("5. EVIDENCIA DISPONIBLE")
        if caseFile.evidence.isEmpty {
            lines.append("Sin evidencia registrada todavía.")
        }
        for item in caseFile.evidence {
            lines.append("• \(item.title) — \(item.kind.displayName), \(item.sensitivity.displayName), estado: \(item.validationState.displayName)")
        }
        lines.append("")

        // MARK: Ubicaciones
        lines.append("6. UBICACIONES RELEVANTES")
        let activeLocations = caseFile.locations.filter { $0.kind != .discardedPlace }
        if activeLocations.isEmpty {
            lines.append("Sin ubicaciones registradas todavía.")
        }
        for location in activeLocations {
            lines.append("• \(location.name) — \(location.kind.displayName), precisión: \(location.precision.displayName), estado: \(location.validationState.displayName)")
        }
        lines.append("")

        // MARK: Contactos
        lines.append("7. CONTACTOS IMPORTANTES")
        if caseFile.contacts.isEmpty {
            lines.append("Sin contactos registrados todavía.")
        }
        for contact in caseFile.contacts {
            let phone = contact.phone.isEmpty ? "" : " — \(contact.phone)"
            lines.append("• \(contact.name) (\(contact.role.displayName))\(phone)")
        }
        lines.append("")

        // MARK: Preguntas urgentes
        lines.append("8. PREGUNTAS URGENTES POR RESOLVER")
        let pending = caseFile.pendingQuestions
        if pending.isEmpty {
            lines.append("No hay preguntas pendientes registradas.")
        }
        for question in pending {
            lines.append("• \(question.text)")
        }
        lines.append("")

        // MARK: Nota obligatoria de alcance
        lines.append("―――")
        lines.append("NOTA: Este documento fue generado para organizar información y debe ser revisado por la familia antes de usarse. No constituye una denuncia oficial ni un documento legal. FARO no sustituye a las autoridades, colectivos ni asesoría profesional.")

        return lines.joined(separator: "\n")
    }
}
