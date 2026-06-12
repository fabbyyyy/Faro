//
//  PublicPosterView.swift
//  Faro
//
//  Ficha pública ética: genera una ficha segura para compartir,
//  explica qué se excluyó y por qué, y exporta como imagen o PDF.
//

import SwiftUI
import SwiftData

struct PublicPosterView: View {
    @Bindable var caseFile: CaseFile
    @Environment(\.modelContext) private var modelContext

    private let services = AppServices.shared

    @State private var tone: PosterTone = .community
    @State private var generatingText = false
    @State private var pdfURL: URL?
    @State private var posterImage: UIImage?

    private var poster: PublicPoster? { caseFile.posters.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FaroTheme.sectionSpacing) {
                if let poster {
                    posterContent(poster)
                } else {
                    EmptyStateView(
                        symbolName: "doc.richtext",
                        title: "Aún no hay ficha pública",
                        message: "FARO preparará una ficha con la información segura para compartir y te explicará qué deja fuera y por qué.",
                        actionTitle: "Generar ficha pública",
                        action: { generatePoster() }
                    )
                }
            }
            .padding(FaroTheme.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(FaroTheme.background)
        .navigationTitle("Ficha pública")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Contenido de la ficha

    @ViewBuilder
    private func posterContent(_ poster: PublicPoster) -> some View {
        // Vista previa de la ficha
        PublicPosterPreview(caseFile: caseFile, poster: poster)
            .frame(maxWidth: .infinity)

        // Aprobación explícita de la familia
        approvalCard(poster)

        // Qué se incluyó
        VStack(alignment: .leading, spacing: 10) {
            FaroSectionHeader(title: "Qué incluye")
            ForEach(poster.includedFields, id: \.self) { field in
                Label(field, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .faroCard()

        // Qué se excluyó y por qué (núcleo ético de la función)
        if !poster.excludedFields.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                FaroSectionHeader(title: "Qué se excluyó y por qué",
                                  subtitle: "Proteger esta información también protege la búsqueda.")
                ForEach(poster.excludedFields) { field in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.lock")
                            .foregroundStyle(FaroTheme.amber)
                            .padding(.top, 2)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.fieldName)
                                .font(.subheadline.weight(.medium))
                            Text(field.reason)
                                .font(.caption)
                                .foregroundStyle(FaroTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Excluido: \(field.fieldName). \(field.reason)")
                }
            }
            .faroCard()
        }

        // Texto corto para difusión
        shareTextCard(poster)

        // Exportación
        exportSection(poster)
    }

    private func approvalCard(_ poster: PublicPoster) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { poster.approvedByFamily },
                set: { poster.approvedByFamily = $0; caseFile.touch() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Revisada y aprobada por la familia")
                        .font(.subheadline.weight(.medium))
                    Text("Compártela solo cuando la hayan revisado.")
                        .font(.caption)
                        .foregroundStyle(FaroTheme.secondaryText)
                }
            }
            .tint(FaroTheme.confirmedGreen)
        }
        .faroCard()
    }

    private func shareTextCard(_ poster: PublicPoster) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FaroSectionHeader(title: "Texto para WhatsApp y redes",
                              subtitle: "Sobrio y claro. Elige el tono; nunca exagera ni inventa.")

            Picker("Tono", selection: $tone) {
                ForEach(PosterTone.allCases) { tone in
                    Text(tone.displayName).tag(tone)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: tone) { regenerateShareText() }

            if generatingText {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Redactando…")
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.secondaryText)
                }
            } else if !poster.shareText.isEmpty {
                Text(poster.shareText)
                    .font(.subheadline)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FaroTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
                    .textSelection(.enabled)

                ShareLink(item: poster.shareText) {
                    Label("Compartir texto", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(FaroSecondaryButtonStyle(fullWidth: false))
                .disabled(!poster.approvedByFamily)

                if !poster.approvedByFamily {
                    Text("Activa la aprobación de la familia para poder compartir.")
                        .font(.caption)
                        .foregroundStyle(FaroTheme.amber)
                }
            } else {
                Button("Redactar texto de difusión") { regenerateShareText() }
                    .buttonStyle(FaroSecondaryButtonStyle(fullWidth: false))
            }
        }
        .faroCard()
    }

    private func exportSection(_ poster: PublicPoster) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FaroSectionHeader(title: "Exportar ficha")

            HStack(spacing: 10) {
                Button {
                    exportPDF(poster)
                } label: {
                    Label("PDF", systemImage: "doc.badge.arrow.up")
                }
                .buttonStyle(FaroSecondaryButtonStyle())

                Button {
                    posterImage = services.pdfExport.exportImage(
                        view: PublicPosterPreview(caseFile: caseFile, poster: poster)
                    )
                } label: {
                    Label("Imagen", systemImage: "photo.badge.arrow.down")
                }
                .buttonStyle(FaroSecondaryButtonStyle())
            }
            .disabled(!poster.approvedByFamily)

            if let pdfURL {
                ShareLink(item: pdfURL) {
                    Label("Compartir PDF generado", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(FaroPrimaryButtonStyle())
            }

            if let posterImage {
                ShareLink(item: Image(uiImage: posterImage),
                          preview: SharePreview("Ficha de búsqueda", image: Image(uiImage: posterImage))) {
                    Label("Compartir imagen generada", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(FaroPrimaryButtonStyle())
            }

            if !poster.approvedByFamily {
                Text("La exportación se habilita cuando la familia aprueba la ficha.")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
            }
        }
        .faroCard()
    }

    // MARK: - Acciones

    private func generatePoster() {
        let poster = services.posterBuilder.buildPoster(for: caseFile, tone: tone)
        caseFile.posters.append(poster)
        caseFile.touch()
        try? modelContext.save()
        regenerateShareText()
    }

    private func regenerateShareText() {
        guard let poster else { return }
        generatingText = true
        let person = caseFile.person
        let zone = services.posterBuilder.generalZone(for: caseFile)
        Task {
            let text = await services.ai.draftShareText(
                personName: person?.displayName ?? "",
                age: person?.approximateAge,
                zone: zone,
                date: person?.lastSeenAt,
                clothing: person?.clothingDescription ?? "",
                contact: poster.publicContact,
                tone: tone
            )
            poster.shareText = text
            poster.tone = tone
            caseFile.touch()
            try? modelContext.save()
            generatingText = false
        }
    }

    private func exportPDF(_ poster: PublicPoster) {
        pdfURL = services.pdfExport.exportPDF(
            view: PublicPosterPreview(caseFile: caseFile, poster: poster),
            fileName: "Ficha-\(caseFile.person?.name.replacingOccurrences(of: " ", with: "-") ?? "busqueda")"
        )
    }
}

// MARK: - Vista previa de la ficha (también se usa para exportar)

struct PublicPosterPreview: View {
    let caseFile: CaseFile
    let poster: PublicPoster

    private var person: MissingPerson? { caseFile.person }

    var body: some View {
        VStack(spacing: 14) {
            Text("SE BUSCA")
                .font(.title2.weight(.bold))
                .tracking(4)
                .foregroundStyle(FaroTheme.night)

            if let data = person?.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
                    .accessibilityLabel("Foto de la persona")
            }

            Text(person?.displayName ?? "")
                .font(.title.weight(.semibold))

            if let age = person?.approximateAge {
                Text("\(age) años")
                    .font(.headline)
                    .foregroundStyle(FaroTheme.secondaryText)
            }

            VStack(spacing: 6) {
                if let lastSeen = person?.lastSeenAt {
                    posterRow("Última vez vista",
                              lastSeen.formatted(date: .long, time: .shortened))
                }
                let zone = AppServices.shared.posterBuilder.generalZone(for: caseFile)
                if !zone.isEmpty {
                    posterRow("Zona", zone)
                }
                if let desc = person?.physicalDescription, !desc.isEmpty {
                    posterRow("Señas", desc)
                }
                if let clothing = person?.clothingDescription, !clothing.isEmpty {
                    posterRow("Vestía", clothing)
                }
            }

            if !poster.publicContact.isEmpty {
                VStack(spacing: 2) {
                    Text("Si tienes información:")
                        .font(.footnote)
                        .foregroundStyle(FaroTheme.secondaryText)
                    Text(poster.publicContact)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(FaroTheme.night)
                }
                .padding(.top, 4)
            }

            Text("Ficha generada con FARO · comparte con responsabilidad")
                .font(.caption2)
                .foregroundStyle(FaroTheme.secondaryText)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous)
                .strokeBorder(FaroTheme.night.opacity(0.15), lineWidth: 1)
        )
        .environment(\.colorScheme, .light) // La ficha exportada siempre en claro
    }

    private func posterRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FaroTheme.secondaryText)
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.black.opacity(0.85))
        }
        .accessibilityElement(children: .combine)
    }
}
