//
//  TrustContactCard.swift
//  Faro
//
//  Tarjeta de contacto de la red de confianza, con rol y permisos visibles.
//

import SwiftUI

struct TrustContactCard: View {
    let contact: TrustedContact

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: contact.symbolName)
                .font(.system(size: 20)) // Tamaño fijo: el ícono decorativo no debe desbordar su recuadro con texto grande.
                .foregroundStyle(FaroTheme.night)
                .frame(width: 40, height: 40)
                .background(FaroTheme.night.opacity(0.08))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.headline)
                if !contact.relationship.isEmpty {
                    Text(contact.relationship)
                        .font(.subheadline)
                        .foregroundStyle(FaroTheme.secondaryText)
                }
                Text(contact.role.displayName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(FaroTheme.night.opacity(0.08))
                    .foregroundStyle(FaroTheme.night)
                    .clipShape(Capsule())
                if !contact.phone.isEmpty {
                    Text(contact.phone)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(FaroTheme.secondaryText)
                }
            }
            Spacer()
        }
        .faroCard()
        .accessibilityElement(children: .combine)
    }
}
