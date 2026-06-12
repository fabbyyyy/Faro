//
//  FaroApp.swift
//  Faro
//
//  FARO no promete encontrar a una persona. Promete que una familia
//  no pierda las primeras horas tratando de entender qué hacer.
//
//  Local-first: todo el expediente vive en SwiftData, en el dispositivo.
//

import SwiftUI
import SwiftData

@main
struct FaroApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CaseFile.self,
            MissingPerson.self,
            EvidenceItem.self,
            TimelineEvent.self,
            TrustedContact.self,
            CaseTask.self,
            CaseQuestion.self,
            LocationRecord.self,
            GeneratedReport.self,
            PublicPoster.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo crear el contenedor de datos local: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
