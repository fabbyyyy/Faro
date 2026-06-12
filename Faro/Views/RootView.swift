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
    /// Cómo se registra un caso nuevo: conversando o paso a paso.
    enum IntakeMode {
        /// Chat de intake con asistente (extracción de varios datos por frase).
        case conversational
        /// Una pregunta por pantalla, respuestas cortas (modo bajo estrés).
        case guided
        /// Fotografiar un cartel de búsqueda existente y extraer sus datos.
        case posterImport
    }

    var activeCase: CaseFile?
    var showingCrisisFlow = false
    /// Modo elegido para el alta del caso actual.
    var intakeMode: IntakeMode = .conversational
}

struct RootView: View {
    @State private var router = AppRouter()
    @Environment(\.modelContext) private var modelContext

    /// El cover del sistema desliza desde abajo; la importación de cartel
    /// trae su propia animación (pill → pantalla completa), así que se
    /// presenta como overlay y no entra por aquí.
    private var coverPresented: Binding<Bool> {
        Binding(
            get: { router.showingCrisisFlow && router.intakeMode != .posterImport },
            set: { router.showingCrisisFlow = $0 }
        )
    }

    var body: some View {
        ZStack {
            Group {
                if let activeCase = router.activeCase {
                    CaseContainerView(caseFile: activeCase)
                } else {
                    HomeView()
                }
            }

            // La cámara del cartel emerge desde el Dynamic Island sobre
            // la pantalla actual, sin transición del sistema.
            if router.showingCrisisFlow && router.intakeMode == .posterImport {
                PosterImportView()
                    .zIndex(10)
                    .transition(.opacity)
            }
        }
        .environment(router)
        .fullScreenCover(isPresented: coverPresented) {
            Group {
                switch router.intakeMode {
                case .conversational: ChatIntakeView()
                case .guided:         CrisisModeView()
                case .posterImport:   EmptyView()
                }
            }
            .environment(router)
        }
        .tint(FaroTheme.night)
        .onAppear { handleLaunchArguments() }
    }

    /// Soporte de ensayo de demo: lanzar con "-FaroOpenDemo" abre
    /// directamente el caso demo (útil para presentaciones y pruebas).
    private func handleLaunchArguments() {
        if ProcessInfo.processInfo.arguments.contains("-FaroOpenIntake") {
            router.intakeMode = .conversational
            router.showingCrisisFlow = true
            return
        }

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
