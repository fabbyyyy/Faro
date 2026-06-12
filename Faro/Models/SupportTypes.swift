//
//  SupportTypes.swift
//  Faro
//
//  Enums compartidos por los modelos del expediente.
//  Regla central de FARO: ningún dato es definitivo sin validación humana,
//  por eso casi todo lleva un ValidationState explícito.
//

import Foundation

/// Estado de validación humana de cualquier dato del expediente.
/// La IA puede sugerir, pero solo una persona confirma.
enum ValidationState: String, Codable, CaseIterable, Identifiable {
    case confirmed      // Revisado y confirmado por la familia
    case pending        // Sugerido (por IA o terceros), aún sin revisar
    case approximate    // Revisado, pero impreciso (hora/lugar aproximado)
    case contradictory  // Existe otro dato que lo contradice
    case discarded      // Revisado y descartado

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .confirmed:     return "Confirmado"
        case .pending:       return "Pendiente de revisar"
        case .approximate:   return "Aproximado"
        case .contradictory: return "Contradictorio"
        case .discarded:     return "Descartado"
        }
    }

    var symbolName: String {
        switch self {
        case .confirmed:     return "checkmark.seal.fill"
        case .pending:       return "clock.badge.questionmark"
        case .approximate:   return "circle.dashed"
        case .contradictory: return "exclamationmark.triangle"
        case .discarded:     return "xmark.circle"
        }
    }

    /// Descripción accesible: el estado nunca depende solo del color.
    var accessibilityDescription: String {
        switch self {
        case .confirmed:     return "Dato confirmado por una persona"
        case .pending:       return "Dato pendiente de revisión humana"
        case .approximate:   return "Dato aproximado, revisado pero impreciso"
        case .contradictory: return "Dato con contradicción detectada, requiere revisión"
        case .discarded:     return "Dato descartado"
        }
    }
}

/// Nivel de confianza de un dato según su origen (no sustituye la validación).
enum ConfidenceLevel: String, Codable, CaseIterable, Identifiable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high:   return "Confianza alta"
        case .medium: return "Confianza media"
        case .low:    return "Confianza baja"
        }
    }
}

/// Origen de un evento o dato.
enum DataSource: String, Codable, CaseIterable, Identifiable {
    case manual          // Escrito directamente por la familia
    case ocr             // Extraído de una captura con Vision
    case transcript      // Transcripción de audio
    case location        // Registro de ubicación
    case aiSuggestion    // Sugerido por IA local
    case testimony       // Relato de un tercero

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual:       return "Registro manual"
        case .ocr:          return "Texto extraído de captura"
        case .transcript:   return "Transcripción de audio"
        case .location:     return "Ubicación"
        case .aiSuggestion: return "Sugerencia de IA"
        case .testimony:    return "Testimonio"
        }
    }

    /// Verdadero cuando el dato fue producido por un proceso automático
    /// y por lo tanto requiere validación humana obligatoria.
    var requiresHumanReview: Bool {
        switch self {
        case .ocr, .transcript, .aiSuggestion: return true
        case .manual, .location, .testimony:   return false
        }
    }
}

