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
    @FocusState private var inputFocused: Bool

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
        .navigationTitle("Beacon")
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
        ZStack {
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
                    .padding(.top, embedded ? 0 : 58)
                    .padding(.bottom, 130)
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

            VStack(spacing: 0) {
                // En el intake inicial (pantalla completa, sin barra de
                // navegación) Beacon y el progreso flotan sobre el chat.
                // Abierto desde el resumen, viven en la barra y aquí no.
                if !embedded {
                    HStack(alignment: .top) {
                        beaconMenu(viewModel, glass: true)
                        Spacer()
                        progressOrb(viewModel, glass: true)
                    }
                    .padding(.horizontal, FaroTheme.screenPadding)
                    .padding(.top, 8)
                }

                Spacer()

                VStack(spacing: 6) {
                    quickRepliesBar(viewModel)
                    inputBar(viewModel)
                }
                .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private func beaconMenu(_ viewModel: ChatIntakeViewModel, glass: Bool = false) -> some View {
        let menu = Menu {
            Button("Ficha en construcción", systemImage: "doc.text.magnifyingglass") {
                showingDraftFicha = true
            }
            Button("Reiniciar caso", systemImage: "arrow.counterclockwise") {
                resetIntake(viewModel)
            }
            Button("Salir al menú principal", systemImage: "house") {
                exitToMainMenu(viewModel)
            }
        } label: {
            if glass {
                Text("Beacon")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FaroTheme.night)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .contentShape(Capsule())
            } else {
                Text("Beacon")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .contentShape(Rectangle())
            }
        }
        .accessibilityLabel("Beacon")
        .accessibilityHint("Abre la ficha en construcción y opciones del caso")

        if glass {
            menu.faroGlassBeaconPill()
        } else {
            menu
        }
    }

    private func resetIntake(_ viewModel: ChatIntakeViewModel) {
        let oldCase = viewModel.caseFile
        modelContext.delete(oldCase)
        do {
            try modelContext.save()
            inputText = ""
            selectedPersonPhoto = nil
            showingPendingPanel = false
            showingDraftFicha = false
            showingReview = false
            let fresh = ChatIntakeViewModel(caseFile: nil, context: modelContext)
            self.viewModel = fresh
            fresh.start()
        } catch {
            viewModel.saveErrorMessage = "No pudimos reiniciar el caso. Intenta de nuevo antes de cerrar."
        }
    }

    private func exitToMainMenu(_ viewModel: ChatIntakeViewModel) {
        viewModel.persist()
        router.activeCase = nil
        router.showingCrisisFlow = false
        dismiss()
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

    @ViewBuilder
    private func progressOrb(_ viewModel: ChatIntakeViewModel, glass: Bool = false) -> some View {
        let total = IntakeQuestionBank.all.count
        let done = viewModel.answeredCount
        let progress = total == 0 ? 0 : Double(done) / Double(total)
        let button = Button {
            showingPendingPanel = true
        } label: {
            ZStack {
                Circle()
                    .stroke(FaroTheme.secondaryText.opacity(0.24), lineWidth: 4)
                    .frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progress >= 1 ? FaroTheme.confirmedGreen : FaroTheme.amber,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.25), value: progress)
                Text("\(done)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(FaroTheme.night)
                    .monospacedDigit()
            }
            .frame(width: glass ? 48 : 40, height: glass ? 48 : 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progreso: \(done) de \(total) datos reunidos")
        .accessibilityHint("Abre la lista de datos pendientes")

        if glass {
            button.faroGlassProgressOrb()
        } else {
            button
        }
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FaroTheme.screenPadding)
            .padding(.vertical, 2)
            .background(Color.clear)
        }
    }

    // MARK: - Barra de entrada

    @ViewBuilder
    private func inputBar(_ viewModel: ChatIntakeViewModel) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 8) {
                inputBarContent(viewModel)
            }
            .inputBarShell(selectedPersonPhoto: $selectedPersonPhoto, viewModel: viewModel)
        } else {
            inputBarContent(viewModel)
                .inputBarShell(selectedPersonPhoto: $selectedPersonPhoto, viewModel: viewModel)
        }
    }

    private func inputBarContent(_ viewModel: ChatIntakeViewModel) -> some View {
        HStack(spacing: 8) {
            PhotosPicker(selection: $selectedPersonPhoto, matching: .images) {
                Image(systemName: "plus")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(FaroTheme.night)
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
                .faroGlassPhotoButton()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Subir imagen")

            HStack(spacing: 6) {
                TextField("Escribe lo que ocupas…", text: $inputText, axis: .vertical)
                    .font(.body)
                    .lineLimit(1...3)
                    .focused($inputFocused)
                    .onSubmit { submit(viewModel) }
                    .accessibilityLabel("Campo de respuesta. Escribe con tus palabras, no necesita ser perfecto.")

                Button {
                    inputFocused = true
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(FaroTheme.secondaryText)
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dictar")

                Button {
                    submit(viewModel)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(inputText.isEmpty ? FaroTheme.secondaryText.opacity(0.55) : Color(light: .white, dark: Color(red: 0.07, green: 0.09, blue: 0.13)))
                        .frame(width: 38, height: 38)
                        .background(inputText.isEmpty ? FaroTheme.secondaryText.opacity(0.16) : FaroTheme.night)
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .disabled(inputText.isEmpty || viewModel.isProcessing)
                .accessibilityLabel("Enviar respuesta")
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .frame(minHeight: 48)
            .faroGlassComposerPill()
        }
        .padding(.horizontal, FaroTheme.screenPadding)
        .padding(.vertical, 10)
        .faroGlassInputBarBackground()
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
        // Abierto desde el resumen del caso: Beacon y el progreso viven
        // en la barra. En el intake inicial flotan sobre el chat.
        if embedded {
            ToolbarItem(placement: .principal) {
                beaconMenu(viewModel)
            }
            ToolbarItem(placement: .topBarTrailing) {
                progressOrb(viewModel)
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

private extension View {
    func inputBarShell(
        selectedPersonPhoto: Binding<PhotosPickerItem?>,
        viewModel: ChatIntakeViewModel
    ) -> some View {
        self
            .onChange(of: selectedPersonPhoto.wrappedValue) { _, item in
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
}
