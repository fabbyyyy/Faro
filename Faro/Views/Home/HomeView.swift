//
//  HomeView.swift
//  Faro
//
//  Pantalla inicial mínima: la mayoría de las personas llegan aquí
//  ya en crisis. Tres acciones, cero fricción, y una advertencia
//  ética breve antes de crear un caso.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CaseFile.updatedAt, order: .reverse) private var cases: [CaseFile]

    @State private var showingEthicsNotice = false
    @State private var appeared = false

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            homeContent(showingMyCases: $router.showingMyCases)
        }
    }

    private func homeContent(showingMyCases: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            Spacer()
            heroSection
            Spacer()
            actionsSection
            privacyFooter
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                FaroTheme.background
                // Velo que nace en la esquina superior derecha y se
                // desvanece hacia abajo: azul noche en claro, crema en oscuro.
                RadialGradient(
                    colors: [
                        Color(light: Color(red: 0.10, green: 0.16, blue: 0.28).opacity(0.38),
                              dark: Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.34)),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 620
                )
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation { appeared = true }
        }
        .navigationDestination(isPresented: showingMyCases) {
            MyCasesGridView { caseFile in
                router.activeCase = caseFile
            }
        }
        .sheet(isPresented: $showingEthicsNotice) {
            EthicsNoticeView { mode in
                showingEthicsNotice = false
                router.intakeMode = mode
                router.showingCrisisFlow = true
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
    }

    // MARK: - Secciones

    private var heroSection: some View {
        VStack(spacing: 0) {
            Image("faro")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .faroEntrance(visible: appeared, delay: 0.0)
                .accessibilityHidden(true)
                .padding(.bottom, 24)

            Text("FARO")
                .font(.system(size: 42, weight: .semibold))
                .tracking(2)
                .foregroundStyle(FaroTheme.night)
                .accessibilityAddTraits(.isHeader)
                .faroEntrance(visible: appeared, delay: 0.08)

            Text("Organiza las primeras horas\ncon claridad y privacidad")
                .font(.title3)
                .foregroundStyle(FaroTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .faroEntrance(visible: appeared, delay: 0.13)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showingEthicsNotice = true
            } label: {
                Label("Crear caso", systemImage: "plus.circle")
            }
            .buttonStyle(HomeGlassActionButtonStyle(prominent: true))
            .accessibilityHint("Inicia el registro guiado de un nuevo caso")
            .faroEntrance(visible: appeared, delay: 0.18)

            if !cases.isEmpty {
                Button {
                    router.showingMyCases = true
                } label: {
                    Label("Mis casos", systemImage: "rectangle.grid.2x2")
                }
                .buttonStyle(HomeGlassActionButtonStyle())
                .accessibilityHint("Muestra tus casos para continuar con uno")
                .faroEntrance(visible: appeared, delay: 0.22)
            }
        }
        .padding(.horizontal, FaroTheme.screenPadding)
        .padding(.bottom, 14)
    }

    private var privacyFooter: some View {
        Text("Tus datos se guardan solo en este dispositivo.")
            .font(.footnote)
            .foregroundStyle(FaroTheme.secondaryText)
            .padding(.bottom, 28)
            .faroEntrance(visible: appeared, delay: 0.28)
    }

}

// MARK: - Mis casos: cuadrícula con foto y nombre

