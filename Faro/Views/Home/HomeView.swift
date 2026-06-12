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

    private var existingRealCases: [CaseFile] { cases.filter { !$0.isDemo } }

    var body: some View {
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
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .faroEntrance(visible: appeared, delay: 0.0)
                .accessibilityHidden(true)
                .padding(.bottom, 16)

            Text("FARO")
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .tracking(7)
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

            Button {
                openDemoCase()
            } label: {
                Label("Abrir caso demo", systemImage: "sparkles.rectangle.stack")
            }
            .buttonStyle(HomeGlassActionButtonStyle())
            .accessibilityHint("Abre un expediente de ejemplo con datos ficticios")
            .faroEntrance(visible: appeared, delay: 0.22)

            if let latest = existingRealCases.first {
                Button {
                    router.activeCase = latest
                } label: {
                    Label("Continuar caso", systemImage: "arrow.right.circle")
                }
                .buttonStyle(HomeGlassActionButtonStyle())
                .accessibilityHint("Continúa con \(latest.title)")
                .faroEntrance(visible: appeared, delay: 0.26)
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

    private func openDemoCase() {
        if let demo = cases.first(where: { $0.isDemo }) {
            router.activeCase = demo
        } else {
            let demo = DemoCaseFactory.makeDemoCase(in: modelContext)
            try? modelContext.save()
            router.activeCase = demo
        }
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
