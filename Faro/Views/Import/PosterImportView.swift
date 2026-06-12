//
//  PosterImportView.swift
//  Faro
//
//  Importar datos desde un cartel de búsqueda existente.
//  La cámara emerge desde la zona del Dynamic Island con un brillo
//  tipo aurora y se expande a pantalla completa. UI mínima: visor,
//  obturador blanco y voltear cámara. Nada más.
//
//  Regla innegociable: todo lo extraído del cartel (OCR + reglas)
//  entra al expediente como pendiente de revisión humana.
//

import SwiftUI
import AVFoundation
import PhotosUI
import SwiftData
import Vision

// MARK: - Vista principal

struct PosterImportView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    /// Fases de la apertura: pill del Dynamic Island → rectángulo
    /// vertical con aurora → pantalla completa.
    private enum OpeningPhase: Int, Comparable {
        case island, card, full
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    @State private var camera = PosterCameraController()
    @State private var phase: OpeningPhase = .island
    @State private var auroraBreathing = false
    @State private var viewfinderVisible = false
    @State private var capturedImage: UIImage?
    /// Marcos en coordenadas globales para mapear el encuadre a la foto.
    @State private var guideFrame: CGRect = .zero
    @State private var previewFrame: CGRect = .zero
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var selectedLibraryItem: PhotosPickerItem?

    private let services = AppServices.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // El visor ocupa toda la pantalla desde el principio;
                // el canvas animado se superpone encima hasta que termina
                // la animación y viewfinderVisible se vuelve true.
                if phase == .full {
                    cameraContent
                        .background(Color.black.ignoresSafeArea())
                        .opacity(viewfinderVisible ? 1 : 0)
                }

                // Lienzo animado: pill → rectángulo con aurora → se desvanece.
                if !viewfinderVisible {
                    RoundedRectangle(cornerRadius: canvasCornerRadius, style: .continuous)
                        .fill(.black)
                        .overlay {
                            auroraGlow
                                .padding(.top, auroraTopInset)
                                .padding([.horizontal, .bottom], auroraEdgeInset)
                                .clipShape(RoundedRectangle(cornerRadius: auroraCornerRadius,
                                                            style: .continuous))
                                .opacity(phase == .island ? 0 : 1)
                        }
                        .frame(width: canvasSize(in: geo.size).width,
                               height: canvasSize(in: geo.size).height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, phase == .full ? 0 : 11)
                        .ignoresSafeArea()
                }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden()
        .task {
            Task { await camera.start() }

            // Toda la apertura se programa de una vez, encadenada con
            // delays: la expansión a pantalla completa arranca mientras
            // el rectángulo aún se asienta — un solo movimiento continuo.
            auroraBreathing = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                phase = .card
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.9).delay(0.34)) {
                phase = .full
            }
            withAnimation(.easeInOut(duration: 0.5).delay(0.72)) {
                viewfinderVisible = true
            }
        }
        .onDisappear { camera.stop() }
        .onChange(of: selectedLibraryItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    withAnimation(FaroTheme.springSmooth) { capturedImage = image }
                }
            }
        }
    }

    // MARK: - Geometría de la apertura

    /// Tamaño del lienzo en cada fase. La pill inicial calca el
    /// Dynamic Island; la fase intermedia es más larga que ancha.
    private func canvasSize(in container: CGSize) -> CGSize {
        switch phase {
        case .island: CGSize(width: 126, height: 37)
        case .card:   CGSize(width: min(310, container.width - 80), height: 330)
        case .full:   container
        }
    }

    /// Las esquinas se quedan redondas durante toda la expansión;
    /// al llenar la pantalla, el radio coincide con el del dispositivo.
    private var canvasCornerRadius: CGFloat {
        switch phase {
        case .island: 19
        case .card:   46
        case .full:   58
        }
    }

    /// Bisel negro de la "pantalla": grueso arriba para envolver la
    /// pill del Dynamic Island, delgado en los lados y abajo.
    private var auroraTopInset: CGFloat {
        phase == .card ? 56 : 0
    }

    private var auroraEdgeInset: CGFloat {
        phase == .card ? 7 : 0
    }

    private var auroraCornerRadius: CGFloat {
        phase == .card ? 40 : 0
    }

    /// Pantalla encendiéndose con la paleta de FARO: azul noche al
    /// centro, horizonte ámbar abajo, respirando suavemente.
    private var auroraGlow: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color(red: 0.28, green: 0.42, blue: 0.78),
                                    Color(red: 0.082, green: 0.133, blue: 0.220).opacity(0.7),
                                    .clear],
                           center: .center, startRadius: 0, endRadius: 280)
            RadialGradient(colors: [Color(red: 0.95, green: 0.72, blue: 0.33).opacity(0.85),
                                    .clear],
                           center: .bottom, startRadius: 0, endRadius: 220)
            RadialGradient(colors: [Color(red: 0.80, green: 0.55, blue: 0.13).opacity(0.45),
                                    .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 180)
            RadialGradient(colors: [.white.opacity(0.30), .clear],
                           center: .bottom, startRadius: 0, endRadius: 90)
        }
        .blur(radius: 22)
        .scaleEffect(auroraBreathing ? 1.12 : 0.96)
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                   value: auroraBreathing)
    }

    // MARK: - Contenido de cámara

    @ViewBuilder
    private var cameraContent: some View {
        if let capturedImage {
            reviewView(capturedImage)
        } else {
            ZStack(alignment: .bottom) {
                CameraPreviewView(controller: camera)
                    .ignoresSafeArea()
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                        previewFrame = $0
                    }

                framingGuide
                    .padding(.horizontal, 36)
                    .padding(.top, 132)
                    .padding(.bottom, 150)

                shutterBar
                    .padding(.bottom, 36)
            }
            .overlay(alignment: .top) {
                // Tacha e instrucción emparejadas en la misma fila.
                ZStack {
                    Text("Encuadra el cartel completo")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.35), in: Capsule())

                    HStack {
                        closeButton
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                // El visor ignora el safe area, así que el overlay nace en
                // el borde físico: este padding libra el Dynamic Island.
                .padding(.top, 64)
            }
        }
    }

    /// Esquinas de encuadre: marcan dónde cuadrar el cartel, sin encerrar
    /// el visor. Proporción vertical, como un cartel impreso. La foto se
    /// recorta exactamente a este marco.
    private var framingGuide: some View {
        CornerBracketsShape(cornerLength: 26, cornerRadius: 10)
            .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .shadow(color: .black.opacity(0.35), radius: 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                guideFrame = $0
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Recorta la captura a lo que se veía dentro del marco de encuadre.
    /// El visor usa aspect-fill, así que se deshace ese mapeo a mano.
    private func cropToGuide(_ image: UIImage) -> UIImage {
        guard previewFrame.width > 0, guideFrame.width > 0,
              let normalized = PosterPhotoExtractor.normalizedUp(image),
              let cgImage = normalized.cgImage else { return image }

        let imageSize = normalized.size
        let scale = max(previewFrame.width / imageSize.width,
                        previewFrame.height / imageSize.height)
        let displayed = CGSize(width: imageSize.width * scale,
                               height: imageSize.height * scale)
        let offsetX = (displayed.width - previewFrame.width) / 2
        let offsetY = (displayed.height - previewFrame.height) / 2

        let cropRect = CGRect(
            x: (guideFrame.minX - previewFrame.minX + offsetX) / scale,
            y: (guideFrame.minY - previewFrame.minY + offsetY) / scale,
            width: guideFrame.width / scale,
            height: guideFrame.height / scale
        ).intersection(CGRect(origin: .zero, size: imageSize))

        guard !cropRect.isEmpty, let cropped = cgImage.cropping(to: cropRect) else {
            return image
        }
        return UIImage(cgImage: cropped)
    }

    /// Barra inferior mínima: galería, obturador blanco limpio, voltear.
    private var shutterBar: some View {
        ZStack {
            // Obturador: círculo blanco simple, sin anillos ni adornos.
            Button {
                camera.capture { image in
                    guard let image else { return }
                    let framed = cropToGuide(image)
                    withAnimation(FaroTheme.springSmooth) { capturedImage = framed }
                }
            } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(ShutterButtonStyle())
            .accessibilityLabel("Tomar foto del cartel")

            HStack {
                PhotosPicker(selection: $selectedLibraryItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .accessibilityLabel("Elegir el cartel desde tus fotos")

                Spacer()

                Button {
                    camera.flip()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .accessibilityLabel("Voltear cámara")
            }
            .padding(.horizontal, 48)
        }
    }

    private var closeButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.25)) {
                router.showingCrisisFlow = false
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.black.opacity(0.35), in: Circle())
        }
        .accessibilityLabel("Cerrar cámara")
    }

    // MARK: - Revisión de la captura

    private func reviewView(_ image: UIImage) -> some View {
        ZStack(alignment: .bottom) {
            // Fondo negro: la foto vive en su marco y los botones
            // siempre quedan visibles y legibles.
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 36)
                .padding(.top, 70)
                .padding(.bottom, 190)
                .opacity(isProcessing ? 0.45 : 1)

            VStack(spacing: 12) {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                    Text("Leyendo el cartel en tu dispositivo…")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text("Todo lo detectado quedará pendiente de tu revisión.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.5), in: Capsule())
                    }
                    Button {
                        Task { await importPoster(image) }
                    } label: {
                        Label("Usar este cartel", systemImage: "text.viewfinder")
                    }
                    .buttonStyle(FaroPrimaryButtonStyle())

                    Button {
                        withAnimation(FaroTheme.springSmooth) {
                            capturedImage = nil
                            errorMessage = nil
                        }
                    } label: {
                        Text("Volver a tomar")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(FaroQuietButtonStyle())
                }
            }
            .padding(.horizontal, FaroTheme.screenPadding)
            .padding(.bottom, 36)
        }
        .overlay(alignment: .topLeading) {
            if !isProcessing { closeButton.padding(20) }
        }
    }

    // MARK: - Importación

    /// OCR en el dispositivo + extracción determinista por reglas.
    /// Crea el caso con todo en estado pendiente de revisión.
    private func importPoster(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        withAnimation { isProcessing = true }
        defer { withAnimation { isProcessing = false } }

        do {
            let ocr = try await services.ocr.extractText(from: data)
            let extracted = PosterFieldExtractor.extract(from: ocr.fullText)
            // Si el cartel trae foto de la persona, se recorta y se usa
            // como foto del caso (también queda pendiente de revisión).
            let personPhoto = await PosterPhotoExtractor.extractPersonPhoto(from: image)
            let caseFile = buildCase(from: extracted, ocrText: ocr.fullText,
                                     imageData: data, personPhoto: personPhoto)
            try? modelContext.save()
            router.activeCase = caseFile
            router.showingCrisisFlow = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildCase(from extracted: PosterExtraction,
                           ocrText: String,
                           imageData: Data,
                           personPhoto: Data?) -> CaseFile {
        let title = extracted.name.map { "Caso · \($0)" } ?? "Nuevo caso"
        let caseFile = CaseFile(title: title)
        modelContext.insert(caseFile)

        let person = MissingPerson(name: extracted.name ?? "")
        person.approximateAge = extracted.age
        if let place = extracted.place { person.lastSeenPlace = place }
        if let clothing = extracted.clothing { person.clothingDescription = clothing }
        person.photoData = personPhoto
        caseFile.person = person

        // El cartel completo entra como evidencia pendiente.
        let evidence = EvidenceItem(
            kind: .document,
            title: "Cartel de búsqueda importado",
            details: ocrText,
            source: "Importado desde un cartel con la cámara"
        )
        evidence.fileData = imageData
        evidence.sensitivity = .publicSafe
        evidence.validationState = .pending
        evidence.classificationSuggestedByAI = true
        caseFile.evidence.append(evidence)

        if let phone = extracted.contactPhone {
            let contact = TrustedContact(
                name: "Contacto del cartel",
                relationship: "Tomado del cartel importado",
                phone: phone,
                role: .observer
            )
            caseFile.contacts.append(contact)
        }

        // Lo leído de un cartel nunca se asume correcto: pregunta de revisión.
        let question = CaseQuestion(
            text: "Revisa los datos importados del cartel: nombre, edad, lugar y contacto.",
            whyItMatters: "La lectura automática de un cartel puede tener errores. Confirma cada dato antes de usarlo.",
            suggestedAutomatically: true
        )
        caseFile.questions.append(question)

        return caseFile
    }
}

// MARK: - Esquinas de encuadre

/// Dibuja solo las cuatro esquinas de un rectángulo redondeado.
private struct CornerBracketsShape: Shape {
    let cornerLength: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = cornerRadius
        let l = cornerLength

        // Superior izquierda
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + r + l))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                    radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + r + l, y: rect.minY))

        // Superior derecha
        path.move(to: CGPoint(x: rect.maxX - r - l, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                    radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r + l))

        // Inferior derecha
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - r - l))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                    radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - r - l, y: rect.maxY))

        // Inferior izquierda
        path.move(to: CGPoint(x: rect.minX + r + l, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                    radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r - l))

        return path
    }
}