struct MyCasesGridView: View {
    let onOpen: (CaseFile) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CaseFile.updatedAt, order: .reverse) private var cases: [CaseFile]

    @State private var isSelecting = false
    @State private var selectedIDs = Set<UUID>()
    @State private var pendingDeletion: [CaseFile] = []

    private var selectedCases: [CaseFile] {
        cases.filter { selectedIDs.contains($0.id) }
    }

    private var pendingCases: [CaseFile] {
        cases.filter { $0.status != .completed }
    }

    private var completedCases: [CaseFile] {
        cases.filter { $0.status == .completed }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !pendingCases.isEmpty {
                    sectionHeader("Pendientes")
                    casesGrid(pendingCases)
                }
                if !completedCases.isEmpty {
                    sectionHeader("Completados")
                        .padding(.top, pendingCases.isEmpty ? 0 : 16)
                    casesGrid(completedCases)
                }
            }
            .padding(FaroTheme.screenPadding)
        }
        .background(FaroTheme.background)
        .navigationTitle("Mis casos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSelecting ? "Cancelar" : "Seleccionar") {
                    withAnimation(FaroTheme.springSnappy) {
                        isSelecting.toggle()
                        selectedIDs.removeAll()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionActionsBar
            }
        }
        .confirmationDialog(
            pendingDeletion.count == 1 ? "¿Eliminar este caso?" : "¿Eliminar \(pendingDeletion.count) casos?",
            isPresented: Binding(
                get: { !pendingDeletion.isEmpty },
                set: { if !$0 { pendingDeletion = [] } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eliminar definitivamente", role: .destructive) {
                for caseFile in pendingDeletion {
                    modelContext.delete(caseFile)
                }
                try? modelContext.save()
                pendingDeletion = []
                selectedIDs.removeAll()
                isSelecting = false
            }
            Button("Cancelar", role: .cancel) { pendingDeletion = [] }
        } message: {
            Text("Se borrará todo el expediente de este dispositivo: evidencia, línea de tiempo y documentos. Esta acción no se puede deshacer.")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }

    private func casesGrid(_ items: [CaseFile]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)],
                  spacing: 12) {
            ForEach(items) { caseFile in
                Button {
                    if isSelecting {
                        toggleSelection(caseFile)
                    } else {
                        // Sin dismiss: al volver del caso se regresa aquí,
                        // a la selección de casos, no al inicio.
                        onOpen(caseFile)
                    }
                } label: {
                    caseTile(caseFile)
                        .overlay(alignment: .topTrailing) {
                            if isSelecting {
                                selectionBadge(selected: selectedIDs.contains(caseFile.id))
                            }
                        }
                }
                .buttonStyle(FaroCardButtonStyle())
                .contextMenu {
                    Button {
                        markCompleted([caseFile])
                    } label: {
                        Label("Marcar como completado", systemImage: "checkmark.circle")
                    }
                    Button(role: .destructive) {
                        pendingDeletion = [caseFile]
                    } label: {
                        Label("Eliminar caso", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: Selección múltiple

    private func toggleSelection(_ caseFile: CaseFile) {
        if selectedIDs.contains(caseFile.id) {
            selectedIDs.remove(caseFile.id)
        } else {
            selectedIDs.insert(caseFile.id)
        }
    }

    private func selectionBadge(selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundStyle(selected ? FaroTheme.night : .white)
            .background(Circle().fill(.white.opacity(selected ? 1 : 0.25)))
            .padding(8)
            .accessibilityHidden(true)
    }

    private var selectionActionsBar: some View {
        HStack(spacing: 10) {
            Button {
                markCompleted(selectedCases)
            } label: {
                Label("Completado", systemImage: "checkmark.circle")
            }
            .buttonStyle(SelectionGlassActionButtonStyle())

            Button {
                pendingDeletion = selectedCases
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
            .buttonStyle(SelectionGlassActionButtonStyle(tint: FaroTheme.destructive,
                                                         foreground: .white))
        }
        .disabled(selectedIDs.isEmpty)
        .opacity(selectedIDs.isEmpty ? 0.5 : 1)
        .padding(.horizontal, FaroTheme.screenPadding)
        .padding(.vertical, 10)
        .background(Color.clear)
    }

    private func markCompleted(_ targets: [CaseFile]) {
        for caseFile in targets {
            caseFile.status = .completed
        }
        try? modelContext.save()
        withAnimation(FaroTheme.springSnappy) {
            selectedIDs.removeAll()
            isSelecting = false
        }
    }

    private func caseTile(_ caseFile: CaseFile) -> some View {
        let name = caseFile.person?.displayName ?? caseFile.title
        return ZStack(alignment: .bottomLeading) {
            // Fondo: la foto de la persona si existe; si no, azul noche suave.
            if let data = caseFile.person?.photoData, let image = UIImage(data: data) {
                Color.clear
                    .overlay(
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipped()
                // Velo para que el nombre siempre se lea.
                LinearGradient(colors: [.clear, .black.opacity(0.65)],
                               startPoint: .center, endPoint: .bottom)
            } else {
                FaroTheme.night.opacity(0.10)
                Image(systemName: "person.crop.rectangle")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(FaroTheme.night.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(caseFile.person?.photoData != nil ? .white : FaroTheme.night)
                    .lineLimit(2)
                Text("Actualizado \(caseFile.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(caseFile.person?.photoData != nil
                                     ? .white.opacity(0.8)
                                     : FaroTheme.secondaryText)
            }
            .padding(12)
        }
        .frame(height: 170)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Caso de \(name)")
        .accessibilityHint("Abre este caso")
    }
}

// MARK: - Advertencia ética previa a crear caso

struct EthicsNoticeView: View {
    /// Recibe el modo de alta elegido por la familia.
    let onContinue: (AppRouter.IntakeMode) -> Void
    @State private var appeared = false

    private let rows: [(symbol: String, text: String)] = [
        ("building.columns",
         "FARO no reemplaza a las autoridades, colectivos ni asesoría profesional. Es una herramienta para organizar información."),
        ("person.2",
         "La información generada (resúmenes, fichas, reportes) debe ser revisada por la familia antes de usarse o compartirse."),
        ("lock.shield",
         "FARO te ayuda a proteger datos sensibles: lo privado se queda privado salvo que tú decidas compartirlo.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Antes de empezar")
                .font(.title2.weight(.semibold))
                .padding(.top, 28)
                .accessibilityAddTraits(.isHeader)
                .faroEntrance(visible: appeared, delay: 0.0)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                noticeRow(symbol: row.symbol, text: row.text)
                    .faroEntrance(visible: appeared, delay: Double(index) * 0.07 + 0.08)
            }

            Spacer()

            Text("¿Cómo prefieres empezar?")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .faroEntrance(visible: appeared, delay: 0.30)

            Button { onContinue(.conversational) } label: {
                Label("Conversar con el asistente", systemImage: "bubble.left.and.text.bubble.right")
            }
            .buttonStyle(HomeGlassActionButtonStyle(prominent: true))
            .accessibilityHint("Respondes con tus palabras y el asistente organiza la información")
            .faroEntrance(visible: appeared, delay: 0.33)

            Button { onContinue(.guided) } label: {
                Label("Ir paso a paso", systemImage: "list.number")
            }
            .buttonStyle(HomeGlassActionButtonStyle())
            .accessibilityHint("Una pregunta corta a la vez, más sencillo bajo estrés")
            .faroEntrance(visible: appeared, delay: 0.36)

            Button { onContinue(.posterImport) } label: {
                Label("Tengo un cartel o ficha", systemImage: "text.viewfinder")
            }
            .buttonStyle(HomeGlassActionButtonStyle())
            .accessibilityHint("Fotografía un cartel de búsqueda y FARO extrae los datos para que los revises")
            .faroEntrance(visible: appeared, delay: 0.39)

            Text("Como te sea más cómodo. Puedes saltar cualquier pregunta.")
                .font(.footnote)
                .foregroundStyle(FaroTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
                .faroEntrance(visible: appeared, delay: 0.42)
        }
        .padding(.horizontal, FaroTheme.screenPadding)
        .background(FaroTheme.background)
        .onAppear { withAnimation { appeared = true } }
    }

    private func noticeRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(FaroTheme.night)
                .frame(width: 32, height: 32)
                .background(FaroTheme.night.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HomeGlassActionButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            configuration.label
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .foregroundStyle(foregroundStyle)
                .glassEffect(glassEffect.interactive(), in: .capsule)
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(FaroTheme.springSnappy, value: configuration.isPressed)
        } else if prominent {
            FaroPrimaryButtonStyle().makeBody(configuration: configuration)
        } else {
            FaroSecondaryButtonStyle().makeBody(configuration: configuration)
        }
    }

    private var foregroundStyle: Color {
        prominent
            ? Color(light: .white, dark: Color(red: 0.043, green: 0.075, blue: 0.122))
            : FaroTheme.night
    }

    @available(iOS 26, *)
    private var glassEffect: Glass {
        prominent ? .regular.tint(FaroTheme.night) : .regular
    }
}

private struct SelectionGlassActionButtonStyle: ButtonStyle {
    var tint: Color?
    var foreground: Color = FaroTheme.night

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            if let tint {
                label(configuration)
                    .foregroundStyle(foreground)
                    .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
            } else {
                label(configuration)
                    .foregroundStyle(foreground)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
        } else if let tint {
            label(configuration)
                .background(tint.opacity(configuration.isPressed ? 0.82 : 1))
                .foregroundStyle(foreground)
                .clipShape(Capsule())
        } else {
            label(configuration)
                .background(FaroTheme.surface.opacity(configuration.isPressed ? 0.85 : 1))
                .foregroundStyle(foreground)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(FaroTheme.night.opacity(0.25), lineWidth: 1))
        }
    }

    private func label(_ configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(FaroTheme.springSnappy, value: configuration.isPressed)
    }
}
