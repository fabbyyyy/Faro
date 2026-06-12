//
//  Badges.swift
//  Faro
//
//  Insignias de estado. Regla de accesibilidad: el estado siempre
//  se comunica con texto e ícono, nunca solo con color.
//

import SwiftUI

/// Insignia de sensibilidad de una evidencia.
struct SensitivityBadge: View {
    let level: SensitivityLevel

    var body: some View {
        Label(level.displayName, systemImage: level.symbolName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(FaroTheme.color(for: level).opacity(0.14))
            .foregroundStyle(FaroTheme.color(for: level))
            .clipShape(Capsule())
            .accessibilityLabel(level.accessibilityDescription)
    }
}

/// Insignia de estado de validación humana.
struct ValidationBadge: View {
    let state: ValidationState

    var body: some View {
        Label(state.displayName, systemImage: state.symbolName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(FaroTheme.color(for: state).opacity(0.14))
            .foregroundStyle(FaroTheme.color(for: state))
            .clipShape(Capsule())
            .accessibilityLabel(state.accessibilityDescription)
    }
}

/// Marca explícita de contenido sugerido por IA pendiente de revisión.
struct AISuggestionBadge: View {
    var body: some View {
        Label("Sugerido por IA · requiere revisión", systemImage: "sparkles")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(FaroTheme.amber.opacity(0.14))
            .foregroundStyle(FaroTheme.amber)
            .clipShape(Capsule())
            .accessibilityLabel("Contenido sugerido por inteligencia artificial, requiere revisión humana")
    }
}

/// Insignia de nivel de confianza.
struct ConfidenceBadge: View {
    let level: ConfidenceLevel

    var body: some View {
        Text(level.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(FaroTheme.secondaryText.opacity(0.12))
            .foregroundStyle(FaroTheme.secondaryText)
            .clipShape(Capsule())
    }
}
