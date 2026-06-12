//
//  CaseQuestion.swift
//  Faro
//
//  Pregunta crítica pendiente. Se genera a partir de lo que falta
//  en el expediente; la familia decide si está resuelta o no aplica.
//

import Foundation
import SwiftData

@Model
final class CaseQuestion {
    var id: UUID = UUID()
    var text: String = ""

    /// Por qué importa esta pregunta (contexto breve y empático).
    var whyItMatters: String = ""

    var state: QuestionState = QuestionState.pending
    var answer: String = ""
    var createdAt: Date = Date.now

    /// Verdadero si la sugirió la IA o el motor de huecos (vs. manual).
    var suggestedAutomatically: Bool = false

    var caseFile: CaseFile?

    init(text: String, whyItMatters: String = "", suggestedAutomatically: Bool = false) {
        self.id = UUID()
        self.text = text
        self.whyItMatters = whyItMatters
        self.suggestedAutomatically = suggestedAutomatically
    }
}
