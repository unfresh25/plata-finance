import AppIntents

// Intents COMPARTIDOS entre la app y el widget (target membership: ambos).
// Abren la app en la acción correspondiente. La app observa ShortcutRouter para
// ejecutar la acción; el widget los invoca con Button(intent:).

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

// Para el atajo de Apple Pay: el usuario crea una Automatización de Atajos con el
// disparador "Transacción" (Wallet), y le pasa el monto y el comercio a este
// intent. Abre la app con el gasto precargado para confirmar/guardar.
struct CapturarPagoIntent: AppIntent {
    static let title: LocalizedStringResource = "Capturar pago en Plata"
    static let description = IntentDescription("Registra un pago de Apple Pay / Wallet como gasto.")
    static let openAppWhenRun = true

    @Parameter(title: "Monto")
    var amount: Double

    @Parameter(title: "Comercio")
    var merchant: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        ShortcutRouter.shared.pending = .capturePayment(amount: amount, merchant: merchant ?? "")
        return .result()
    }
}
