//
//  ChatComponents.swift
//  Faro
//
//  Piezas visuales del chatbot: burbujas sobrias, chips de respuesta
//  rápida y tarjeta de microconfirmación de datos detectados.
//  Conversacional pero serio: esto no es una app casual.
//

import SwiftUI

// MARK: - Burbuja de mensaje

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(message.role == .user
                                     ? Color(light: .white, dark: Color(red: 0.07, green: 0.09, blue: 0.13))
                                     : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))

                if message.kind == .empathy {
                    Text("Sin prisa. Nada se pierde.")
                        .font(.caption2)
                        .foregroundStyle(FaroTheme.secondaryText)
                        .padding(.horizontal, 4)
                }
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? "Tú" : "Asistente"): \(message.text)")
    }

    private var bubbleBackground: some ShapeStyle {
        message.role == .user
            ? AnyShapeStyle(FaroTheme.night)
            : AnyShapeStyle(FaroTheme.surface)
    }
}

// MARK: - Indicador de "pensando"

struct ChatTypingIndicator: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(FaroTheme.secondaryText.opacity(pulse ? 0.7 : 0.25))
                    .frame(width: 7, height: 7)
                    .animation(.easeInOut(duration: 0.7).repeatForever().delay(Double(index) * 0.18),
                               value: pulse)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(FaroTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
        .onAppear { pulse = true }
        .accessibilityLabel("El asistente está procesando")
    }
}

// MARK: - Chip de respuesta rápida

struct QuickReplyChip: View {
    let title: String
    var systemImage: String?
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(minHeight: 44) // Objetivo táctil accesible (mínimo 44 pt).
            .background(prominent ? AnyShapeStyle(FaroTheme.night) : AnyShapeStyle(FaroTheme.night.opacity(0.08)))
            .foregroundStyle(prominent
                             ? Color(light: .white, dark: Color(red: 0.07, green: 0.09, blue: 0.13))
                             : FaroTheme.night)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tarjeta de microconfirmación de datos detectados

/// Muestra los campos extraídos por la IA, formalizados, con su
/// confianza. La familia decide: confirmar, aproximado, editar o descartar.
struct FieldConfirmationCard: View {
    let fields: [DetectedField]
    let onConfirm: () -> Void
    let onApproximate: () -> Void
    let onEdit: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AISuggestionBadge()

            ForEach(fields) { field in
                VStack(alignment: .leading, spacing: 3) {
                    Text(field.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FaroTheme.secondaryText)
                    Text(field.formalValue)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        ConfidenceBadge(level: field.confidence)
                        if field.suggestedValidation == .approximate {
                            Text("Se guardará como aproximado")
                                .font(.caption2)
                                .foregroundStyle(FaroTheme.amber)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FaroTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: FaroTheme.smallCornerRadius, style: .continuous))
                .accessibilityElement(children: .combine)
            }

            // Acciones de validación humana
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    QuickReplyChip(title: "Confirmar", systemImage: "checkmark", prominent: true, action: onConfirm)
                    QuickReplyChip(title: "Marcar como aproximado", systemImage: "circle.dashed", action: onApproximate)
                }
                HStack(spacing: 8) {
                    QuickReplyChip(title: "Editar", systemImage: "pencil", action: onEdit)
                    QuickReplyChip(title: "Descartar", systemImage: "xmark", action: onDiscard)
                }
            }
        }
        .padding(14)
        .background(FaroTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous)
                .strokeBorder(FaroTheme.amber.opacity(0.35), lineWidth: 1)
        )
    }
}
