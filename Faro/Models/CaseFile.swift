//
//  CaseFile.swift
//  Faro
//
//  Entidad raíz del expediente. Todo lo demás cuelga de aquí
//  con borrado en cascada: si la familia elimina el caso,
//  no queda información huérfana en el dispositivo.
//

import Foundation
import SwiftData

@Model
final class CaseFile {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var statusRaw: String = CaseStatus.draft.rawValue

    /// Contador que sube cada vez que cambia un dato del caso.
    /// Las fichas guardan su valor al generarse para detectar si quedaron desactualizadas.
    var dataRevision: Int = 0

    /// Marca el caso precargado de demostración (datos ficticios).
    var isDemo: Bool = false

    /// Notas generales del expediente.
    var notes: String = ""

    // MARK: Relaciones (borrado en cascada)

    @Relationship(deleteRule: .cascade, inverse: \MissingPerson.caseFile)
    var person: MissingPerson?

    @Relationship(deleteRule: .cascade, inverse: \EvidenceItem.caseFile)
    var evidence: [EvidenceItem] = []

    @Relationship(deleteRule: .cascade, inverse: \TimelineEvent.caseFile)
    var timeline: [TimelineEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \TrustedContact.caseFile)
    var contacts: [TrustedContact] = []

    @Relationship(deleteRule: .cascade, inverse: \CaseTask.caseFile)
    var tasks: [CaseTask] = []

    @Relationship(deleteRule: .cascade, inverse: \CaseQuestion.caseFile)
    var questions: [CaseQuestion] = []

    @Relationship(deleteRule: .cascade, inverse: \LocationRecord.caseFile)
    var locations: [LocationRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \GeneratedReport.caseFile)
    var reports: [GeneratedReport] = []

    @Relationship(deleteRule: .cascade, inverse: \PublicPoster.caseFile)
    var posters: [PublicPoster] = []

    @Relationship(deleteRule: .cascade, inverse: \IntakeQuestionRecord.caseFile)
    var questionStates: [IntakeQuestionRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \CaseFicha.caseFile)
    var fichas: [CaseFicha] = []

    @Relationship(deleteRule: .cascade, inverse: \ChatSession.caseFile)
    var sessions: [ChatSession] = []

    init(title: String, isDemo: Bool = false) {
        self.id = UUID()
        self.title = title
        self.isDemo = isDemo
        self.createdAt = .now
        self.updatedAt = .now
    }

    var status: CaseStatus {
        get { CaseStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    /// Incrementa la revisión del caso y actualiza la marca temporal.
    /// Las fichas generadas anteriormente quedan marcadas como desactualizadas.
    func touch() {
        dataRevision += 1
        updatedAt = .now
    }

    /// Actualiza solo la marca temporal sin cambiar dataRevision.
    /// Usar cuando se genera o actualiza un documento sin que los datos del caso cambien.
    func touchDocumentsOnly() {
        updatedAt = .now
    }

    /// Avanza el estado del caso sin retroceder.
    func promoteStatus(to newStatus: CaseStatus) {
        guard newStatus.rank > status.rank else { return }
        status = newStatus
    }

    // MARK: Conveniencias de lectura

    var sortedTimeline: [TimelineEvent] {
        timeline.sorted { $0.date < $1.date }
    }

    var pendingReviewCount: Int {
        evidence.filter { $0.validationState == .pending }.count
            + timeline.filter { $0.validationState == .pending }.count
    }

    var pendingQuestions: [CaseQuestion] {
        questions.filter { $0.state == .pending }
    }
}
