//
//  TimelineAnalysisService.swift
//  Faro
//
//  Detección determinista de huecos y contradicciones en el timeline.
//  No usa IA: estas alertas deben ser explicables y predecibles.
//

import Foundation

struct TimelineGap: Identifiable {
    var id: UUID = UUID()
    var start: Date
    var end: Date
    var hours: Int
}

struct TimelineConflict: Identifiable {
    var id: UUID = UUID()
    /// IDs de los eventos en conflicto.
    var eventIDs: [UUID]
    var message: String
}

struct TimelineAnalysisService {

    /// Huecos de más de `minimumGapHours` horas entre eventos no descartados.
    func detectGaps(in caseFile: CaseFile, minimumGapHours: Double = 3) -> [TimelineGap] {
        let events = caseFile.sortedTimeline.filter { $0.validationState != .discarded }
        guard events.count >= 2 else { return [] }

        var gaps: [TimelineGap] = []
        for (current, next) in zip(events, events.dropFirst()) {
            let interval = next.date.timeIntervalSince(current.date)
            if interval >= minimumGapHours * 3600 {
                gaps.append(TimelineGap(start: current.date,
                                        end: next.date,
                                        hours: Int(interval / 3600)))
            }
        }
        return gaps
    }

    /// Contradicciones: dos o más marcadores de "última vez vista"
    /// con horarios distintos y ninguno descartado.
    func detectConflicts(in caseFile: CaseFile) -> [TimelineConflict] {
        let markers = caseFile.timeline.filter {
            $0.isLastSeenMarker && $0.validationState != .discarded
        }
        guard markers.count >= 2 else { return [] }

        // Si difieren por más de 15 minutos, se considera contradicción.
        let sorted = markers.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last,
              last.date.timeIntervalSince(first.date) > 15 * 60 else { return [] }

        return [TimelineConflict(
            eventIDs: markers.map(\.id),
            message: "Hay dos horarios distintos para la última vez vista. Revisa cuál está confirmado."
        )]
    }
}
