//
//  DocumentsView.swift
//  Faro
//
//  Documentos generados del caso: fichas técnicas versionadas,
//  reportes y fichas públicas. Regenerar crea una versión nueva;
//  nada se borra automáticamente — trazabilidad completa.
//

import SwiftUI
import SwiftData

struct DocumentsView: View {
    @Bindable var caseFile: CaseFile
    @Environment(\.modelContext) private var modelContext

    @State private var selectedFicha: CaseFicha?
    @State private var saveError = false

    private var finalFichas: [CaseFicha] {
        caseFile.fichas
            .filter { $0.status != .draft }
            .sorted { $0.versionNumber > $1.versionNumber }
    }

    private var reports: [GeneratedReport] {
        caseFile.reports.sorted { $0.version > $1.version }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FaroTheme.sectionSpacing) {
                if finalFichas.isEmpty && reports.isEmpty && caseFile.posters.isEmpty {
                    EmptyStateView(
                        symbolName: "doc.on.doc",
                        title: "Aún no hay documentos",
                        message: "Cuando generes una ficha técnica, una ficha pública o un reporte, quedarán guardados aquí con fecha y versión."
                    )
                } else {
                    if !finalFichas.isEmpty {
                        FaroSectionHeader(title: "Fichas técnicas")
                        ForEach(finalFichas) { ficha in
                            fichaCard(ficha)
                        }
                    }

                    if !reports.isEmpty {
                        FaroSectionHeader(title: "Reportes formales")
                        ForEach(reports) { report in
                            reportCard(report)
                        }
                    }

                    if !caseFile.posters.isEmpty {
                        FaroSectionHeader(title: "Fichas públicas")
                        ForEach(caseFile.posters) { poster in
                            posterCard(poster)
                        }
                    }
                }
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Documentos generados")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedFicha) { ficha in
            NavigationStack {
                GeneratedFichaDetailView(ficha: ficha, caseFile: caseFile)
            }
        }
        .alert("No se pudo guardar", isPresented: $saveError) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text("No pudimos guardar este cambio. Intenta de nuevo antes de cerrar.")
        }
    }

    // MARK: - Tarjetas

    private func fichaCard(_ ficha: CaseFicha) -> some View {
        Button {
            selectedFicha = ficha
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Ficha técnica v\(ficha.versionNumber)", systemImage: "doc.text")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    if ficha.isOutdated(comparedTo: caseFile) || ficha.status == .outdated {
                        outdatedBadge
                    }
                }
                Text("Generada el \(ficha.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)

                if ficha.isOutdated(comparedTo: caseFile) || ficha.status == .outdated {
                    Text("El caso cambió desde que se generó esta ficha. Puedes regenerarla; esta versión se conserva.")
                        .font(.caption)
                        .foregroundStyle(FaroTheme.amber)
                }
            }
            .faroCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre la ficha técnica versión \(ficha.versionNumber)")
    }

    private var outdatedBadge: some View {
        Label("Desactualizada", systemImage: "exclamationmark.arrow.circlepath")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(FaroTheme.amber.opacity(0.15))
            .foregroundStyle(FaroTheme.amber)
            .clipShape(Capsule())
    }

    private func reportCard(_ report: GeneratedReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(report.kind.displayName) · v\(report.version)", systemImage: "doc.text.below.ecg")
                .font(.headline)
            Text("Generado el \(report.createdAt.formatted(date: .abbreviated, time: .shortened))"
                 + (report.wasEdited ? " · editado" : ""))
                .font(.caption)
                .foregroundStyle(FaroTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .faroCard()
    }

    private func posterCard(_ poster: PublicPoster) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Ficha pública · \(poster.tone.displayName)", systemImage: "doc.richtext")
                .font(.headline)
            Text("Creada el \(poster.createdAt.formatted(date: .abbreviated, time: .shortened))"
                 + (poster.approvedByFamily ? " · aprobada por la familia" : " · sin aprobar"))
                .font(.caption)
                .foregroundStyle(poster.approvedByFamily ? FaroTheme.confirmedGreen : FaroTheme.amber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .faroCard()
    }
}

// MARK: - Detalle de ficha generada

struct GeneratedFichaDetailView: View {
    @Bindable var ficha: CaseFicha
    var caseFile: CaseFile

    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if ficha.isOutdated(comparedTo: caseFile) || ficha.status == .outdated {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.arrow.circlepath")
                            .foregroundStyle(FaroTheme.amber)
                        Text("El caso cambió desde que se generó esta ficha. Puedes regenerarla desde Revisión; esta versión se conserva.")
                            .font(.subheadline)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FaroTheme.amber.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
                }

                Text(ficha.content)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(FaroTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
                    .textSelection(.enabled)

                Button {
                    pdfURL = AppServices.shared.pdfExport.exportPDF(
                        view: AuthorityReportPreview(content: ficha.content),
                        fileName: "Ficha-tecnica-v\(ficha.versionNumber)"
                    )
                } label: {
                    Label("Exportar como PDF", systemImage: "doc.badge.arrow.up")
                }
                .buttonStyle(FaroPrimaryButtonStyle())

                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("Compartir PDF", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(FaroSecondaryButtonStyle())
                }
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Ficha técnica v\(ficha.versionNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Listo") { dismiss() }
            }
        }
    }
}
