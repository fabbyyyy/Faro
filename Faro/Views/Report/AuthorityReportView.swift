//
//  AuthorityReportView.swift
//  Faro
//
//  Reporte formal para autoridad o colectivo. Editable antes de
//  exportar y con nota explícita de que no es denuncia oficial.
//

import SwiftUI
import SwiftData

struct AuthorityReportView: View {
    @Bindable var caseFile: CaseFile
    @Environment(\.modelContext) private var modelContext

    private let services = AppServices.shared

    @State private var kind: ReportKind = .authority
    @State private var isEditing = false
    @State private var pdfURL: URL?

    private var report: GeneratedReport? {
        caseFile.reports.sorted { $0.version > $1.version }.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FaroTheme.sectionSpacing) {
                Picker("Destino", selection: $kind) {
                    ForEach(ReportKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                if let report {
                    reportCard(report)
                    exportSection(report)
                } else {
                    EmptyStateView(
                        symbolName: "doc.text.below.ecg",
                        title: "Aún no hay reporte",
                        message: "FARO estructurará la información del expediente: hechos confirmados, pendientes, evidencia, ubicaciones y preguntas urgentes.",
                        actionTitle: "Generar reporte",
                        action: { generate() }
                    )
                }
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Reporte formal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if report != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        generate()
                    } label: {
                        Label("Regenerar", systemImage: "arrow.clockwise")
                    }
                    .accessibilityHint("Genera una nueva versión con la información actual del expediente")
                }
            }
        }
    }

    private func reportCard(_ report: GeneratedReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                FaroSectionHeader(
                    title: "Versión \(report.version)",
                    subtitle: "Generado el \(report.createdAt.formatted(date: .abbreviated, time: .shortened))"
                        + (report.wasEdited ? " · editado por la familia" : "")
                )
                Spacer()
                Button(isEditing ? "Listo" : "Editar") {
                    if isEditing { caseFile.touch(); try? modelContext.save() }
                    isEditing.toggle()
                }
                .font(.subheadline.weight(.medium))
            }

            if isEditing {
                TextEditor(text: Binding(
                    get: { report.content },
                    set: { report.content = $0; report.wasEdited = true }
                ))
                .font(.caption.monospaced())
                .frame(minHeight: 380)
                .padding(8)
                .background(FaroTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
                .accessibilityLabel("Contenido del reporte, editable")
            } else {
                Text(report.content)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(FaroTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
                    .textSelection(.enabled)
            }
        }
        .faroCard()
    }

    private func exportSection(_ report: GeneratedReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                pdfURL = services.pdfExport.exportPDF(
                    view: AuthorityReportPreview(content: report.content),
                    fileName: "Reporte-FARO-v\(report.version)"
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

            Text("Este reporte organiza información para la familia. No constituye una denuncia oficial ni un documento legal.")
                .font(.caption)
                .foregroundStyle(FaroTheme.secondaryText)
        }
        .faroCard()
    }

    private func generate() {
        let content = services.reportBuilder.buildReport(for: caseFile, kind: kind)
        let version = (report?.version ?? 0) + 1
        let newReport = GeneratedReport(kind: kind, content: content, version: version)
        caseFile.reports.append(newReport)
        caseFile.touch()
        try? modelContext.save()
        pdfURL = nil
    }
}

// MARK: - Vista para exportar el reporte a PDF

struct AuthorityReportPreview: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "light.beacon.max")
                    .foregroundStyle(FaroTheme.amber)
                Text("FARO · Expediente organizado")
                    .font(.headline)
            }
            Divider()
            Text(content)
                .font(.system(size: 11, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(28)
        .background(.white)
        .environment(\.colorScheme, .light)
    }
}
