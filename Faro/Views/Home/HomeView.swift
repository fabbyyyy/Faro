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
        .background(FaroTheme.background)
        .onAppear {
            withAnimation { appeared = true }
        }
        .sheet(isPresented: $showingEthicsNotice) {
            EthicsNoticeView {
                showingEthicsNotice = false
                router.showingCrisisFlow = true
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
        }
    }

    // MARK: - Secciones

    private var heroSection: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(FaroTheme.amber.opacity(0.10))
                    .frame(width: 100, height: 100)
                    .blur(radius: 18)
                    .faroEntrance(visible: appeared, delay: 0.0)

                Image(systemName: "light.beacon.max")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(FaroTheme.amber)
                    .faroEntrance(visible: appeared, delay: 0.04)
            }
            .frame(width: 100, height: 90)
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
            .buttonStyle(FaroPrimaryButtonStyle())
            .accessibilityHint("Inicia el registro guiado de un nuevo caso")
            .faroEntrance(visible: appeared, delay: 0.18)

            Button {
                openDemoCase()
            } label: {
                Label("Abrir caso demo", systemImage: "sparkles.rectangle.stack")
            }
            .buttonStyle(FaroSecondaryButtonStyle())
            .accessibilityHint("Abre un expediente de ejemplo con datos ficticios")
            .faroEntrance(visible: appeared, delay: 0.22)

            if let latest = existingRealCases.first {
                Button {
                    router.activeCase = latest
                } label: {
                    Label("Continuar caso", systemImage: "arrow.right.circle")
                }
                .buttonStyle(FaroSecondaryButtonStyle())
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
    let onContinue: () -> Void
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

            Button("Entendido, crear caso", action: onContinue)
                .buttonStyle(FaroPrimaryButtonStyle())
                .faroEntrance(visible: appeared, delay: 0.32)

            Text("Vamos paso a paso. Puedes saltar cualquier pregunta.")
                .font(.footnote)
                .foregroundStyle(FaroTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
                .faroEntrance(visible: appeared, delay: 0.36)
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
