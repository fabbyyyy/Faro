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
        VStack(spacing: 0) {
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
                        .tint(markerColor(for: location))
                        .tag(location)
                    }
                }
                .frame(minHeight: 280)

                locationList
            }
        }
        .background(FaroTheme.background)
        .navigationTitle("Mapa privado")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedLocation) { location in
            LocationDetailView(location: location, caseFile: caseFile)
                .presentationDetents([.medium])
        }
    }

    private func markerColor(for location: LocationRecord) -> Color {
        switch location.kind {
        case .lastKnown:      return FaroTheme.amber
        case .frequent:       return FaroTheme.night
        case .mentioned:      return FaroTheme.secondaryText
        case .discardedPlace: return FaroTheme.secondaryText.opacity(0.5)
        }
    }

    private var locationList: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Este mapa es privado del expediente. Si generas una ficha pública, las ubicaciones precisas se convierten en zonas generales.")
                    .font(.footnote)
                    .foregroundStyle(FaroTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 2)

                ForEach(activeLocations) { location in
                    Button {
                        selectedLocation = location
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: location.kind.symbolName)
                                .foregroundStyle(markerColor(for: location))
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("\(location.kind.displayName) · \(location.precision.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(FaroTheme.secondaryText)
                            }
                            Spacer()
                            ValidationBadge(state: location.validationState)
                        }
                        .faroCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(FaroTheme.screenPadding)
        }
    }
}

// MARK: - Detalle de ubicación

struct LocationDetailView: View {
    @Bindable var location: LocationRecord
    var caseFile: CaseFile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                Section("Lugar") {
                    LabeledContent("Nombre", value: location.name)
                    if !location.details.isEmpty {
                        Text(location.details)
                    }
                    LabeledContent("Fuente", value: location.source.isEmpty ? "Sin registrar" : location.source)
                    LabeledContent("Precisión", value: location.precision.displayName)
                }

                Section("Zona general (compartible)") {
                    TextField("Zona que sí podría mencionarse en público",
                              text: $location.generalZoneName)
                }

                Section("Tipo") {
                    Picker("Tipo", selection: $location.kind) {
                        ForEach(LocationKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                }

                Section("Validación humana") {
                    Picker("Estado", selection: $location.validationState) {
                        ForEach(ValidationState.allCases) { state in
                            Text(state.displayName).tag(state)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
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
        }
    }
}