// MARK: - Estilo del obturador

private struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1.0)
            .animation(FaroTheme.springSnappy, value: configuration.isPressed)
    }
}

// MARK: - Extracción determinista de campos del cartel

struct PosterExtraction {
    var name: String?
    var age: Int?
    var place: String?
    var clothing: String?
    var contactPhone: String?
}

/// Reglas explícitas, sin modelo: lo que se extrae y por qué es auditable.
enum PosterFieldExtractor {

    static func extract(from text: String) -> PosterExtraction {
        var result = PosterExtraction()
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Edad: "22 años"
        if let ageText = SpanishIntakeEngine.firstMatch(in: text, pattern: #"(\d{1,2})\s*años"#),
           let age = Int(ageText) {
            result.age = age
        }

        // Teléfono: 10 dígitos con separadores opcionales.
        if let phone = SpanishIntakeEngine.firstMatch(
            in: text,
            pattern: #"(\d{2,3}[\s\-\.]?\d{3,4}[\s\-\.]?\d{4})"#) {
            result.contactPhone = phone
        }

        // Nombre: línea después de "SE BUSCA"/"BUSCAMOS A"/"DESAPARECIDA",
        // o la primera línea en mayúsculas con 2+ palabras.
        let triggers = ["se busca", "buscamos a", "desaparecid", "ayúdanos a encontrar", "ayudanos a encontrar"]
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            if triggers.contains(where: { lower.contains($0) }), index + 1 < lines.count {
                let candidate = lines[index + 1]
                if isLikelyName(candidate) {
                    result.name = candidate.capitalized
                    break
                }
            }
        }
        if result.name == nil {
            result.name = lines.first(where: { isLikelyName($0) && $0 == $0.uppercased() })?.capitalized
        }

        // Lugar: "vista por última vez en …" / "desapareció en …"
        if let place = SpanishIntakeEngine.firstMatch(
            in: text,
            pattern: #"(?:última vez|ultima vez|desapareci[oó])\s+(?:en|por)\s+([^\n\.]{4,60})"#) {
            result.place = place.trimmingCharacters(in: .whitespaces)
        }

        // Vestimenta: "vestía …"
        if let clothing = SpanishIntakeEngine.firstMatch(
            in: text,
            pattern: #"(?:vest[ií]a|llevaba puesto|llevaba)\s+([^\n\.]{4,80})"#) {
            result.clothing = clothing.trimmingCharacters(in: .whitespaces)
        }

        return result
    }

