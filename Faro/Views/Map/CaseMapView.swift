//
//  CaseMapView.swift
//  Faro
//
//  Mapa privado del expediente con MapKit. No es un mapa público:
//  muestra última ubicación, lugares frecuentes, puntos mencionados
//  y descartados, cada uno con su estado de validación.
//

import SwiftUI
import SwiftData
import MapKit

struct CaseMapView: View {
    @Bindable var caseFile: CaseFile

    @State private var selectedLocation: LocationRecord?

    private var activeLocations: [LocationRecord] {
        caseFile.locations
    }

    private var initialPosition: MapCameraPosition {
        if let last = caseFile.locations.first(where: { $0.kind == .lastKnown }) {
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            ))
        }
        if let first = caseFile.locations.first {
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
        return .automatic
    }

    var body: some View {
        Group {
            if activeLocations.isEmpty {
                EmptyStateView(
                    symbolName: "map",
                    title: "Sin ubicaciones todavía",
                    message: "Agrega lugares desde Evidencia. Las ubicaciones precisas se quedan en este mapa privado; la ficha pública solo menciona zonas generales."
                )
                .frame(maxHeight: .infinity)
            } else {
                Map(initialPosition: initialPosition, selection: $selectedLocation) {
                    ForEach(activeLocations) { location in
                        Marker(location.name,
                               systemImage: location.kind.symbolName,
                               coordinate: CLLocationCoordinate2D(latitude: location.latitude,
                                                                  longitude: location.longitude))
                        .tint(location.markerColor)
                        .tag(location)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .safeAreaInset(edge: .bottom) {
                    privacyNote
                }
            }
        }
        .background(FaroTheme.background)
        .navigationTitle("Mapa privado")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedLocation) { location in
            LocationDetailView(location: location, caseFile: caseFile)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var privacyNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(FaroTheme.night)
                .accessibilityHidden(true)
            Text("Mapa privado del expediente. La ficha pública solo menciona zonas generales.")
                .font(.caption)
                .foregroundStyle(FaroTheme.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, FaroTheme.screenPadding)
        .padding(.bottom, 8)
    }
}

private extension LocationRecord {
    var markerColor: Color {
        switch kind {
        case .lastKnown:      return FaroTheme.amber
        case .frequent:       return FaroTheme.night
        case .mentioned:      return FaroTheme.secondaryText
        case .discardedPlace: return FaroTheme.secondaryText.opacity(0.5)
        }
    }
}

// MARK: - Detalle de ubicación

struct LocationDetailView: View {
    @Bindable var location: LocationRecord
    var caseFile: CaseFile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var lookAroundScene: MKLookAroundScene?
    @State private var lookAroundChecked = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FaroTheme.sectionSpacing) {
                    header
                    lookAroundSection
                    zoneSection
                    typeSection
                    validationSection
                }
                .padding(FaroTheme.screenPadding)
            }
            .background(FaroTheme.background)
            .navigationTitle("Ubicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        caseFile.touch()
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .task { await loadLookAround() }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: location.kind.symbolName)
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(location.markerColor)
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(location.kind.displayName) · \(location.precision.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(FaroTheme.secondaryText)
                if !location.details.isEmpty {
                    Text(location.details)
                        .font(.footnote)
                        .foregroundStyle(FaroTheme.secondaryText)
                }
                if !location.source.isEmpty {
                    Text("Fuente: \(location.source)")
                        .font(.caption)
                        .foregroundStyle(FaroTheme.secondaryText)
                }
                ValidationBadge(state: location.validationState)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .faroCard()
    }

    @ViewBuilder
    private var lookAroundSection: some View {
        if let scene = lookAroundScene {
            VStack(alignment: .leading, spacing: 8) {
                FaroSectionHeader(title: "Vista de calle",
                                  subtitle: "Explora el entorno en 360°.")
                LookAroundPreview(initialScene: scene)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius))
            }
        } else if lookAroundChecked {
            HStack(spacing: 10) {
                Image(systemName: "binoculars")
                    .foregroundStyle(FaroTheme.secondaryText)
                    .accessibilityHidden(true)
                Text("No hay vista de calle disponible para este punto.")
                    .font(.caption)
                    .foregroundStyle(FaroTheme.secondaryText)
            }
            .faroCard()
        } else {
            ProgressView("Buscando vista de calle…")
                .font(.caption)
                .frame(maxWidth: .infinity)
                .faroCard()
        }
    }

    private var zoneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FaroSectionHeader(title: "Zona general (compartible)",
                              subtitle: "Lo único que podría mencionarse en público.")
            TextField("Zona que sí podría mencionarse en público",
                      text: $location.generalZoneName)
                .textFieldStyle(.plain)
                .faroCard()
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FaroSectionHeader(title: "Tipo")
            HStack(spacing: 12) {
                Image(systemName: location.kind.symbolName)
                    .foregroundStyle(FaroTheme.night)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Picker("Tipo", selection: $location.kind) {
                    ForEach(LocationKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .tint(FaroTheme.night)
                Spacer(minLength: 0)
            }
            .faroCard()
        }
    }

    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FaroSectionHeader(title: "Validación humana")
            HStack(spacing: 12) {
                Image(systemName: location.validationState.symbolName)
                    .foregroundStyle(FaroTheme.color(for: location.validationState))
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Picker("Estado", selection: $location.validationState) {
                    ForEach(ValidationState.allCases) { state in
                        Text(state.displayName).tag(state)
                    }
                }
                .pickerStyle(.menu)
                .tint(FaroTheme.night)
                Spacer(minLength: 0)
            }
            .faroCard()
        }
    }

    private func loadLookAround() async {
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude,
                                                longitude: location.longitude)
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        lookAroundScene = try? await request.scene
        lookAroundChecked = true
    }
}
