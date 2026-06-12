//
//  RootView.swift
//  Faro
//
//  Raíz de navegación: Inicio cuando no hay caso activo,
//  expediente cuando sí lo hay, y Modo Crisis a pantalla completa.
//

import SwiftUI
import SwiftData

/// Estado global de navegación.
@Observable
@MainActor
final class AppRouter {
    var activeCase: CaseFile?
    var showingCrisisFlow = false
}

struct RootView: View {
    @State private var router = AppRouter()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let activeCase = router.activeCase {
                CaseContainerView(caseFile: activeCase)
            } else {
                HomeView()
            }
        }
        .environment(router)
        .fullScreenCover(isPresented: $router.showingCrisisFlow) {
            CrisisModeView()
                .environment(router)
        }
        .tint(FaroTheme.night)
        .onAppear { handleLaunchArguments() }
    }

    /// Soporte de ensayo de demo: lanzar con "-FaroOpenDemo" abre
    /// directamente el caso demo (útil para presentaciones y pruebas).
    private func handleLaunchArguments() {
        guard ProcessInfo.processInfo.arguments.contains("-FaroOpenDemo") else { return }
        let descriptor = FetchDescriptor<CaseFile>(predicate: #Predicate { $0.isDemo })
        if let demo = (try? modelContext.fetch(descriptor))?.first {
            router.activeCase = demo
        } else {
            router.activeCase = DemoCaseFactory.makeDemoCase(in: modelContext)
            try? modelContext.save()
        }
    }
}
