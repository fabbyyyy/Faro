//
//  TrustNetworkView.swift
//  Faro
//
//  Red de confianza: no toda persona debe ver toda la información.
//  Cada rol tiene permisos claros (MVP local-first; sincronización
//  segura con CloudKit como evolución futura).
//

import SwiftUI
import SwiftData

struct TrustNetworkView: View {
    @Bindable var caseFile: CaseFile
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddContact = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if caseFile.contacts.isEmpty {
                    EmptyStateView(
                        symbolName: "person.2",
                        title: "Aún no hay red de confianza",
                        message: "Agrega a las personas que te apoyan. Cada rol define qué información le corresponde ver.",
                        actionTitle: "Agregar contacto",
                        action: { showingAddContact = true }
                    )
                } else {
                    Text("Cada rol limita qué parte del expediente le corresponde. La información sensible no se comparte con toda la red.")
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(caseFile.contacts) { contact in
                        TrustContactCard(contact: contact)
                            .contextMenu {
                                Button("Eliminar", role: .destructive) {
                                    modelContext.delete(contact)
                                    caseFile.touch()
                                }
                            }
                    }
                }
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Red de confianza")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddContact = true
                } label: {
                    Label("Agregar contacto", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddContact) {
            AddContactView(caseFile: caseFile)
                .presentationDetents([.large])
        }
    }
}

// MARK: - Alta de contacto

struct AddContactView: View {
    var caseFile: CaseFile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var relationship = ""
    @State private var phone = ""
    @State private var role: ContactRole = .documentation

    var body: some View {
        NavigationStack {
            Form {
                Section("Contacto") {
                    TextField("Nombre", text: $name)
                        .textContentType(.name)
                    TextField("Parentesco o relación", text: $relationship)
                    TextField("Teléfono", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                Section {
                    Picker("Rol", selection: $role) {
                        ForEach(ContactRole.allCases) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Rol en el caso")
                } footer: {
                    Text(role.permissionsSummary)
                }
            }
            .navigationTitle("Agregar contacto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let contact = TrustedContact(
                            name: name,
                            relationship: relationship,
                            phone: phone,
                            role: role
                        )
                        caseFile.contacts.append(contact)
                        caseFile.touch()
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
