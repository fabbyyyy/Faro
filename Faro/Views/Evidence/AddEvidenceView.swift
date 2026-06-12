//
//  AddEvidenceView.swift
//  Faro
//
//  Alta de evidencia. Tras capturar, el dato NO entra directo al
//  expediente: pasa por la pantalla de validación humana con la
//  clasificación sugerida por IA claramente marcada.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddEvidenceView: View {
    var caseFile: CaseFile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let services = AppServices.shared

    enum Mode: String, CaseIterable, Identifiable {
        case screenshot, note, audio, location
        var id: String { rawValue }

        var title: String {
            switch self {
            case .screenshot: return "Captura de pantalla"
            case .note:       return "Nota escrita"
            case .audio:      return "Nota de voz"
            case .location:   return "Ubicación"
            }
        }

        var subtitle: String {
            switch self {
            case .screenshot: return "FARO leerá el texto de la imagen para sugerir eventos"
            case .note:       return "Escribe un testimonio, recuerdo o dato suelto"
            case .audio:      return "Transcribe una nota de voz para revisarla"
            case .location:   return "Registra un lugar relevante en el mapa privado"
            }
        }

        var symbolName: String {
            switch self {
            case .screenshot: return "photo.on.rectangle.angled"
            case .note:       return "square.and.pencil"
            case .audio:      return "waveform"
            case .location:   return "mappin.and.ellipse"
            }
        }
    }

    @State private var mode: Mode?

    // Captura
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isProcessing = false
    @State private var processingError: String?

    // Nota
    @State private var noteTitle = ""
    @State private var noteText = ""
    @State private var noteSource = ""

    // Ubicación
    @State private var locationName = ""
    @State private var locationZone = ""
    @State private var locationDetails = ""

    // Resultado pendiente de validación
    @State private var pendingEvidence: EvidenceItem?

    var body: some View {
        NavigationStack {
            Group {
                if let mode {
                    modeContent(mode)
                } else {
                    modePicker
                }
            }
            .background(FaroTheme.background)
            .navigationTitle("Agregar evidencia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                if mode != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Atrás") { mode = nil }
                    }
                }
            }
            .sheet(item: $pendingEvidence) { evidence in
                ValidationReviewView(evidence: evidence, caseFile: caseFile) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Selección de tipo

    private var modePicker: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("¿Qué quieres guardar?")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                ForEach(Mode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        CaseDashboardCard(
                            symbolName: option.symbolName,
                            title: option.title,
                            subtitle: option.subtitle
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("Todo lo que agregues pasa por tu revisión antes de integrarse al expediente.")
                    .font(.footnote)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .padding(.top, 8)
            }
            .padding(FaroTheme.screenPadding)
        }
    }

    @ViewBuilder
    private func modeContent(_ mode: Mode) -> some View {
        switch mode {
        case .screenshot: screenshotFlow
        case .note:       noteFlow
        case .audio:      audioFlow
        case .location:   locationFlow
        }
    }

    // MARK: - Captura con OCR

    private var screenshotFlow: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
                        .accessibilityLabel("Captura seleccionada")
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(photoData == nil ? "Elegir captura" : "Cambiar captura",
                          systemImage: "photo.on.rectangle")
                }
                .buttonStyle(FaroSecondaryButtonStyle())
                .onChange(of: selectedPhoto) { _, item in
                    Task {
                        photoData = try? await item?.loadTransferable(type: Data.self)
                    }
                }

                if caseFile.isDemo {
                    Button {
                        Task { await processScreenshot(useDemoOCR: true) }
                    } label: {
                        Label("Usar captura simulada (demo)", systemImage: "sparkles.rectangle.stack")
                    }
                    .buttonStyle(FaroSecondaryButtonStyle())
                    .accessibilityHint("Procesa una captura de ejemplo sin usar tus fotos")
                }

                if photoData != nil {
                    Button {
                        Task { await processScreenshot(useDemoOCR: false) }
                    } label: {
                        if isProcessing {
                            ProgressView().tint(.white)
                        } else {
                            Label("Leer texto de la captura", systemImage: "text.viewfinder")
                        }
                    }
                    .buttonStyle(FaroPrimaryButtonStyle())
                    .disabled(isProcessing)
                }

                if isProcessing {
                    Text("Leyendo la imagen en tu dispositivo…")
                        .font(.footnote)
                        .foregroundStyle(FaroTheme.secondaryText)
                }

                if let processingError {
                    errorCard(processingError)
                }

                Text("El texto extraído será una sugerencia. Tú decides qué entra al expediente.")
                    .font(.footnote)
                    .foregroundStyle(FaroTheme.secondaryText)
            }
            .padding(FaroTheme.screenPadding)
        }
    }

    private func processScreenshot(useDemoOCR: Bool) async {
        isProcessing = true
        processingError = nil
        defer { isProcessing = false }

        do {
            let service = useDemoOCR ? services.demoOCR : services.ocr
            let result = try await service.extractText(from: photoData ?? Data([0x0]))

            let evidence = EvidenceItem(
                kind: .communication,
                title: useDemoOCR ? "Captura simulada (demo)" : "Captura de pantalla",
                details: "Texto extraído con Vision OCR, pendiente de tu revisión.",
                source: useDemoOCR ? "Captura simulada" : "Captura de pantalla"
            )
            evidence.extractedText = result.fullText
            evidence.fileData = useDemoOCR ? nil : photoData
            evidence.validationState = .pending
            evidence.classificationSuggestedByAI = true

            // Clasificación sugerida por IA (solo sugerencia).
            let classification = await services.ai.classifyEvidence(text: result.fullText)
            evidence.kind = classification.kind
            evidence.sensitivity = classification.sensitivity

            caseFile.evidence.append(evidence)
            caseFile.touch()
            try? modelContext.save()
            pendingEvidence = evidence
        } catch {
            processingError = error.localizedDescription
        }
    }

    // MARK: - Nota escrita

    private var noteFlow: some View {
        Form {
            Section("Nota") {
                TextField("Título breve", text: $noteTitle)
                TextField("Qué sabes, qué te dijeron, qué recuerdas…",
                          text: $noteText, axis: .vertical)
                    .lineLimit(4...10)
                TextField("Quién lo dijo o de dónde viene (opcional)", text: $noteSource)
            }
            Section {
                Button("Guardar y revisar") {
                    Task { await saveNote() }
                }
                .disabled(noteText.isEmpty)
            } footer: {
                Text("FARO sugerirá un tipo y nivel de sensibilidad. Tú confirmas o corriges.")
            }
        }
    }

    private func saveNote() async {
        let evidence = EvidenceItem(
            kind: .testimony,
            title: noteTitle.isEmpty ? "Nota escrita" : noteTitle,
            details: noteText,
            source: noteSource.isEmpty ? "Nota manual" : noteSource
        )
        evidence.extractedText = noteText
        evidence.validationState = .pending
        evidence.classificationSuggestedByAI = true

        let classification = await services.ai.classifyEvidence(text: noteText)
        evidence.kind = classification.kind
        evidence.sensitivity = classification.sensitivity

        caseFile.evidence.append(evidence)
        caseFile.touch()
        try? modelContext.save()
        pendingEvidence = evidence
    }

    // MARK: - Nota de voz (transcripción)

    private var audioFlow: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "waveform")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(FaroTheme.night)
                    .accessibilityHidden(true)

                Text("Transcribir nota de voz")
                    .font(.headline)

                Text(services.speech.isAvailable
                     ? "La transcripción se hace en tu dispositivo y luego la revisas tú."
                     : "El reconocimiento de voz no está disponible en este entorno. Puedes usar la transcripción simulada o escribir la nota manualmente.")
                    .font(.subheadline)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await processAudio() }
                } label: {
                    if isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Label("Transcribir audio de ejemplo", systemImage: "waveform.badge.mic")
                    }
                }
                .buttonStyle(FaroPrimaryButtonStyle())
                .disabled(isProcessing)

                Button {
                    mode = .note
                } label: {
                    Label("Mejor escribirla manualmente", systemImage: "square.and.pencil")
                }
                .buttonStyle(FaroSecondaryButtonStyle())

                if isProcessing {
                    Text("Transcribiendo en tu dispositivo…")
                        .font(.footnote)
                        .foregroundStyle(FaroTheme.secondaryText)
                }
            }
            .padding(FaroTheme.screenPadding)
        }
    }

    private func processAudio() async {
        isProcessing = true
        defer { isProcessing = false }

        // En el MVP la transcripción usa el servicio simulado (claramente
        // etiquetado); la integración real de Speech queda lista vía protocolo.
        guard let result = try? await services.demoSpeech.transcribeAudio(
            at: FileManager.default.temporaryDirectory
        ) else { return }

        let evidence = EvidenceItem(
            kind: .communication,
            title: "Nota de voz transcrita",
            details: result.isSimulated
                ? "Transcripción simulada para demostración, pendiente de tu revisión."
                : "Transcripción de audio, pendiente de tu revisión.",
            source: result.isSimulated ? "Nota de voz (transcripción simulada)" : "Nota de voz"
        )
        evidence.extractedText = result.text
        evidence.validationState = .pending
        evidence.classificationSuggestedByAI = true

        let classification = await services.ai.classifyEvidence(text: result.text)
        evidence.kind = classification.kind
        evidence.sensitivity = classification.sensitivity

        caseFile.evidence.append(evidence)
        caseFile.touch()
        try? modelContext.save()
        pendingEvidence = evidence
    }

    // MARK: - Ubicación

    private var locationFlow: some View {
        Form {
            Section("Lugar") {
                TextField("Nombre del lugar", text: $locationName)
                TextField("Zona general (lo que podría compartirse)", text: $locationZone)
                TextField("Detalles (opcional)", text: $locationDetails, axis: .vertical)
            }
            Section {
                Button("Guardar ubicación") {
                    saveLocation()
                }
                .disabled(locationName.isEmpty)
            } footer: {
                Text("La ubicación se guarda en el mapa privado como pendiente de validar. En la ficha pública solo se usa la zona general.")
            }
        }
    }

    private func saveLocation() {
        // Sin Core Location en el alta manual: el punto se coloca cerca
        // de la última ubicación conocida para mantener el mapa útil.
        let base = caseFile.locations.first { $0.kind == .lastKnown }
        let lat = (base?.latitude ?? 19.3321) + Double.random(in: -0.004...0.004)
        let lon = (base?.longitude ?? -99.1862) + Double.random(in: -0.004...0.004)

        let record = LocationRecord(
            name: locationName,
            latitude: lat,
            longitude: lon,
            kind: .mentioned,
            precision: .approximate,
            source: "Registro manual"
        )
        record.generalZoneName = locationZone
        record.details = locationDetails
        record.validationState = .pending
        caseFile.locations.append(record)

        let evidence = EvidenceItem(
            kind: .locationInfo,
            title: "Ubicación: \(locationName)",
            details: locationDetails,
            source: "Registro manual"
        )
        evidence.sensitivity = .privateInfo
        evidence.validationState = .pending
        caseFile.evidence.append(evidence)

        caseFile.touch()
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Error

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(FaroTheme.amber)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FaroTheme.amber.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
    }
}
