//
//  CaseContainerView.swift
//  Faro
//
//  Navegación del expediente. En iPhone: pila vertical simple y guiada.
//  En iPad: NavigationSplitView tipo "centro de control" con secciones
//  a la izquierda y detalle amplio a la derecha.
//

import SwiftUI
import SwiftData

/// Secciones del expediente.
enum CaseSection: String, CaseIterable, Identifiable {
    case dashboard
    case timeline
    case evidence
    case validation
    case poster
    case report
    case questions
    case trust
    case map
    case privacy
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:  return "Resumen del caso"
        case .timeline:   return "Línea de tiempo"
        case .evidence:   return "Evidencia"
        case .validation: return "Por revisar"
        case .poster:     return "Ficha pública"
        case .report:     return "Reporte formal"
        case .questions:  return "Preguntas pendientes"
        case .trust:      return "Red de confianza"
        case .map:        return "Mapa privado"
        case .privacy:    return "Privacidad y ética"
        case .settings:   return "Ajustes del caso"
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard:  return "rectangle.3.group"
        case .timeline:   return "clock.arrow.circlepath"
        case .evidence:   return "tray.full"
        case .validation: return "checkmark.seal"
        case .poster:     return "doc.richtext"
        case .report:     return "doc.text.below.ecg"
        case .questions:  return "questionmark.circle"
        case .trust:      return "person.2"
        case .map:        return "map"
        case .privacy:    return "lock.shield"
        case .settings:   return "gearshape"
        }
    }
}

struct CaseContainerView: View {
    @Bindable var caseFile: CaseFile
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selectedSection: CaseSection? = .dashboard

    var body: some View {
        if sizeClass == .regular {
            splitLayout
        } else {
            compactLayout
        }
    }

    // MARK: - iPad: case board

    private var splitLayout: some View {
        NavigationSplitView {
            List(CaseSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.symbolName)
                    .badge(badgeCount(for: section))
                    .tag(section)
            }
            .navigationTitle(caseFile.person?.displayName ?? "Expediente")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        router.activeCase = nil
                    } label: {
                        Label("Inicio", systemImage: "chevron.backward")
                    }
                    .accessibilityLabel("Volver al inicio")
                }
            }
        } detail: {
            NavigationStack {
                sectionView(selectedSection ?? .dashboard)
            }
        }
    }

    // MARK: - iPhone: pila guiada

    private var compactLayout: some View {
        NavigationStack {
            CaseDashboardView(caseFile: caseFile, onNavigate: nil)
                .navigationDestination(for: CaseSection.self) { section in
                    sectionView(section)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            router.activeCase = nil
                        } label: {
                            Label("Inicio", systemImage: "chevron.backward")
                        }
                        .accessibilityLabel("Volver al inicio")
                    }
                }
        }
    }

    // MARK: - Detalle de sección

    @ViewBuilder
    private func sectionView(_ section: CaseSection) -> some View {
        switch section {
        case .dashboard:
            CaseDashboardView(caseFile: caseFile) { selectedSection = $0 }
        case .timeline:   TimelineView(caseFile: caseFile)
        case .evidence:   EvidenceVaultView(caseFile: caseFile)
        case .validation: ValidationCenterView(caseFile: caseFile)
        case .poster:     PublicPosterView(caseFile: caseFile)
        case .report:     AuthorityReportView(caseFile: caseFile)
        case .questions:  QuestionsView(caseFile: caseFile)
        case .trust:      TrustNetworkView(caseFile: caseFile)
        case .map:        CaseMapView(caseFile: caseFile)
        case .privacy:    PrivacyEthicsView()
        case .settings:   CaseSettingsView(caseFile: caseFile)
        }
    }

    private func badgeCount(for section: CaseSection) -> Int {
        switch section {
        case .validation: return caseFile.pendingReviewCount
        case .questions:  return caseFile.pendingQuestions.count
        default:          return 0
        }
    }
}
