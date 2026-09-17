import SwiftUI
import UIKit

// MARK: - Paleta

/// Sistema de color de Plata. Base oscura profunda con acentos coloridos
/// usados con propósito (cada categoría/estado tiene su color), derivados de
/// las formas del onboarding original. La saturación se mantiene alta pero el
/// uso es disciplinado: un acento por contexto, nunca color al azar.
nonisolated enum Palette {
    // Identidad violeta suave (premium/fintech). Neutros con leve matiz violeta:
    // evita blanco/negro puros. Cada rol resuelve claro/oscuro por trait.
    static let bg = dynamic(light: 0xF8F7FB, dark: 0x0E0D12)               // fondo base
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x15131A)          // tarjetas
    static let surfaceElevated = dynamic(light: 0xF1EFF5, dark: 0x1D1A24)  // chips, tracks, botones secundarios
    static let stroke = dynamic(light: 0xE3E0E8, dark: 0x2D2935)           // bordes hairline

    // Tinta (todos pasan AA, incluido el terciario)
    static let ink = dynamic(light: 0x17151C, dark: 0xF7F5FA)          // texto primario
    static let inkSecondary = dynamic(light: 0x5C5666, dark: 0xBBB4C5) // texto secundario
    static let inkTertiary = dynamic(light: 0x706978, dark: 0x9890A3)  // texto terciario

    // Acento de marca: único color "esto es interactivo/importante".
    static let accent = dynamic(light: 0x7050E8, dark: 0xA58BFF)
    // Texto sobre el acento (botones llenos).
    static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x141119)

    /// Construye un Color que resuelve distinto en claro y oscuro (UIKit trait).
    /// `nonisolated` + closure `@Sendable`: UIKit resuelve el color en cualquier
    /// hilo, así que el closure NO debe estar aislado al main actor (si lo está,
    /// Swift 6 dispara un assert de aislamiento y la app crashea al resolver el
    /// color fuera del main thread).
    nonisolated static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(UIColor { @Sendable traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    // MARK: Semánticos (pares claro/oscuro; pasan AA como texto o ícono)
    // Cargan significado: no se confunden con el violeta de marca. Deliberadamente
    // NO dependen solo de verde/rojo — la UI acompaña con flechas/íconos.
    static let positive = dynamic(light: 0x0B7A55, dark: 0x48D6A2) // ingresos, "nos deben", sano
    static let negative = dynamic(light: 0xC03B55, dark: 0xFF7890) // gastos, "debemos", excedido
    static let warning  = dynamic(light: 0x9A5B00, dark: 0xF4B860) // presupuesto cerca del límite
    static let info     = dynamic(light: 0x285FC7, dark: 0x78A9FF) // transferencias, notas neutras

    // Alias heredados → mapeados a los semánticos nuevos (evita romper call sites).
    static let green = positive
    static let pink = negative
    static let amber = warning
    static let sky = info
    static let indigo = accent   // "marca" heredado → acento
    static let purple = accent   // "categorías" heredado → acento (usar CustomPalette para color real)
    static let orange = warning  // acento cálido heredado

    // MARK: Personalización (una sola paleta, 12 colores, mismos en claro/oscuro)
    // Luminancia intermedia: ninguno desaparece en ningún fondo. Ninguno se
    // parece al violeta de marca. El ORDEN separa colores parecidos al rotar.
    static let customPalette: [Color] = CustomPalette.colors

    /// Rueda de colores para asignar a entidades sin color propio.
    static let categoryWheel: [Color] = CustomPalette.colors

    static func categoryColor(for index: Int) -> Color {
        let c = CustomPalette.colors
        return c[((index % c.count) + c.count) % c.count]
    }
}

// MARK: - Paleta de personalización (fuente única de verdad)

/// Los 12 colores que el usuario puede elegir para cuentas, categorías y metas.
/// Mismos hex en claro y oscuro. El orden evita vecinos parecidos al rotar
/// (teal≠cyan, coral≠terracotta, blue≠indigo…).
nonisolated enum CustomPalette {
    struct Swatch: Sendable {
        let name: String
        let hex: String   // "#RRGGBB" — lo que se guarda en la BD
        let value: UInt    // 0xRRGGBB
        var color: Color { Color(hex: value) }
    }

    static let swatches: [Swatch] = [
        Swatch(name: "Teal",       hex: "#2B887A", value: 0x2B887A),
        Swatch(name: "Coral",      hex: "#C45E52", value: 0xC45E52),
        Swatch(name: "Blue",       hex: "#3977B8", value: 0x3977B8),
        Swatch(name: "Amber",      hex: "#A96B18", value: 0xA96B18),
        Swatch(name: "Rose",       hex: "#B95072", value: 0xB95072),
        Swatch(name: "Green",      hex: "#3B815C", value: 0x3B815C),
        Swatch(name: "Sky",        hex: "#3E83A3", value: 0x3E83A3),
        Swatch(name: "Terracotta", hex: "#A9664D", value: 0xA9664D),
        Swatch(name: "Indigo",     hex: "#5369B2", value: 0x5369B2),
        Swatch(name: "Olive",      hex: "#79873C", value: 0x79873C),
        Swatch(name: "Plum",       hex: "#875989", value: 0x875989),
        Swatch(name: "Cyan",       hex: "#2C7F8D", value: 0x2C7F8D),
    ]

    static let colors: [Color] = swatches.map(\.color)
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
    nonisolated init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