    /// Heurística conservadora: 2-5 palabras, sin dígitos, sin palabras de cartel.
    private static func isLikelyName(_ line: String) -> Bool {
        let words = line.split(separator: " ")
        guard (2...5).contains(words.count) else { return false }
        guard line.rangeOfCharacter(from: .decimalDigits) == nil else { return false }
        let banned = ["busca", "ayuda", "información", "informacion", "llamar",
                      "reporte", "favor", "comparte", "años", "vez"]
        let lower = line.lowercased()
        return !banned.contains(where: { lower.contains($0) })
    }
}

// MARK: - Foto de la persona dentro del cartel

/// Detecta el rostro en la foto del cartel con Vision (en el dispositivo)
/// y recorta un retrato alrededor. Si no hay rostro claro, no devuelve
/// nada: nunca se adivina qué parte del cartel es la persona.
enum PosterPhotoExtractor {

    static func extractPersonPhoto(from image: UIImage) async -> Data? {
        // Se normaliza la orientación primero para que las coordenadas
        // de Vision y el recorte hablen del mismo espacio.
        guard let cgImage = normalizedUp(image)?.cgImage else { return nil }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        let faces: [VNFaceObservation]? = await Task.detached(priority: .userInitiated) {
            try? handler.perform([request])
            return request.results
        }.value

        // El rostro más grande es el retrato principal del cartel.
        guard let face = faces?.max(by: { area($0) < area($1) }) else { return nil }

        return crop(cgImage: cgImage, around: face.boundingBox)
    }

