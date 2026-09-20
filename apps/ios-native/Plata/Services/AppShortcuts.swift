import AppIntents
import SwiftUI

// Siri Shortcuts / App Intents: acciones que el usuario puede invocar por voz
// ("Oye Siri, registrar gasto en Plata") o desde Spotlight/atajos. No requieren
// configuración de servidor; solo el framework AppIntents.
//
// El intent no puede tocar la UI directamente, así que publica una "acción
// pendiente" en un singleton que MainTabView observa y ejecuta al abrir.

@MainActor
final class ShortcutRouter: ObservableObject {
    static let shared = ShortcutRouter()
    @Published var pending: Action?

    enum Action { case dictar, chat }
}

struct RegistrarGastoIntent: AppIntent {
    static let title: LocalizedStringResource = "Registrar un gasto"
    static let description = IntentDescription("Abre Plata para dictar un movimiento por voz.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ShortcutRouter.shared.pending = .dictar
        return .result()
    }
}

struct PreguntarPlataIntent: AppIntent {
    static let title: LocalizedStringResource = "Preguntarle a Plata"
    static let description = IntentDescription("Abre el asistente de finanzas de Plata.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ShortcutRouter.shared.pending = .chat
        return .result()
    }
}

struct PlataShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RegistrarGastoIntent(),
            phrases: [
                "Registrar un gasto en \(.applicationName)",
                "Anota un gasto en \(.applicationName)",
                "Nuevo movimiento en \(.applicationName)",
            ],
            shortTitle: "Registrar gasto",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: PreguntarPlataIntent(),
            phrases: [
                "Pregúntale a \(.applicationName)",
                "Abre el asistente de \(.applicationName)",
            ],
            shortTitle: "Preguntar a Plata",
            systemImageName: "sparkles"
        )
    }
}
