//
//  CaseTask.swift
//  Faro
//
//  Acción recomendada o pendiente del caso, con prioridad y estado.
//

import Foundation
import SwiftData

@Model
final class CaseTask {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var priority: TaskPriority = TaskPriority.medium
    var state: TaskState = TaskState.pending
    var createdAt: Date = Date.now

    var caseFile: CaseFile?

    init(title: String, details: String = "", priority: TaskPriority = .medium) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.priority = priority
    }
}