    /// Redibuja la imagen con orientación .up real.
    static func normalizedUp(_ image: UIImage) -> UIImage? {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func area(_ face: VNFaceObservation) -> CGFloat {
        face.boundingBox.width * face.boundingBox.height
    }

    /// Expande el cuadro del rostro a un retrato (hombros y cabello
    /// incluidos) y lo recorta de la imagen original.
    private static func crop(cgImage: CGImage,
                             around normalizedBox: CGRect) -> Data? {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        // Vision usa origen abajo-izquierda y coordenadas normalizadas.
        var box = CGRect(x: normalizedBox.minX * width,
                         y: (1 - normalizedBox.maxY) * height,
                         width: normalizedBox.width * width,
                         height: normalizedBox.height * height)

        // Margen de retrato: más espacio arriba (cabello) y abajo (hombros).
        let expandX = box.width * 0.65
        let expandTop = box.height * 0.85
        let expandBottom = box.height * 1.0
        box = CGRect(x: box.minX - expandX,
                     y: box.minY - expandTop,
                     width: box.width + expandX * 2,
                     height: box.height + expandTop + expandBottom)
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))

        guard !box.isEmpty, let cropped = cgImage.cropping(to: box) else { return nil }
        return UIImage(cgImage: cropped).jpegData(compressionQuality: 0.9)
    }
}

