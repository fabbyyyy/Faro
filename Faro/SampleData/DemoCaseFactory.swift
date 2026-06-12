//
//  DemoCaseFactory.swift
//  Faro
//
//  Caso de demostración con datos 100% ficticios y seguros.
//  Permite presentar todo el flujo sin información real, sin permisos
//  y sin internet. Puede reiniciarse desde Ajustes.
//

import Foundation
import SwiftData

enum DemoCaseFactory {

    static let demoTitle = "Caso demo · Mariana López"

    /// Crea (o reemplaza) el caso demo en el contexto dado.
    @discardableResult
    static func makeDemoCase(in context: ModelContext) -> CaseFile {
        // Fechas relativas a "ayer" para que la demo siempre se vea reciente.
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!
        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: yesterday)!
        }

        let caseFile = CaseFile(title: demoTitle, isDemo: true)
        context.insert(caseFile)

        // MARK: Persona (ficticia)
        let person = MissingPerson(name: "Mariana López")
        person.approximateAge = 22
        person.physicalDescription = "1.62 m, complexión delgada, cabello castaño largo, lentes de pasta negros."
        person.clothingDescription = "Sudadera gris con capucha, jeans azules, tenis blancos, mochila verde."
        person.lastSeenAt = at(21, 30)
        person.lastSeenPlace = "Zona universitaria norte (ficticia), cerca de la biblioteca central"
        person.carriedPhone = true
        person.medicalConditions = "Usa medicamento diario para asma (salbutamol)."
        person.frequentPlaces = "Biblioteca central, cafetería La Espiga, casa de su prima en colonia Roble."
        person.possibleCompanions = "Compañeras del taller de cerámica de los martes."
        person.infoState = .confirmed
        caseFile.person = person

        // MARK: Evidencia
        let lastMessage = EvidenceItem(
            kind: .communication,
            title: "Último mensaje de WhatsApp",
            details: "Captura del último chat: «voy saliendo de la biblioteca, ya casi llego a la parada» enviado a las 21:47.",
            source: "Captura de WhatsApp"
        )
        lastMessage.referenceDate = at(21, 47)
        lastMessage.sensitivity = .privateInfo
        lastMessage.validationState = .confirmed
        lastMessage.extractedText = "Mariana: voy saliendo de la biblioteca\nya casi llego a la parada\n21:47 ✓✓"
        caseFile.evidence.append(lastMessage)

        let voiceNote = EvidenceItem(
            kind: .communication,
            title: "Nota de voz a su mamá",
            details: "Transcripción simulada: «Hola ma, ya voy a la parada del camión, se me hizo tarde en la biblioteca. Te marco llegando.»",
            source: "Nota de voz (transcripción simulada)"
        )
        voiceNote.referenceDate = at(21, 49)
        voiceNote.sensitivity = .privateInfo
        voiceNote.validationState = .pending
        voiceNote.extractedText = "Hola ma, ya voy a la parada del camión, se me hizo tarde en la biblioteca. Te marco llegando."
        voiceNote.classificationSuggestedByAI = true
        caseFile.evidence.append(voiceNote)

        let sharedLocation = EvidenceItem(
            kind: .locationInfo,
            title: "Última ubicación compartida",
            details: "Ubicación en vivo compartida con su hermana hasta las 21:52, cerca de la parada Roble Norte.",
            source: "Ubicación compartida"
        )
        sharedLocation.referenceDate = at(21, 52)
        sharedLocation.sensitivity = .sensitive
        sharedLocation.validationState = .confirmed
        caseFile.evidence.append(sharedLocation)

        let rumorItem = EvidenceItem(
            kind: .rumor,
            title: "Comentario sin confirmar de un vecino",
            details: "«Dicen que la vieron subir a un camión blanco». Sin confirmar; no debe difundirse.",
            source: "Comentario de tercero"
        )
        rumorItem.referenceDate = at(22, 10)
        rumorItem.sensitivity = .sensitive
        rumorItem.validationState = .pending
        rumorItem.classificationSuggestedByAI = true
        caseFile.evidence.append(rumorItem)

        // MARK: Timeline
        let leftLibrary = TimelineEvent(
            date: at(21, 47),
            title: "Envía su último mensaje al salir de la biblioteca",
            details: "«voy saliendo de la biblioteca, ya casi llego a la parada»",
            source: .ocr,
            confidence: .high,
            validationState: .confirmed
        )
        leftLibrary.relatedEvidence.append(lastMessage)
        caseFile.timeline.append(leftLibrary)

        let voiceEvent = TimelineEvent(
            date: at(21, 49),
            title: "Envía nota de voz a su mamá",
            details: "Dice que va hacia la parada del camión.",
            source: .transcript,
            confidence: .medium,
            validationState: .pending
        )
        voiceEvent.relatedEvidence.append(voiceNote)
        caseFile.timeline.append(voiceEvent)

        let lastSeenA = TimelineEvent(
            date: at(21, 30),
            title: "Una compañera la ve salir del edificio de la biblioteca",
            details: "Relato de su compañera del taller.",
            source: .testimony,
            confidence: .medium,
            validationState: .approximate
        )
        lastSeenA.isLastSeenMarker = true
        caseFile.timeline.append(lastSeenA)

        let lastSeenB = TimelineEvent(
            date: at(22, 05),
            title: "Vecina cree haberla visto en la parada Roble Norte",
            details: "Horario distinto al del mensaje. Requiere confirmación.",
            source: .testimony,
            confidence: .low,
            validationState: .pending
        )
        lastSeenB.isLastSeenMarker = true
        caseFile.timeline.append(lastSeenB)

        let locationEnd = TimelineEvent(
            date: at(21, 52),
            title: "Se interrumpe la ubicación compartida",
            details: "La ubicación en vivo con su hermana se detiene cerca de la parada.",
            source: .location,
            confidence: .high,
            validationState: .confirmed
        )
        locationEnd.relatedEvidence.append(sharedLocation)
        caseFile.timeline.append(locationEnd)

        // MARK: Ubicaciones (coordenadas ficticias de demostración)
        let library = LocationRecord(
            name: "Biblioteca central (ficticia)",
            latitude: 19.3321, longitude: -99.1862,
            kind: .frequent, precision: .approximate,
            source: "Lugar frecuente confirmado por la familia"
        )
        library.generalZoneName = "Zona universitaria norte"
        library.validationState = .confirmed
        caseFile.locations.append(library)

        let busStop = LocationRecord(
            name: "Parada Roble Norte (ficticia)",
            latitude: 19.3367, longitude: -99.1810,
            kind: .lastKnown, precision: .exact,
            source: "Última ubicación compartida"
        )
        busStop.generalZoneName = "Zona universitaria norte"
        busStop.validationState = .confirmed
        caseFile.locations.append(busStop)

        let cafe = LocationRecord(
            name: "Cafetería La Espiga (ficticia)",
            latitude: 19.3290, longitude: -99.1845,
            kind: .frequent, precision: .approximate,
            source: "Lugar frecuente"
        )
        cafe.generalZoneName = "Zona universitaria norte"
        cafe.validationState = .approximate
        caseFile.locations.append(cafe)

        let reportedSpot = LocationRecord(
            name: "Punto mencionado por vecina",
            latitude: 19.3402, longitude: -99.1788,
            kind: .mentioned, precision: .approximate,
            source: "Testimonio sin confirmar"
        )
        reportedSpot.generalZoneName = "Zona universitaria norte"
        reportedSpot.validationState = .pending
        caseFile.locations.append(reportedSpot)

        // MARK: Contactos de confianza
        let mom = TrustedContact(name: "Rosa Hernández", relationship: "Mamá",
                                 phone: "55 0000 0001", role: .familyAdmin)
        let sister = TrustedContact(name: "Paola López", relationship: "Hermana",
                                    phone: "55 0000 0002", role: .documentation)
        let friend = TrustedContact(name: "Daniel Ruiz", relationship: "Amigo de la familia",
                                    phone: "55 0000 0003", role: .diffusion)
        let lawyer = TrustedContact(name: "Lic. Carmen Soto", relationship: "Clínica legal universitaria",
                                    phone: "55 0000 0004", role: .legal)
        caseFile.contacts.append(contentsOf: [mom, sister, friend, lawyer])

        // MARK: Tareas recomendadas
        let task1 = CaseTask(title: "Confirmar el horario de la última vez vista",
                             details: "Hay dos horarios distintos (21:30 y 22:05). Definir cuál está confirmado.",
                             priority: .high)
        let task2 = CaseTask(title: "Pedir lista de asistencia del taller de cerámica",
                             details: "Puede confirmar con quién estuvo durante la tarde.",
                             priority: .medium)
        let task3 = CaseTask(title: "Revisar si la parada Roble Norte tiene cámaras",
                             details: "Preguntar en los comercios cercanos a la parada.",
                             priority: .high)
        caseFile.tasks.append(contentsOf: [task1, task2, task3])

        // MARK: Preguntas pendientes
        let q1 = CaseQuestion(text: "¿Quién fue la última persona que habló con ella?",
                              whyItMatters: "Ayuda a confirmar el horario y el estado de ánimo.",
                              suggestedAutomatically: true)
        let q2 = CaseQuestion(text: "¿Llevaba identificación?",
                              whyItMatters: "Es un dato que las autoridades suelen pedir primero.",
                              suggestedAutomatically: true)
        let q3 = CaseQuestion(text: "¿Tomó el camión de la ruta de siempre?",
                              whyItMatters: "Define la zona a revisar primero.",
                              suggestedAutomatically: true)
        let q4 = CaseQuestion(text: "¿Hay una foto reciente de cuerpo completo?",
                              whyItMatters: "Mejora la ficha de búsqueda.",
                              suggestedAutomatically: true)
        let q5 = CaseQuestion(text: "¿Llevaba su medicamento para el asma?",
                              whyItMatters: "Información médica clave para priorizar la búsqueda.",
                              suggestedAutomatically: true)
        caseFile.questions.append(contentsOf: [q1, q2, q3, q4, q5])

        // MARK: Ficha pública precargada
        let poster = PosterBuilderService().buildPoster(for: caseFile, tone: .community)
        poster.shareText = "Vecinas y vecinos: estamos buscando a Mariana López, 22 años. La última vez que se le vio fue ayer por la noche en la zona universitaria norte. Vestía sudadera gris con capucha, jeans azules y tenis blancos. Cualquier dato ayuda. Si tienes información, comunícate al 55 0000 0001."
        poster.approvedByFamily = false
        caseFile.posters.append(poster)

        // MARK: Reporte precargado
        let reportContent = ReportBuilderService().buildReport(for: caseFile, kind: .authority)
        let report = GeneratedReport(kind: .authority, content: reportContent)
        caseFile.reports.append(report)

        caseFile.notes = "Caso de demostración con datos ficticios. Ninguna persona real está involucrada."
        caseFile.touch()
        return caseFile
    }

    /// Elimina el caso demo existente y crea uno nuevo.
    static func resetDemoCase(in context: ModelContext) {
        let descriptor = FetchDescriptor<CaseFile>(predicate: #Predicate { $0.isDemo })
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
        }
        makeDemoCase(in: context)
        try? context.save()
    }
}
