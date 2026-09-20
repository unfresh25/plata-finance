import SwiftUI
import LocalAuthentication

// Bloqueo con Face ID / Touch ID. Opcional (toggle en Ajustes, persistido en
// UserDefaults). Cuando está activo, al abrir la app o volver de fondo se exige
// autenticación biométrica antes de mostrar el contenido.

@MainActor
@Observable
final class AppLock {
    static let shared = AppLock()

    private let key = "app_lock_enabled"

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: key) }
    }
    /// true = contenido tapado hasta autenticar.
    var locked: Bool

    private init() {
        let on = UserDefaults.standard.bool(forKey: key)
        isEnabled = on
        locked = on   // arranca bloqueado si estaba activo
    }

    /// ¿Hay biometría disponible en el device?
    var biometricsAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Al entrar a fondo, si el bloqueo está activo, marca para exigir auth al volver.
    func lockIfEnabled() {
        if isEnabled { locked = true }
    }

    /// Pide Face ID/Touch ID (con fallback a passcode del device).
    func authenticate() async {
        guard locked else { return }
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Usar código"
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication,
                                                  localizedReason: "Desbloquea Plata")
            if ok { locked = false }
        } catch {
            // Falló/canceló: sigue bloqueado; el overlay ofrece reintentar.
        }
    }
}