// MARK: - Controlador de cámara (AVFoundation)

@Observable
@MainActor
final class PosterCameraController: NSObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentPosition: AVCaptureDevice.Position = .back
    private var captureCompletion: ((UIImage?) -> Void)?

    func start() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            guard await AVCaptureDevice.requestAccess(for: .video) else { return }
        } else if status != .authorized {
            return
        }
        configure(position: currentPosition)
        let session = self.session
        Task.detached { session.startRunning() }
    }

    func stop() {
        let session = self.session
        Task.detached { session.stopRunning() }
    }

    func flip() {
        currentPosition = currentPosition == .back ? .front : .back
        configure(position: currentPosition)
    }

    func capture(completion: @escaping (UIImage?) -> Void) {
        guard session.isRunning else { completion(nil); return }
        captureCompletion = completion
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    private func configure(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.inputs.forEach { session.removeInput($0) }

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
    }
}

extension PosterCameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        Task { @MainActor in
            captureCompletion?(image)
            captureCompletion = nil
        }
    }
}

// MARK: - Visor

struct CameraPreviewView: UIViewRepresentable {
    let controller: PosterCameraController

    func makeUIView(context: Context) -> PreviewLayerView {
        let view = PreviewLayerView()
        view.previewLayer.session = controller.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewLayerView, context: Context) { }

    final class PreviewLayerView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
