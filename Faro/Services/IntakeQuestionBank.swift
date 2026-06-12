//
//  IntakeQuestionBank.swift
//  Faro
//
//  Banco configurable de preguntas de intake. El flujo NO está
//  hardcodeado en las vistas: vive aquí, con categoría, prioridad,
//  campo formal y versión humana para el chatbot.
//
//  Diseño a futuro: el análisis de reportes históricos anonimizados
//  (ver TrainingPreparationService) podrá ajustar el orden, la
//  redacción y la prioridad de estas preguntas sin tocar la UI.
//

import Foundation

/// Categorías de información del intake.
enum IntakeCategory: String, Codable, CaseIterable {
    case identification   // Identificación
    case lastContact      // Último contacto
    case location         // Ubicación
    case physical         // Descripción física
    case clothing         // Vestimenta
    case health           // Salud
    case devices          // Dispositivos
    case transport        // Transporte
    case frequentPlaces   // Lugares frecuentes
    case contacts         // Contactos relevantes
    case evidence         // Evidencia disponible
    case diffusion        // Difusión

    var displayName: String {
        switch self {
        case .identification: return "Identificación"
        case .lastContact:    return "Último contacto"
        case .location:       return "Ubicación"
        case .physical:       return "Descripción física"
        case .clothing:       return "Vestimenta"
        case .health:         return "Salud"
        case .devices:        return "Dispositivos"
        case .transport:      return "Transporte"
        case .frequentPlaces: return "Lugares frecuentes"
        case .contacts:       return "Contactos relevantes"
        case .evidence:       return "Evidencia disponible"
        case .diffusion:      return "Difusión"
        }
    }
}

/// Una pregunta del banco: versión humana para el chat y
/// versión formal para la ficha técnica.
struct IntakeQuestion: Identifiable, Hashable {
    /// Clave estable del campo (se usa en QuestionState y FichaSourceField).
    let key: String
    let category: IntakeCategory
    /// Prioridad: menor = se pregunta antes.
    let priority: Int
    /// Cómo lo pregunta el chatbot (humano, calmado).
    let humanQuestion: String
    /// Nombre formal del campo en la ficha técnica.
    let formalLabel: String
    /// Explicación breve opcional bajo la pregunta.
    let hint: String?
    /// Obligatoria para considerar la ficha completa, o solo recomendada.
    let isRequired: Bool
    /// Versión suave para volver a preguntar un dato pendiente.
    let reaskQuestion: String
    /// Ejemplos de respuesta (para futura evaluación del flujo, no se muestran).
    let sampleAnswers: [String]

    var id: String { key }
}

/// Repositorio del flujo base. Orden por prioridad.
enum IntakeQuestionBank {