/// Tipo de evidencia dentro del Vault.
enum EvidenceKind: String, Codable, CaseIterable, Identifiable {
    case communication   // Mensajes, capturas de chat
    case testimony       // Relatos de personas
    case locationInfo    // Datos de ubicación
    case document        // Documentos, identificaciones
    case photo           // Fotografías
    case medical         // Datos médicos
    case contact         // Datos de contacto
    case rumor           // Rumor: nunca se publica
    case unconfirmed     // Información sin confirmar
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .communication: return "Comunicación"
        case .testimony:     return "Testimonio"
        case .locationInfo:  return "Ubicación"
        case .document:      return "Documento"
        case .photo:         return "Fotografía"
        case .medical:       return "Dato médico"
        case .contact:       return "Contacto"
        case .rumor:         return "Rumor"
        case .unconfirmed:   return "No confirmado"
        case .other:         return "Otro"
        }
    }

    var symbolName: String {
        switch self {
        case .communication: return "bubble.left.and.bubble.right"
        case .testimony:     return "person.wave.2"
        case .locationInfo:  return "mappin.and.ellipse"
        case .document:      return "doc.text"
        case .photo:         return "photo"
        case .medical:       return "cross.case"
        case .contact:       return "person.crop.circle"
        case .rumor:         return "questionmark.bubble"
        case .unconfirmed:   return "questionmark.circle"
        case .other:         return "tray"
        }
    }

    /// Confianza orientativa según el tipo de origen. Determinista y
    /// explicable: una captura original pesa más que un rumor. No sustituye
    /// la validación humana; solo orienta qué tan firme es el dato.
    var sourceConfidence: ConfidenceLevel {
        switch self {
        case .photo, .document, .communication: return .high
        case .locationInfo, .contact, .medical: return .medium
        case .testimony, .rumor, .unconfirmed, .other: return .low
        }
    }

    /// Por qué ese origen tiene esa confianza (texto breve para la UI).
    var sourceConfidenceRationale: String {
        switch self {
        case .photo, .document:
            return "Documento o imagen original: por lo general, confianza alta."
        case .communication:
            return "Captura o mensaje original: confianza alta como registro, sujeto a tu revisión."
        case .locationInfo:
            return "Dato de ubicación: confianza media; puede estar desactualizado."
        case .contact:
            return "Dato de contacto: confianza media."
        case .medical:
            return "Dato de salud: confianza media; se trata como sensible."
        case .testimony:
            return "Relato de un tercero: confianza baja hasta confirmarse."
        case .rumor:
            return "Rumor: no confirmado. Nunca se publica."
        case .unconfirmed:
            return "Información sin confirmar: confianza baja."
        case .other:
            return "Origen sin clasificar: confianza baja."
        }
    }
}

/// Sensibilidad de una evidencia. Define qué puede salir del expediente.
enum SensitivityLevel: String, Codable, CaseIterable, Identifiable {
    case publicSafe   // Puede incluirse en una ficha pública
    case privateInfo  // Solo para la familia
    case sensitive    // Nunca se comparte automáticamente
    case incomplete   // Falta contexto para clasificarla
    case urgent       // Requiere atención inmediata de la familia

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .publicSafe:  return "Pública"
        case .privateInfo: return "Privada"
        case .sensitive:   return "Sensible"
        case .incomplete:  return "Incompleta"
        case .urgent:      return "Urgente"
        }
    }

    /// Texto explícito de accesibilidad: lo sensible se dice, no solo se colorea.
    var accessibilityDescription: String {
        switch self {
        case .publicSafe:  return "Información pública, puede compartirse"
        case .privateInfo: return "Información privada, solo para la familia"
        case .sensitive:   return "Información sensible, no se comparte automáticamente"
        case .incomplete:  return "Información incompleta, falta contexto"
        case .urgent:      return "Información urgente, requiere atención"
        }
    }

    var symbolName: String {
        switch self {
        case .publicSafe:  return "globe"
        case .privateInfo: return "lock"
        case .sensitive:   return "exclamationmark.lock"
        case .incomplete:  return "circle.dotted"
        case .urgent:      return "bolt"
        }
    }
}

/// Rol de un contacto dentro de la red de confianza.
enum ContactRole: String, Codable, CaseIterable, Identifiable {
    case familyAdmin    // Administra el expediente
    case documentation  // Apoya capturando y organizando información
    case diffusion      // Coordina difusión responsable
    case legal          // Contacto legal o de acompañamiento
    case emotional      // Apoyo emocional
    case observer       // Solo consulta

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .familyAdmin:   return "Administra el caso"
        case .documentation: return "Apoyo de documentación"
        case .diffusion:     return "Difusión"
        case .legal:         return "Contacto legal"
        case .emotional:     return "Apoyo emocional"
        case .observer:      return "Observador"
        }
    }

    var permissionsSummary: String {
        switch self {
        case .familyAdmin:   return "Puede ver y editar todo el expediente"
        case .documentation: return "Puede agregar evidencia y notas"
        case .diffusion:     return "Solo ve la ficha pública aprobada"
        case .legal:         return "Puede ver el reporte formal completo"
        case .emotional:     return "Ve el estado general, sin datos sensibles"
        case .observer:      return "Solo consulta información confirmada"
        }
    }

    var symbolName: String {
        switch self {
        case .familyAdmin:   return "person.badge.key"
        case .documentation: return "tray.full"
        case .diffusion:     return "megaphone"
        case .legal:         return "briefcase"
        case .emotional:     return "heart"
        case .observer:      return "eye"
        }
    }
}

