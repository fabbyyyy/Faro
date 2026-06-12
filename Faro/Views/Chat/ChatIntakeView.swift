//
//  ChatIntakeView.swift
//  Faro
//
//  Conversación de intake. En iPhone: chat a pantalla completa con la
//  ficha en construcción accesible desde la barra. En iPad: chat a la
//  izquierda y ficha formándose en tiempo real a la derecha.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ChatIntakeView: View {
    /// Caso existente a retomar, o nil para crear uno nuevo (borrador).
    var existingCase: CaseFile?
    /// Verdadero cuando se muestra dentro del expediente (sin botón Cerrar propio).
    var embedded: Bool = false

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ChatIntakeViewModel?
    @State private var inputText = ""
    @State private var showingPendingPanel = false
    @State private var showingDraftFicha = false
    @State private var showingReview = false
    @State private var selectedPersonPhoto: PhotosPickerItem?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(FaroTheme.background)
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = ChatIntakeViewModel(caseFile: existingCase, context: modelContext)
                viewModel = vm
                vm.start()
                runSelfTestIfRequested(vm)
            } else {
                viewModel?.start()
            }
        }
    }

    /// Modo de prueba: "-FaroIntakeSelfTest" recorre los escenarios clave
    /// (multi-dato en una frase, "no sé", estrés, confirmación) de forma
    /// programática para validar el flujo sin escribir a mano.
    private func runSelfTestIfRequested(_ vm: ChatIntakeViewModel) {
        guard ProcessInfo.processInfo.arguments.contains("-FaroIntakeSelfTest"),
              existingCase == nil else { return }
        Task { @MainActor in
            @Sendable func wait(_ seconds: Double) async {
                try? await Task.sleep(for: .seconds(seconds))
            }
            @MainActor func confirmIfPending() async {
                for _ in 0..<10 where vm.awaitingConfirmation == nil { await wait(0.3) }
                if vm.awaitingConfirmation != nil {
                    vm.confirmPendingFields(as: .approximate)
                }
            }

            await wait(1.0)
            // Escenario: varios datos en una sola frase coloquial.
            vm.send("Se llama Carmen Díaz, tiene 19, salió de la prepa como a las 7 y llevaba chamarra azul")
            await wait(1.5); await confirmIfPending(); await wait(1.2)
            // Escenario: respuestas de desconocimiento, sin bloquear.
            vm.send("la neta no sé")
            await wait(1.5)
            // Escenario: estrés → contención breve y redirección.
            vm.send("estoy desesperada, no sé qué hacer")
            await wait(1.5)
            // Escenario: respuesta normal con duda parcial.
            vm.send("mide como 1.55, delgada, creo que usa lentes")
            await wait(1.5); await confirmIfPending()
        }
    }

    @ViewBuilder
    private func content(_ viewModel: ChatIntakeViewModel) -> some View {
        let chat = chatColumn(viewModel)

        Group {
            if sizeClass == .regular && !embedded {
                // iPad: conversación + ficha en construcción en vivo.
                HStack(spacing: 0) {
                    chat.frame(minWidth: 380)
                    Divider()
                    DraftFichaLiveColumn(caseFile: viewModel.caseFile)
                        .frame(minWidth: 320, idealWidth: 420)
                }
            } else {
                chat
            }
        }
        .background(FaroTheme.background)
        .navigationTitle("Asistente del caso")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent(viewModel) }
        .sheet(isPresented: $showingPendingPanel) {
            PendingIntakePanel(viewModel: viewModel) {
                showingPendingPanel = false
            }
        }
        .sheet(isPresented: $showingDraftFicha) {
            NavigationStack {
                DraftFichaView(caseFile: viewModel.caseFile)
            }
        }
        .sheet(isPresented: $showingReview) {
            ReviewBeforeGenerateView(caseFile: viewModel.caseFile) {
                viewModel.generateFinalFicha()
                showingReview = false
            }
        }
        .alert("No se pudo guardar",
               isPresented: Binding(
                get: { viewModel.saveErrorMessage != nil },
                set: { if !$0 { viewModel.saveErrorMessage = nil } })
        ) {
            Button("Reintentar") { viewModel.persist() }
            Button("Entendido", role: .cancel) { }
        } message: {
            Text(viewModel.saveErrorMessage ?? "")
        }
        .onChange(of: viewModel.inputPrefill) { _, prefill in
            if let prefill {
                inputText = prefill
                viewModel.inputPrefill = nil
            }
        }
    }

    // MARK: - Columna de chat

    private func chatColumn(_ viewModel: ChatIntakeViewModel) -> some View {
        VStack(spacing: 0) {
            progressBar(viewModel)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            messageView(message, viewModel: viewModel)
                                .id(message.id)
                        }
                        if viewModel.isProcessing {
                            HStack { ChatTypingIndicator(); Spacer() }
                        }
                    }
                    .padding(FaroTheme.screenPadding)
                }
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let last = viewModel.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            quickRepliesBar(viewModel)
            inputBar(viewModel)
        }
    }

    @ViewBuilder
    private func messageView(_ message: ChatMessage, viewModel: ChatIntakeViewModel) -> some View {
        if message.kind == .fieldConfirmation && !message.pendingFields.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ChatBubbleView(message: message)
                FieldConfirmationCard(
                    fields: message.pendingFields,
                    onConfirm: { viewModel.confirmPendingFields(as: .confirmed) },
                    onApproximate: { viewModel.confirmPendingFields(as: .approximate) },
                    onEdit: { viewModel.editPendingFields() },
                    onDiscard: { viewModel.discardPendingFields() }
                )
            }
        } else {
            ChatBubbleView(message: message)
        }
    }

    // MARK: - Progreso suave

    private func progressBar(_ viewModel: ChatIntakeViewModel) -> some View {
        let total = IntakeQuestionBank.all.count
        let done = viewModel.answeredCount
        return VStack(spacing: 4) {
            ProgressView(value: Double(done), total: Double(total))
                .tint(FaroTheme.amber)
            HStack(spacing: 8) {
                Text("\(done) de \(total) datos")
                    .font(.caption2)
                    .foregroundStyle(FaroTheme.secondaryText)
                if viewModel.openQuestions.count > 0 && viewModel.answeredCount > 0 {
                    Text("· \(viewModel.openQuestions.count) pendientes")
                        .font(.caption2)
                        .foregroundStyle(FaroTheme.amber)
                }
                Spacer()
                saveStatusView(viewModel)
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.saveStatus)
        }
        .padding(.horizontal, FaroTheme.screenPadding)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progreso: \(done) de \(total) datos reunidos. Puedes saltar cualquier pregunta.")
    }

    /// Indicador discreto de autosave: confirma que nada se pierde.
    @ViewBuilder
    private func saveStatusView(_ viewModel: ChatIntakeViewModel) -> some View {
        switch viewModel.saveStatus {
        case .saving:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Guardando…")
            }
            .font(.caption2)
            .foregroundStyle(FaroTheme.secondaryText)
            .accessibilityLabel("Guardando")
        case .saved:
            Label("Guardado", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .labelStyle(.titleAndIcon)
                .foregroundStyle(FaroTheme.confirmedGreen)
                .accessibilityLabel("Cambios guardados")
        case .failed:
            Label("Sin guardar", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .labelStyle(.titleAndIcon)
                .foregroundStyle(FaroTheme.amber)
                .accessibilityLabel("No se pudo guardar")
        case .idle:
            EmptyView()
        }
    }

    // MARK: - Respuestas rápidas

    @ViewBuilder
    private func quickRepliesBar(_ viewModel: ChatIntakeViewModel) -> some View {
        if viewModel.awaitingConfirmation == nil && !viewModel.isProcessing {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if viewModel.activeQuestion != nil {
                        QuickReplyChip(title: "No lo sé", action: { viewModel.send("No lo sé") })
                        QuickReplyChip(title: "Saltar por ahora", action: { viewModel.send("saltar") })
                    }
                    if viewModel.baseFlowFinished {
                        QuickReplyChip(title: "Revisar y generar ficha",
                                       systemImage: "doc.text",
                                       prominent: true,
                                       action: { showingReview = true })
                    }
                    if !viewModel.openQuestions.isEmpty {
                        QuickReplyChip(title: "Ver pendientes (\(viewModel.openQuestions.count))",
                                       systemImage: "tray",
                                       action: { showingPendingPanel = true })
                    }
                }
                .padding(.horizontal, FaroTheme.screenPadding)
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Barra de entrada

    private func inputBar(_ viewModel: ChatIntakeViewModel) -> some View {
        HStack(spacing: 8) {
            // Foto de la persona — acceso rápido desde el chat.
            PhotosPicker(selection: $selectedPersonPhoto, matching: .images) {
                ZStack {
                    if let data = viewModel.caseFile.person?.photoData,
                       let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(FaroTheme.secondaryText.opacity(0.10))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "camera")
                                    .font(.system(size: 14))
                                    .foregroundStyle(FaroTheme.secondaryText)
                            )
                    }
                }
                .frame(width: 44, height: 44) // Objetivo táctil accesible.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.caseFile.person?.photoData != nil ? "Cambiar foto de la persona" : "Agregar foto de la persona")

            TextField("Escribe con tus palabras…", text: $inputText, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(FaroTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous)
                        .strokeBorder(FaroTheme.night.opacity(0.15), lineWidth: 1)
                )
                .onSubmit { submit(viewModel) }
                .accessibilityLabel("Campo de respuesta. Escribe con tus palabras, no necesita ser perfecto.")

            Button {
                submit(viewModel)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.isEmpty ? FaroTheme.secondaryText.opacity(0.4) : FaroTheme.night)
                    .frame(width: 44, height: 44) // Objetivo táctil accesible.
                    .contentShape(Rectangle())
            }
            .disabled(inputText.isEmpty || viewModel.isProcessing)
            .accessibilityLabel("Enviar respuesta")
        }
        .padding(.horizontal, FaroTheme.screenPadding)
        .padding(.vertical, 10)
        .background(FaroTheme.background)
        .onChange(of: selectedPersonPhoto) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        if viewModel.caseFile.person == nil {
                            viewModel.caseFile.person = MissingPerson()
                        }
                        viewModel.caseFile.person?.photoData = data
                        viewModel.persist()
                    }
                }
            }
        }
    }

    private func submit(_ viewModel: ChatIntakeViewModel) {
        let text = inputText
        inputText = ""
        viewModel.send(text)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent(_ viewModel: ChatIntakeViewModel) -> some ToolbarContent {
        if !embedded {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cerrar") {
                    // El progreso ya está autosaveado: cerrar nunca pierde nada.
                    viewModel.persist()
                    router.activeCase = viewModel.caseFile
                    router.showingCrisisFlow = false
                    dismiss()
                }
                .accessibilityHint("Tu progreso queda guardado como borrador")
            }
        }
        if sizeClass != .regular || embedded {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingDraftFicha = true
                } label: {
                    Label("Ficha en construcción", systemImage: "doc.text.magnifyingglass")
                }
                .accessibilityHint("Muestra qué datos ya están listos y cuáles faltan")
            }
        }
    }
}

// MARK: - Columna iPad: ficha en construcción en tiempo real

struct DraftFichaLiveColumn: View {
    let caseFile: CaseFile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ficha en construcción")
                .font(.headline)
                .padding(FaroTheme.screenPadding)
            Divider()
            DraftFichaView(caseFile: caseFile, compact: true)
        }
        .background(FaroTheme.background)
    }
}
