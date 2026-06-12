//
//  CrisisModeView.swift
//  Faro
//
//  Corazón de la app: una pregunta por pantalla, tipografía grande,
//  sin culpa por saltar, y el expediente se crea con lo que haya.
//

import SwiftUI
import SwiftData
import PhotosUI

struct CrisisModeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = CrisisFlowViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var goingForward = true

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
            removal:   .move(edge: goingForward ? .leading  : .trailing).combined(with: .opacity)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.currentStep {
                case .name:           nameStep
                case .age:            ageStep
                case .photo:          photoStep
                case .lastSeenWhen:   lastSeenWhenStep
                case .lastSeenWhere:  lastSeenWhereStep
                case .clothing:       clothingStep
                case .phone:          phoneStep
                case .lastMessage:    lastMessageStep
                case .medical:        medicalStep
                case .frequentPlaces: frequentPlacesStep
                case .companions:     companionsStep
                case .trustedContact: trustedContactStep
                }
            }
            .id(viewModel.stepNumber)
            .transition(stepTransition)
            .background(FaroTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.currentStep != .name {
                        Button("Atrás") {
                            goingForward = false
                            withAnimation(FaroTheme.springSmooth) { viewModel.goBack() }
                        }
                    } else {
                        Button("Cancelar") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Terminar ahora") { finish() }
                        .accessibilityHint("Crea el expediente con lo que llevas. Puedes completar el resto después.")
                }
            }
        }
    }

    // MARK: - Pasos

    private var nameStep: some View {
        step(onDontKnow: nil) {
            TextField("Nombre", text: $viewModel.name)
                .crisisFieldStyle()
                .textContentType(.name)
                .submitLabel(.next)
                .onSubmit { next() }
            continueButton
        }
    }

    private var ageStep: some View {
        step {
            TextField("Edad aproximada", text: $viewModel.ageText)
                .crisisFieldStyle()
                .keyboardType(.numberPad)
            continueButton
        }
    }

    private var photoStep: some View {
        step {
            VStack(spacing: 14) {
                if let data = viewModel.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
                        .accessibilityLabel("Foto seleccionada de la persona")
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(viewModel.photoData == nil ? "Elegir foto" : "Cambiar foto",
                          systemImage: "photo.on.rectangle")
                }
                .buttonStyle(FaroSecondaryButtonStyle())
                .onChange(of: selectedPhoto) { _, item in
                    Task { @MainActor in
                        if let data = try? await item?.loadTransferable(type: Data.self) {
                            viewModel.photoData = data
                        }
                    }
                }
                if viewModel.photoData != nil { continueButton }
            }
        }
    }

    private var lastSeenWhenStep: some View {
        step {
            DatePicker("Fecha y hora aproximadas",
                       selection: $viewModel.lastSeenDate,
                       in: ...Date.now)
                .datePickerStyle(.graphical)
                .onChange(of: viewModel.lastSeenDate) { viewModel.lastSeenDateAnswered = true }
            Button("Usar esta fecha y hora") {
                viewModel.lastSeenDateAnswered = true
                next()
            }
            .buttonStyle(FaroPrimaryButtonStyle())
        }
    }

    private var lastSeenWhereStep: some View {
        step {
            TextField("Lugar (calle, parada, edificio...)", text: $viewModel.lastSeenPlace, axis: .vertical)
                .crisisFieldStyle()
                .lineLimit(2...4)
            continueButton
        }
    }

    private var clothingStep: some View {
        step {
            TextField("Ropa que llevaba", text: $viewModel.clothing, axis: .vertical)
                .crisisFieldStyle()
                .lineLimit(2...4)
            continueButton
        }
    }

    private var phoneStep: some View {
        step {
            VStack(spacing: 12) {
                Button {
                    viewModel.carriedPhone = true
                    next()
                } label: { Label("Sí, llevaba celular", systemImage: "iphone") }
                .buttonStyle(FaroSecondaryButtonStyle())

                Button {
                    viewModel.carriedPhone = false
                    next()
                } label: { Label("No llevaba celular", systemImage: "iphone.slash") }
                .buttonStyle(FaroSecondaryButtonStyle())
            }
        }
    }

    private var lastMessageStep: some View {
        step {
            TextField("Escribe el último mensaje que conozcas",
                      text: $viewModel.lastMessageText, axis: .vertical)
                .crisisFieldStyle()
                .lineLimit(3...6)
            Text("Si tienes capturas o audios, podrás agregarlos después en Evidencia.")
                .font(.footnote)
                .foregroundStyle(FaroTheme.secondaryText)
            continueButton
        }
    }

    private var medicalStep: some View {
        step {
            TextField("Condición médica, medicamento o tratamiento",
                      text: $viewModel.medical, axis: .vertical)
                .crisisFieldStyle()
                .lineLimit(2...4)
            Text("Esta información se marca como sensible y no se comparte automáticamente.")
                .font(.footnote)
                .foregroundStyle(FaroTheme.amber)
            continueButton
        }
    }

    private var frequentPlacesStep: some View {
        step {
            TextField("Lugares frecuentes, separados por comas",
                      text: $viewModel.frequentPlaces, axis: .vertical)
                .crisisFieldStyle()
                .lineLimit(2...4)
            continueButton
        }
    }

    private var companionsStep: some View {
        step {
            TextField("Personas con las que pudo estar",
                      text: $viewModel.companions, axis: .vertical)
                .crisisFieldStyle()
                .lineLimit(2...4)
            continueButton
        }
    }

    private var trustedContactStep: some View {
        step(onDontKnow: nil) {
            VStack(spacing: 12) {
                TextField("Nombre del contacto", text: $viewModel.contactName)
                    .crisisFieldStyle()
                    .textContentType(.name)
                TextField("Parentesco o relación", text: $viewModel.contactRelationship)
                    .crisisFieldStyle()
                TextField("Teléfono", text: $viewModel.contactPhone)
                    .crisisFieldStyle()
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)

                Button("Crear expediente") { finish() }
                    .buttonStyle(FaroPrimaryButtonStyle())
                Text("Puedes completar todo lo demás después, con calma.")
                    .font(.footnote)
                    .foregroundStyle(FaroTheme.secondaryText)
            }
        }
    }

    // MARK: - Helpers

    /// Paso estándar con salidas sin culpa.
    private func step<Content: View>(
        onDontKnow: (() -> Void)? = { },
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let dontKnowAction: (() -> Void)? = onDontKnow == nil
            ? nil
            : {
                goingForward = true
                withAnimation(FaroTheme.springSmooth) { viewModel.markUnknown() }
            }

        return CrisisQuestionView(
            step: viewModel.stepNumber,
            totalSteps: viewModel.totalSteps,
            question: viewModel.currentStep.question,
            hint: viewModel.currentStep.hint,
            onSkip: { next() },
            onDontKnow: dontKnowAction
        ) {
            content()
        }
    }

    private var continueButton: some View {
        Button("Continuar") { next() }
            .buttonStyle(FaroPrimaryButtonStyle())
            .padding(.top, 8)
    }

    private func next() {
        goingForward = true
        if viewModel.isLastStep {
            finish()
        } else {
            withAnimation(FaroTheme.springSmooth) { viewModel.advance() }
        }
    }

    private func finish() {
        let caseFile = viewModel.buildCase(in: modelContext)
        router.activeCase = caseFile
        router.showingCrisisFlow = false
    }
}

// MARK: - Estilo de campo grande para crisis

private struct CrisisFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title3)
            .padding(16)
            .background(FaroTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous)
                    .strokeBorder(FaroTheme.night.opacity(0.15), lineWidth: 1)
            )
    }
}

private extension View {
    func crisisFieldStyle() -> some View { modifier(CrisisFieldModifier()) }
}
