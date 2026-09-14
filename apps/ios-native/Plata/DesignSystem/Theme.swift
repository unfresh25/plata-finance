import SwiftUI

// MARK: - Paleta

/// Sistema de color de Plata. Base oscura profunda con acentos coloridos
/// usados con propósito (cada categoría/estado tiene su color), derivados de
/// las formas del onboarding original. La saturación se mantiene alta pero el
/// uso es disciplinado: un acento por contexto, nunca color al azar.
enum Palette {
    // Fondos (del más profundo al más elevado)
    static let bg = Color(hex: 0x09090B)          // fondo base, casi negro
    static let surface = Color(hex: 0x151518)     // tarjetas
    static let surfaceElevated = Color(hex: 0x1E1E23) // tarjetas sobre tarjetas
    static let stroke = Color(hex: 0x2A2A31)      // bordes hairline

    // Tinta
    static let ink = Color(hex: 0xFAFAFA)         // texto primario
    static let inkSecondary = Color(hex: 0xA1A1AA) // texto secundario
    static let inkTertiary = Color(hex: 0x6B6B74)  // texto terciario / hints

    // Acento primario de marca (índigo del onboarding)
    static let accent = Color(hex: 0x818CF8)

    // Acentos coloridos con propósito (categorías, estados)
    static let green = Color(hex: 0x34D399)   // ingresos, éxito, "safe"
    static let sky = Color(hex: 0x38BDF8)     // información, transferencias
    static let indigo = Color(hex: 0x818CF8)  // marca
    static let purple = Color(hex: 0xC084FC)  // categorías
    static let pink = Color(hex: 0xF43F5E)    // gastos, deuda, "danger"
    static let amber = Color(hex: 0xFDE047)   // presupuesto, "warning"
    static let orange = Color(hex: 0xFB923C)  // acento cálido

    // Semánticos (separados del acento de marca)
    static let positive = green
    static let negative = pink
    static let warning = amber

    /// Rueda de colores para asignar a categorías sin color propio, en orden
    /// de rotación agradable (evita dos vecinos parecidos).
    static let categoryWheel: [Color] = [
        green, sky, indigo, purple, pink, amber, orange,
    ]

    static func categoryColor(for index: Int) -> Color {
        categoryWheel[((index % categoryWheel.count) + categoryWheel.count) % categoryWheel.count]
    }
}

// MARK: - Tipografía

/// Escala tipográfica basada en SF Pro (rounded para cifras, para dar calidez
/// a los números financieros). Un solo eje de tamaños, pesos deliberados.
enum Typo {
    /// Cifra hero (monto gigante en add-transaction / balance del dashboard).
    static func amountHero(_ size: CGFloat = 56) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static let amountLarge = Font.system(size: 34, weight: .bold, design: .rounded)
    static let amountMedium = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let amount = Font.system(size: 17, weight: .semibold, design: .rounded)

    static let titleXL = Font.system(size: 34, weight: .bold)
    static let title = Font.system(size: 22, weight: .bold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let callout = Font.system(size: 15, weight: .medium)
    static let subhead = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 12, weight: .medium)
    static let overline = Font.system(size: 11, weight: .semibold) // labels en mayúsculas
}

// MARK: - Espaciado y radios

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum Radius {
    static let s: CGFloat = 10
    static let m: CGFloat = 16
    static let l: CGFloat = 22
    static let pill: CGFloat = 999
}

// MARK: - Animación (curvas de Emil: ease-out fuerte, springs sutiles)

enum Motion {
    /// Feedback de press: rápido, ease-out.
    static let press = Animation.easeOut(duration: 0.12)
    /// Entrada/salida de UI (sheets, elementos): spring sutil de Apple.
    static let ui = Animation.spring(duration: 0.32, bounce: 0.12)
    /// Transición de valor (contadores, progreso).
    static let value = Animation.easeOut(duration: 0.25)
}

// MARK: - Helpers de color

extension Color {
    /// Init desde hex 0xRRGGBB.
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
