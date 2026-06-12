//
//  CaseSettingsView.swift
//  Faro
//
//  Ajustes del caso: datos de la persona, demo y eliminación.
//

import SwiftUI
import SwiftData

struct CaseSettingsView: View {
    @Bindable var caseFile: CaseFile
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @State private var confirmingDelete = false
    @State private var confirmingDemoReset = false

    var body: some View {
        Form {
            Section("Persona") {
                NavigationLink("Editar datos de la persona") {
                    PersonDetailView(caseFile: caseFile)
                }
            }

            Section("Asistente de IA") {
                LabeledContent("Motor activo", value: AppServices.shared.ai.engineName)
                Text("La IA trabaja solo en este dispositivo y todo lo que sugiere pasa por tu validación.")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
            }

            if caseFile.isDemo {
                Section {
                    Button("Reiniciar caso demo") {
                        confirmingDemoReset = true
                    }
                } header: {
                    Text("Demostración")
                } footer: {
                    Text("Restaura el caso demo a su estado original con datos ficticios.")
                }
            }

            Section {
                Button("Eliminar este caso", role: .destructive) {
                    confirmingDelete = true
                }
            } footer: {
                Text("Se borra todo el expediente de este dispositivo. Esta acción no se puede deshacer.")
            }
        }
        .navigationTitle("Ajustes del caso")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Eliminar todo el expediente?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Eliminar definitivamente", role: .destructive) {
                deleteCase()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se eliminarán la persona, evidencia, timeline, contactos, ubicaciones y reportes de este caso.")
        }
        .confirmationDialog("¿Reiniciar el caso demo?",
                            isPresented: $confirmingDemoReset,
                            titleVisibility: .visible) {
            Button("Reiniciar", role: .destructive) {
                resetDemo()
            }
            Button("Cancelar", role: .cancel) { }
        }
    }

    private func deleteCase() {
        router.activeCase = nil
        modelContext.delete(caseFile)
        try? modelContext.save()
    }

    private func resetDemo() {
        router.activeCase = nil
        DemoCaseFactory.resetDemoCase(in: modelContext)
    }
}

// MARK: - Edición de datos de la persona

struct PersonDetailView: View {
    @Bindable var caseFile: CaseFile
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            if let person = caseFile.person {
                PersonFormFields(person: person, caseFile: caseFile)
            } else {
                Button("Registrar persona") {
                    caseFile.person = MissingPerson()
                    caseFile.touch()
                }
            }
        }
        .navigationTitle("Datos de la persona")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            caseFile.touch()
            try? modelContext.save()
        }
    }
}

private struct PersonFormFields: View {
    @Bindable var person: MissingPerson
    var caseFile: CaseFile

    @State private var ageText = ""

    var body: some View {
        Section("Identidad") {
            TextField("Nombre", text: $person.name)
            TextField("Edad aproximada", text: $ageText)
                .keyboardType(.numberPad)
                .onChange(of: ageText) { person.approximateAge = Int(ageText) }
                .onAppear { ageText = person.approximateAge.map(String.init) ?? "" }
        }

        Section("Descripción") {
            TextField("Descripción física", text: $person.physicalDescription, axis: .vertical)
            TextField("Ropa la última vez vista", text: $person.clothingDescription, axis: .vertical)
        }

        Section("Última vez") {
            DatePicker(
                "Fecha y hora",
                selection: Binding(
                    get: { person.lastSeenAt ?? .now },
                    set: { person.lastSeenAt = $0 }
                )
            )
            TextField("Lugar", text: $person.lastSeenPlace, axis: .vertical)
        }

        Section {
            TextField("Condición médica o medicamentos", text: $person.medicalConditions, axis: .vertical)
        } header: {
            Text("Salud")
        } footer: {
            Text("Información sensible: solo se usa en reportes que tú decidas compartir, nunca en la ficha pública.")
        }

        Section("Contexto") {
            TextField("Lugares frecuentes", text: $person.frequentPlaces, axis: .vertical)
            TextField("Personas con las que pudo estar", text: $person.possibleCompanions, axis: .vertical)
            TextField("Notas", text: $person.notes, axis: .vertical)
        }
    }
}
