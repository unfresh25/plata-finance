import AppIntents

// AppShortcutsProvider: registra las frases de Siri/Spotlight para los intents
// compartidos (Shared/QuickIntents.swift). Vive solo en el target de la app.

struct PlataShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RegistrarGastoIntent(),
            phrases: [
                // App Shortcuts EXIGE \(.applicationName) en cada frase.
                "\(.applicationName) registrar gasto",
                "Registrar gasto en \(.applicationName)",
                "Registrar un gasto en \(.applicationName)",
                "Anotar un gasto en \(.applicationName)",
                "Nuevo movimiento en \(.applicationName)",
            ],
            shortTitle: "Registrar gasto",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: PreguntarPlataIntent(),
            phrases: [
                "\(.applicationName) asistente",
                "Preguntar a \(.applicationName)",
                "Pregúntale a \(.applicationName)",
                "Abrir el asistente de \(.applicationName)",
            ],
            shortTitle: "Preguntar",
            systemImageName: "sparkles"
        )
    }
}
