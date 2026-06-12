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

    init(title: String, isDemo: Bool = false) {
        self.id = UUID()
        self.title = title
        self.isDemo = isDemo
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// Registrar actividad: mantiene visible "última actualización" en el dashboard.
    func touch() {
        updatedAt = .now
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
