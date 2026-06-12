//
//  FaroTheme.swift
//  Faro
//
//  Sistema de diseño central: calma en una emergencia, no una alarma más.
//  Paleta sobria (azul noche, blanco cálido, gris suave, ámbar de atención).
//  El rojo se reserva para acciones destructivas o alertas graves.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum FaroTheme {

    // MARK: - Color

    /// Azul noche: identidad y elementos primarios.
    static let night = Color(light: Color(red: 0.10, green: 0.16, blue: 0.28),
                             dark: Color(red: 0.62, green: 0.72, blue: 0.88))

    /// Fondo: off-white con un velo azul en claro; azul casi negro (#0B131F) en oscuro.
    static let background = Color(light: Color(red: 0.96, green: 0.97, blue: 0.99),
                                  dark: Color(red: 0.043, green: 0.075, blue: 0.122))

    /// Superficie de tarjetas: blanco puro en claro; azul del icono (#152238) en oscuro.
    static let surface = Color(light: .white,
                               dark: Color(red: 0.082, green: 0.133, blue: 0.220))

    /// Gris medio (#6C757D) para texto secundario; gris claro en oscuro.
    static let secondaryText = Color(light: Color(red: 0.424, green: 0.459, blue: 0.490),
                                     dark: Color(red: 0.78, green: 0.80, blue: 0.84))

    /// Ámbar: atención, pendientes, datos por revisar. No es alarma.
    static let amber = Color(light: Color(red: 0.80, green: 0.55, blue: 0.13),
                             dark: Color(red: 0.95, green: 0.72, blue: 0.33))

    /// Verde sobrio para confirmados.
    static let confirmedGreen = Color(light: Color(red: 0.18, green: 0.49, blue: 0.34),
                                      dark: Color(red: 0.45, green: 0.75, blue: 0.58))

    /// Rojo: solo destructivo o alerta grave.
    static let destructive = Color(light: Color(red: 0.72, green: 0.20, blue: 0.18),
                                   dark: Color(red: 0.90, green: 0.45, blue: 0.42))

    /// Color asociado a un estado de validación.
    /// Importante: el color nunca es el único canal; siempre hay texto e ícono.
    static func color(for state: ValidationState) -> Color {
        switch state {
        case .confirmed:     return confirmedGreen
        case .pending:       return amber
        case .approximate:   return secondaryText
        case .contradictory: return amber
        case .discarded:     return secondaryText
        }
    }

    static func color(for sensitivity: SensitivityLevel) -> Color {
        switch sensitivity {
        case .publicSafe:  return confirmedGreen
        case .privateInfo: return night
        case .sensitive:   return amber
        case .incomplete:  return secondaryText
        case .urgent:      return amber
        }
    }

    // MARK: - Métricas

    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 10
    static let cardPadding: CGFloat = 18
    static let screenPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24

    // MARK: - Animaciones

    /// Respuesta rápida para botones y tarjetas (press feedback).
    static let springSnappy = Animation.spring(response: 0.25, dampingFraction: 0.72)
    /// Transición fluida para modales y pasos del flujo.
    static let springSmooth  = Animation.spring(response: 0.38, dampingFraction: 0.78)
    /// Entrada de elementos en pantalla.
    static let springEntrance = Animation.spring(response: 0.50, dampingFraction: 0.80)
}

// MARK: - Color adaptable claro/oscuro

extension Color {
    /// Crea un color que se adapta a modo claro y oscuro.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Tarjeta estándar

struct FaroCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(FaroTheme.cardPadding)
            .background(FaroTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: FaroTheme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

extension View {
    /// Tarjeta sobria estándar de FARO.
    func faroCard() -> some View {
        modifier(FaroCardModifier())
    }

    /// Animación de entrada escalonada: opacidad + deslizamiento hacia arriba.
    /// Llama con `appeared` cambiando de false → true dentro de onAppear.
    /// Respeta "Reducir movimiento": en ese caso se omite el deslizamiento
    /// y queda solo un fundido suave de opacidad.
    func faroEntrance(visible: Bool, delay: Double = 0) -> some View {
        modifier(FaroEntranceModifier(visible: visible, delay: delay))
    }
}

// MARK: - Entrada escalonada (accesible)

struct FaroEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let visible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (visible ? 0 : 14))
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.2).delay(delay)
                    : FaroTheme.springEntrance.delay(delay),
                value: visible
            )
    }
}

// MARK: - Estilos de botón

/// Botón principal: grande, claro, accesible en crisis.
struct FaroPrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(FaroTheme.night.opacity(configuration.isPressed ? 0.82 : 1))
            .foregroundStyle(Color(light: .white, dark: Color(red: 0.043, green: 0.075, blue: 0.122)))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(FaroTheme.springSnappy, value: configuration.isPressed)
    }
}

/// Botón secundario con borde suave.
struct FaroSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(FaroTheme.surface.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundStyle(FaroTheme.night)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(FaroTheme.night.opacity(0.25), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(FaroTheme.springSnappy, value: configuration.isPressed)
    }
}

/// Botón silencioso para "Saltar" / "No lo sé todavía": sin culpa, sin peso visual.
struct FaroQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .foregroundStyle(FaroTheme.secondaryText)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(FaroTheme.springSnappy, value: configuration.isPressed)
    }
}

/// Estilo de tarjeta interactiva: escala sutil al presionar.
struct FaroCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(FaroTheme.springSnappy, value: configuration.isPressed)
    }
}

// MARK: - Encabezado de sección

struct FaroSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(FaroTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