    static let all: [IntakeQuestion] = [
        IntakeQuestion(
            key: "personName",
            category: .identification,
            priority: 10,
            humanQuestion: "Vamos paso a paso. ¿Cómo se llama la persona?",
            formalLabel: "Nombre de la persona",
            hint: "Como le dices tú está bien.",
            isRequired: true,
            reaskQuestion: "Hay un dato que dejamos pendiente: ¿cómo se llama la persona?",
            sampleAnswers: ["Se llama Mariana", "Mariana López", "Mi hija Mariana"]
        ),
        IntakeQuestion(
            key: "age",
            category: .identification,
            priority: 20,
            humanQuestion: "¿Qué edad tiene, aproximadamente?",
            formalLabel: "Edad aproximada",
            hint: "Una edad aproximada es suficiente.",
            isRequired: true,
            reaskQuestion: "Cuando puedas: ¿qué edad tiene, más o menos?",
            sampleAnswers: ["22", "tiene 22 años", "como 20 y algo"]
        ),
        IntakeQuestion(
            key: "lastSeenTime",
            category: .lastContact,
            priority: 30,
            humanQuestion: "¿Cuándo fue la última vez que la viste o supiste de ella?",
            formalLabel: "Última vez vista / último contacto",
            hint: "Puede ser aproximado. Después se puede precisar.",
            isRequired: true,
            reaskQuestion: "Antes de cerrar la ficha, hay un dato que dejamos pendiente: ¿recuerdas aproximadamente a qué hora fue la última vez que se supo de ella?",
            sampleAnswers: ["como a las 8 creo", "ayer en la noche", "no sé"]
        ),
        IntakeQuestion(
            key: "lastSeenPlace",
            category: .location,
            priority: 40,
            humanQuestion: "¿Dónde fue la última vez que se supo de ella?",
            formalLabel: "Última ubicación referida",
            hint: "El lugar como lo recuerdes: una calle, una parada, un edificio.",
            isRequired: true,
            reaskQuestion: "Cuando lo tengas: ¿dónde fue la última vez que se supo de ella?",
            sampleAnswers: ["saliendo de la uni", "en la parada del camión", "no sabemos"]
        ),
        IntakeQuestion(
            key: "clothing",
            category: .clothing,
            priority: 50,
            humanQuestion: "¿Recuerdas qué ropa llevaba?",
            formalLabel: "Vestimenta referida",
            hint: "Lo que recuerdes está bien. No necesita ser perfecto.",
            isRequired: true,
            reaskQuestion: "Si ya lo recuerdas: ¿qué ropa llevaba ese día?",
            sampleAnswers: ["una hoodie gris y jeans", "creo que tenis blancos", "no me acuerdo"]
        ),
        IntakeQuestion(
            key: "physicalDescription",
            category: .physical,
            priority: 60,
            humanQuestion: "¿Cómo la describirías físicamente?",
            formalLabel: "Descripción física",
            hint: "Estatura, complexión, cabello, lentes… lo que ayude a reconocerla.",
            isRequired: true,
            reaskQuestion: "¿Podemos completar la descripción física? Estatura o complexión, por ejemplo.",
            sampleAnswers: ["mide como 1.60, delgada, cabello castaño"]
        ),
        IntakeQuestion(
            key: "distinguishingMarks",
            category: .physical,
            priority: 65,
            humanQuestion: "¿Tiene alguna seña particular? Tatuajes, cicatrices, lunares…",
            formalLabel: "Señas particulares",
            hint: nil,
            isRequired: false,
            reaskQuestion: "¿Recordaste alguna seña particular que ayude a identificarla?",
            sampleAnswers: ["un tatuaje en la muñeca", "ninguna que recuerde"]
        ),
        IntakeQuestion(
            key: "medical",
            category: .health,
            priority: 70,
            humanQuestion: "¿Hay alguna condición médica o medicamento importante?",
            formalLabel: "Condición médica relevante",
            hint: "Esta información se marca como sensible y no se difunde.",
            isRequired: false,
            reaskQuestion: "¿Hay algún dato de salud que debamos registrar? Se mantiene privado.",
            sampleAnswers: ["usa inhalador para el asma", "no"]
        ),
        IntakeQuestion(
            key: "phone",
            category: .devices,
            priority: 80,
            humanQuestion: "¿Llevaba celular u otro dispositivo?",
            formalLabel: "Dispositivos que portaba",
            hint: "Esto ayuda a saber qué señales buscar.",
            isRequired: false,
            reaskQuestion: "¿Sabes si llevaba su celular?",
            sampleAnswers: ["sí, su celular", "creo que sí", "no sé"]
        ),
        IntakeQuestion(
            key: "transport",
            category: .transport,
            priority: 90,
            humanQuestion: "¿Sabes si tomó algún transporte? ¿Cuál ruta o tipo?",
            formalLabel: "Transporte referido",
            hint: nil,
            isRequired: false,
            reaskQuestion: "¿Se supo algo del transporte que pudo tomar?",
            sampleAnswers: ["siempre toma el camión de la ruta 12", "iba caminando"]
        ),
        IntakeQuestion(
            key: "frequentPlaces",
            category: .frequentPlaces,
            priority: 100,
            humanQuestion: "¿Qué lugares frecuenta? Casa de alguien, trabajo, escuela…",
            formalLabel: "Lugares frecuentes",
            hint: nil,
            isRequired: false,
            reaskQuestion: "¿Quieres agregar lugares que frecuenta? Ayuda a orientar la búsqueda.",
            sampleAnswers: ["la biblioteca y un café cerca de la uni"]
        ),
        IntakeQuestion(
            key: "companions",
            category: .contacts,
            priority: 110,
            humanQuestion: "¿Con quién pudo haber estado ese día?",
            formalLabel: "Personas con las que pudo estar",
            hint: nil,
            isRequired: false,
            reaskQuestion: "¿Se sabe ya con quién pudo haber estado?",
            sampleAnswers: ["con sus compañeras del taller", "nadie sabe"]
        ),
        IntakeQuestion(
            key: "trustedContact",
            category: .contacts,
            priority: 120,
            humanQuestion: "¿Quién más te está ayudando? Puedo registrar a una persona de confianza.",
            formalLabel: "Contacto de referencia",
            hint: "Nombre y teléfono de alguien que apoye con la información.",
            isRequired: false,
            reaskQuestion: "Si quieres, registramos a una persona de confianza para el caso.",
            sampleAnswers: ["mi hermana Paola, 55 0000 0002"]
        ),
        IntakeQuestion(
            key: "evidenceAvailable",
            category: .evidence,
            priority: 130,
            humanQuestion: "¿Tienes mensajes, capturas, audios o fotos de ese día?",
            formalLabel: "Evidencia disponible referida",
            hint: "Después podrás agregarlos al expediente desde Evidencia.",
            isRequired: false,
            reaskQuestion: "¿Encontraste mensajes o capturas de ese día que podamos registrar?",
            sampleAnswers: ["tengo el último chat", "hay una nota de voz"]
        )
    ]

    static var sortedByPriority: [IntakeQuestion] {
        all.sorted { $0.priority < $1.priority }
    }

    static func question(for key: String) -> IntakeQuestion? {
        all.first { $0.key == key }
    }

    /// Campos obligatorios para considerar la ficha razonablemente completa.
    static var requiredKeys: [String] {
        all.filter(\.isRequired).map(\.key)
    }
}
