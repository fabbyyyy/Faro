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

    private var existingRealCases: [CaseFile] { cases.filter { !$0.isDemo } }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Identidad: sobria, sin dramatismo.
            Image(systemName: "light.beacon.max")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(FaroTheme.amber)
                .padding(.bottom, 18)
                .accessibilityHidden(true)

            Text("FARO")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .tracking(6)
                .foregroundStyle(FaroTheme.night)
                .accessibilityAddTraits(.isHeader)

            Text("Organiza las primeras horas\ncon claridad y privacidad")
                .font(.title3)
                .foregroundStyle(FaroTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showingEthicsNotice = true
                } label: {
                    Label("Crear caso", systemImage: "plus.circle")
                }
                .buttonStyle(FaroPrimaryButtonStyle())
                .accessibilityHint("Inicia el registro guiado de un nuevo caso")

                Button {
                    openDemoCase()
                } label: {
                    Label("Abrir caso demo", systemImage: "sparkles.rectangle.stack")
                }
                .buttonStyle(FaroSecondaryButtonStyle())
                .accessibilityHint("Abre un expediente de ejemplo con datos ficticios")

                if let latest = existingRealCases.first {
                    Button {
                        router.activeCase = latest
                    } label: {
                        Label("Continuar caso", systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(FaroSecondaryButtonStyle())
                    .accessibilityHint("Continúa con \(latest.title)")
                }
            }
            .padding(.horizontal, FaroTheme.screenPadding)
            .padding(.bottom, 14)

            Text("Tus datos se guardan solo en este dispositivo.")
                .font(.footnote)
                .foregroundStyle(FaroTheme.secondaryText)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FaroTheme.background)
        .sheet(isPresented: $showingEthicsNotice) {
            EthicsNoticeView {
                showingEthicsNotice = false
                router.showingCrisisFlow = true
            }
            .presentationDetents([.medium, .large])
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Antes de empezar")
                .font(.title2.weight(.semibold))
                .padding(.top, 26)
                .accessibilityAddTraits(.isHeader)

            noticeRow(symbol: "building.columns",
                      text: "FARO no reemplaza a las autoridades, colectivos ni asesoría profesional. Es una herramienta para organizar información.")
            noticeRow(symbol: "person.2",
                      text: "La información generada (resúmenes, fichas, reportes) debe ser revisada por la familia antes de usarse o compartirse.")
            noticeRow(symbol: "lock.shield",
                      text: "FARO te ayuda a proteger datos sensibles: lo privado se queda privado salvo que tú decidas compartirlo.")

            Spacer()

            Button("Entendido, crear caso", action: onContinue)
                .buttonStyle(FaroPrimaryButtonStyle())

            Text("Vamos paso a paso. Puedes saltar cualquier pregunta.")
                .font(.footnote)
                .foregroundStyle(FaroTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, FaroTheme.screenPadding)
        .background(FaroTheme.background)
    }

    private func noticeRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(FaroTheme.night)
                .frame(width: 30)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