/// Prioridad de una acción pendiente.
enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case high, medium, low

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high:   return "Prioridad alta"
        case .medium: return "Prioridad media"
        case .low:    return "Prioridad baja"
        }
    }
}

/// Estado de una acción pendiente.
enum TaskState: String, Codable, CaseIterable, Identifiable {
    case pending, inProgress, done

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:    return "Pendiente"
        case .inProgress: return "En curso"
        case .done:       return "Hecha"
        }
    }
}

/// Estado global del expediente.
enum CaseStatus: String, Codable, CaseIterable, Identifiable {
    case draft           // Recién creado, sin datos ingresados
    case inProgress      // Datos en proceso de recopilación
    case fichaGenerated  // Ficha técnica generada
    case reportReady     // Reporte formal listo para presentar
    case completed       // Caso cerrado por la familia

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft:          return "Borrador"
        case .inProgress:     return "En proceso"
        case .fichaGenerated: return "Ficha generada"
        case .reportReady:    return "Reporte listo"
        case .completed:      return "Completado"
        }
    }

    var rank: Int {
        switch self {
        case .draft:          return 0
        case .inProgress:     return 1
        case .fichaGenerated: return 2
        case .reportReady:    return 3
        case .completed:      return 4
        }
    }
}

/// Estado de una pregunta crítica.
enum QuestionState: String, Codable, CaseIterable, Identifiable {
    case pending
    case resolved
    case notApplicable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:       return "Pendiente"
        case .resolved:      return "Resuelta"
        case .notApplicable: return "No aplica"
        }
    }
}

/// Tipo de reporte generado.
enum ReportKind: String, Codable, CaseIterable, Identifiable {
    case authority   // Para presentar ante autoridad
    case collective  // Para colectivos de búsqueda y acompañamiento

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .authority:  return "Para autoridad"
        case .collective: return "Para colectivo"
        }
    }
}

/// Qué representa una ubicación dentro del mapa privado.
enum LocationKind: String, Codable, CaseIterable, Identifiable {
    case lastKnown   // Última ubicación conocida
    case frequent    // Lugar frecuente
    case mentioned   // Punto mencionado en testimonios o mensajes
    case discardedPlace // Ubicación revisada y descartada

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lastKnown:      return "Última ubicación conocida"
        case .frequent:       return "Lugar frecuente"
        case .mentioned:      return "Punto mencionado"
        case .discardedPlace: return "Descartada"
        }
    }

    var symbolName: String {
        switch self {
        case .lastKnown:      return "mappin.circle.fill"
        case .frequent:       return "house"
        case .mentioned:      return "bubble.left"
        case .discardedPlace: return "xmark.circle"
        }
    }
}

/// Precisión de una ubicación. La ficha pública solo usa zonas generales.
enum LocationPrecision: String, Codable, CaseIterable, Identifiable {
    case exact        // Dirección o punto preciso (privado por defecto)
    case approximate  // Cuadra o área cercana
    case zone         // Zona general (lo único que se comparte por defecto)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exact:       return "Punto preciso"
        case .approximate: return "Aproximada"
        case .zone:        return "Zona general"
        }
    }
}

/// Tono del texto corto de difusión.
enum PosterTone: String, Codable, CaseIterable, Identifiable {
    case formal
    case community
    case urgent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .formal:    return "Formal"
        case .community: return "Comunitario"
        case .urgent:    return "Urgente"
        }
    }
}
