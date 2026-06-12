//
//  CasesListView.swift
//  Faro
//
//  Historial de casos guardados. Nada se sobrescribe ni se pierde:
//  cada ficha vive como CaseFile independiente. Desde aquí se puede
//  continuar, duplicar, buscar o eliminar (con confirmación).
//

import SwiftUI
import SwiftData

struct CasesListView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CaseFile.updatedAt, order: .reverse) private var cases: [CaseFile]

    @State private var searchText = ""
    @State private var caseToDelete: CaseFile?
    @State private var saveError = false

    private let scoring = AppServices.shared.scoring

    private var filteredCases: [CaseFile] {
        guard !searchText.isEmpty else { return cases }
        let query = searchText.lowercased()
        return cases.filter { caseFile in
            caseFile.title.lowercased().contains(query)
                || (caseFile.person?.name.lowercased().contains(query) ?? false)
                || caseFile.createdAt.formatted(date: .abbreviated, time: .omitted).lowercased().contains(query)
        }
    }

    var body: some View {
        Group {
            if cases.isEmpty {
                EmptyStateView(
                    symbolName: "folder",
                    title: "Aún no tienes fichas guardadas",
                    message: "Puedes crear una nueva o abrir el caso demo.",
                    actionTitle: "Crear caso",
                    action: {
                        router.intakeMode = .conversational
                        router.showingCrisisFlow = true
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FaroTheme.background)
            } else {
                List {
                    ForEach(filteredCases) { caseFile in
                        Button {
                            router.activeCase = caseFile
                        } label: {
                            CaseHistoryRow(caseFile: caseFile,
                                           completeness: scoring.evaluate(caseFile).completenessPercent)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Eliminar", systemImage: "trash", role: .destructive) {
                                caseToDelete = caseFile
                            }
                            Button("Duplicar", systemImage: "doc.on.doc") {
                                duplicate(caseFile)
                            }
                            .tint(FaroTheme.night)
                        }
                        .listRowBackground(FaroTheme.background)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .background(FaroTheme.background)
                .searchable(text: $searchText, prompt: "Buscar por nombre o fecha")
            }
        }
        .navigationTitle("Casos guardados")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Eliminar este caso?",
                            isPresented: Binding(
                                get: { caseToDelete != nil },
                                set: { if !$0 { caseToDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Eliminar definitivamente", role: .destructive) {
                if let caseFile = caseToDelete { delete(caseFile) }
            }
            Button("Cancelar", role: .cancel) { caseToDelete = nil }
        } message: {
            Text("Se borra todo el expediente de este dispositivo: conversación, evidencia, fichas y reportes. Esta acción no se puede deshacer.")
        }
        .alert("No se pudo guardar", isPresented: $saveError) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text("No pudimos guardar este cambio. Intenta de nuevo antes de cerrar.")
        }
    }

    // MARK: - Acciones

    private func delete(_ caseFile: CaseFile) {
        modelContext.delete(caseFile)
        do { try modelContext.save() } catch { saveError = true }
        caseToDelete = nil
    }

    /// Duplica los datos base del caso (sin documentos generados):
    /// útil para reorganizar sin tocar el expediente original.
    private func duplicate(_ caseFile: CaseFile) {
        let copy = CaseFile(title: caseFile.title + " (copia)")
        copy.status = .draft
        copy.notes = caseFile.notes

        if let person = caseFile.person {
            let personCopy = MissingPerson(name: person.name)
            personCopy.approximateAge = person.approximateAge
            personCopy.physicalDescription = person.physicalDescription
            personCopy.clothingDescription = person.clothingDescription
            personCopy.photoData = person.photoData
            personCopy.lastSeenAt = person.lastSeenAt
            personCopy.lastSeenPlace = person.lastSeenPlace
            personCopy.carriedPhone = person.carriedPhone
            personCopy.medicalConditions = person.medicalConditions
            personCopy.frequentPlaces = person.frequentPlaces
            personCopy.possibleCompanions = person.possibleCompanions
            copy.person = personCopy
        }

        for state in caseFile.questionStates {
            let stateCopy = IntakeQuestionRecord(questionKey: state.questionKey)
            stateCopy.statusRaw = state.statusRaw
            stateCopy.rawAnswer = state.rawAnswer
            stateCopy.formalValue = state.formalValue
            stateCopy.confidenceRaw = state.confidenceRaw
            stateCopy.validationRaw = state.validationRaw
            copy.questionStates.append(stateCopy)
        }

        for contact in caseFile.contacts {
            copy.contacts.append(TrustedContact(name: contact.name,
                                                relationship: contact.relationship,
                                                phone: contact.phone,
                                                role: contact.role))
        }

        modelContext.insert(copy)
        do { try modelContext.save() } catch { saveError = true }
    }
}

// MARK: - Fila del historial

struct CaseHistoryRow: View {
    let caseFile: CaseFile
    let completeness: Int

    var body: some View {
        HStack(spacing: 14) {
            photoView

            VStack(alignment: .leading, spacing: 4) {
                Text(caseFile.person?.displayName ?? caseFile.title)
                    .font(.headline)

                Text("Creado: \(caseFile.createdAt.formatted(date: .abbreviated, time: .omitted)) · Actualizado: \(caseFile.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)

                HStack(spacing: 8) {
                    statusBadge
                    if completeness > 0 {
                        Text("\(completeness)% reunido")
                            .font(.caption2)
                            .foregroundStyle(FaroTheme.secondaryText)
                    }
                    if caseFile.isDemo {
                        Text("Demo")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(FaroTheme.amber.opacity(0.15))
                            .foregroundStyle(FaroTheme.amber)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FaroTheme.secondaryText.opacity(0.6))
                .accessibilityHidden(true)
        }
        .faroCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caseFile.person?.displayName ?? caseFile.title). Estado: \(caseFile.status.displayName). \(completeness) por ciento de información reunida.")
        .accessibilityHint("Toca para abrir este caso")
    }

    @ViewBuilder
    private var photoView: some View {
        if let data = caseFile.person?.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
        } else {
            Image(systemName: "person.crop.circle.dashed")
                .font(.title2)
                .foregroundStyle(FaroTheme.secondaryText)
                .frame(width: 52, height: 52)
                .background(FaroTheme.secondaryText.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
        }
    }

    private var statusBadge: some View {
        let color: Color = {
            switch caseFile.status {
            case .draft:          return FaroTheme.secondaryText
            case .inProgress:     return FaroTheme.amber
            case .fichaGenerated: return FaroTheme.night
            case .reportReady:    return FaroTheme.confirmedGreen
            }
        }()
        return Text(caseFile.status.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
