//
//  CrisisFlowViewModel.swift
//  Faro
//
//  Estado del Modo Crisis: una pregunta por pantalla, todo se puede
//  saltar, y "No lo sé todavía" se convierte en pregunta pendiente
//  en lugar de en culpa.
//

import Foundation
import SwiftData
import SwiftUI

/// Pasos del flujo de crisis, en orden.
enum CrisisStep: Int, CaseIterable {
    case name
    case age
    case photo
    case lastSeenWhen
    case lastSeenWhere
    case clothing
    case phone
    case lastMessage
    case medical
    case frequentPlaces
    case companions
    case trustedContact

    var question: String {
        switch self {
        case .name:           return "¿Quién falta?"
        case .age:            return "¿Qué edad tiene, aproximadamente?"
        case .photo:          return "¿Tienes una foto reciente?"
        case .lastSeenWhen:   return "¿Cuándo fue la última vez que se le vio?"
        case .lastSeenWhere:  return "¿Dónde fue la última vez que se supo de ella o él?"
        case .clothing:       return "¿Qué ropa llevaba?"
        case .phone:          return "¿Llevaba celular?"
        case .lastMessage:    return "¿Hay un último mensaje?"
        case .medical:        return "¿Hay alguna condición médica importante?"
        case .frequentPlaces: return "¿Qué lugares frecuenta?"
        case .companions:     return "¿Con quién pudo haber estado?"
        case .trustedContact: return "¿Quién más puede ayudarte con esto?"
        }
    }

    var hint: String? {
        switch self {
        case .name:           return "Vamos paso a paso. Solo el nombre, como le dices tú."
        case .age:            return "Una edad aproximada es suficiente."
        case .photo:          return "Puede ser cualquier foto donde se le vea bien. Puedes agregar más después."
        case .lastSeenWhen:   return "Puede ser aproximado. Después se puede precisar."
        case .lastSeenWhere:  return "El lugar como lo recuerdes: una calle, una parada, un edificio."
        case .clothing:       return "Lo que recuerdes está bien. No necesitas tener todo ahora."
        case .phone:          return "Esto ayuda a saber qué señales buscar."
        case .lastMessage:    return "Si tienes una captura, podrás agregarla después en Evidencia."
        case .medical:        return "Medicamentos, tratamientos o condiciones que importen en la búsqueda."
        case .frequentPlaces: return "Casa de alguien, trabajo, escuela, cafés. Separados por comas."
        case .companions:     return "Personas con las que pudo haber estado ese día."
        case .trustedContact: return "Alguien de confianza que te apoye con la información."
        }
    }

    /// Pregunta pendiente que se genera al tocar "No lo sé todavía".
    var pendingQuestionText: String? {
        switch self {
        case .lastSeenWhen:   return "¿A qué hora se le vio por última vez?"
        case .lastSeenWhere:  return "¿Dónde se le vio por última vez?"
        case .clothing:       return "¿Qué ropa llevaba?"
        case .phone:          return "¿Llevaba celular?"
        case .lastMessage:    return "¿Cuál fue su último mensaje y a quién?"
        case .medical:        return "¿Hay alguna condición médica importante?"
        case .companions:     return "¿Con quién pudo haber estado?"
        default:              return nil
        }
    }
}

@Observable
@MainActor
final class CrisisFlowViewModel {

    var currentStep: CrisisStep = .name

    // Respuestas (todas opcionales: nada es obligatorio en crisis)
    var name = ""
    var ageText = ""
    var photoData: Data?
    var lastSeenDate: Date = .now
    var lastSeenDateAnswered = false
    var lastSeenPlace = ""
    var clothing = ""
    var carriedPhone: Bool?
    var lastMessageText = ""
    var medical = ""
    var frequentPlaces = ""
    var companions = ""
    var contactName = ""
    var contactPhone = ""
    var contactRelationship = ""

    /// Pasos donde la persona tocó "No lo sé todavía".
    private(set) var unknownSteps: Set<CrisisStep> = []

    var stepNumber: Int { CrisisStep.allCases.firstIndex(of: currentStep)! + 1 }
    var totalSteps: Int { CrisisStep.allCases.count }
    var isLastStep: Bool { currentStep == CrisisStep.allCases.last }

    func advance() {
        guard let index = CrisisStep.allCases.firstIndex(of: currentStep),
              index + 1 < CrisisStep.allCases.count else { return }
        currentStep = CrisisStep.allCases[index + 1]
    }

    func goBack() {
        guard let index = CrisisStep.allCases.firstIndex(of: currentStep), index > 0 else { return }
        currentStep = CrisisStep.allCases[index - 1]
    }

    func markUnknown() {
        unknownSteps.insert(currentStep)
        advance()
    }

    /// Crea el expediente con lo que haya. Lo que falte se convierte
    /// en preguntas pendientes, nunca en un bloqueo.
    func buildCase(in context: ModelContext) -> CaseFile {
        let title = name.isEmpty ? "Nuevo caso" : "Caso · \(name)"
        let caseFile = CaseFile(title: title)
        context.insert(caseFile)

        let person = MissingPerson(name: name)
        person.approximateAge = Int(ageText)
        person.photoData = photoData
        if lastSeenDateAnswered { person.lastSeenAt = lastSeenDate }
        person.lastSeenPlace = lastSeenPlace
        person.clothingDescription = clothing
        person.carriedPhone = carriedPhone
        person.medicalConditions = medical
        person.frequentPlaces = frequentPlaces
        person.possibleCompanions = companions
        caseFile.person = person

        // Último mensaje → evidencia inicial pendiente de validar.
        if !lastMessageText.isEmpty {
            let evidence = EvidenceItem(
                kind: .communication,
                title: "Último mensaje conocido",
                details: lastMessageText,
                source: "Registrado en Modo Crisis"
            )
            evidence.sensitivity = .privateInfo
            evidence.validationState = .pending
            caseFile.evidence.append(evidence)
        }

        // Última vez vista → primer evento del timeline (aproximado).
        if lastSeenDateAnswered {
            let event = TimelineEvent(
                date: lastSeenDate,
                title: "Última vez vista",
                details: lastSeenPlace.isEmpty ? "" : "Lugar: \(lastSeenPlace)",
                source: .manual,
                confidence: .medium,
                validationState: .approximate
            )
            event.isLastSeenMarker = true
            caseFile.timeline.append(event)
        }

        if !contactName.isEmpty {
            let contact = TrustedContact(
                name: contactName,
                relationship: contactRelationship,
                phone: contactPhone,
                role: .familyAdmin
            )
            caseFile.contacts.append(contact)
        }

        // "No lo sé todavía" → preguntas pendientes.
        for step in unknownSteps {
            if let text = step.pendingQuestionText {
                let question = CaseQuestion(
                    text: text,
                    whyItMatters: "Marcaste que aún no lo sabes. Puedes completarlo cuando tengas el dato.",
                    suggestedAutomatically: true
                )
                caseFile.questions.append(question)
            }
        }

        caseFile.touch()
        try? context.save()
        return caseFile
    }
}
