import SwiftUI
import Observation

/// Preferencia de tema del usuario, persistida en UserDefaults. La app aplica
/// `resolvedColorScheme` con `.preferredColorScheme`; los colores de Palette son
/// dinámicos, así que responden automáticamente.
enum ThemePreference: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Automático"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }

    var sfSymbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
@MainActor
final class ThemeManager {
    private let key = "theme_preference"

    var preference: ThemePreference {
        didSet { UserDefaults.standard.set(preference.rawValue, forKey: key) }
    }

    init() {
        // Override de previsualización: -theme light|dark.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-theme"), i + 1 < args.count,
           let forced = ThemePreference(rawValue: args[i + 1]) {
            preference = forced
            return
        }
        let raw = UserDefaults.standard.string(forKey: "theme_preference") ?? ThemePreference.dark.rawValue
        preference = ThemePreference(rawValue: raw) ?? .dark
    }

    var colorScheme: ColorScheme? { preference.colorScheme }
}
