import Foundation

// Respuestas del cuestionario de onboarding. Como el cuestionario ocurre ANTES
// de crear la cuenta (el usuario aún no tiene perfil), se guardan localmente en
// UserDefaults y se suben al perfil (columna profiles.onboarding jsonb) justo
// después de registrarse/iniciar sesión.

struct OnboardingSurvey: Codable, Equatable {
    var manejo: String?      // cómo llevan la plata hoy
    var reto: String?        // qué es lo que más los enreda
    var objetivos: [String]  // para qué quieren usar Plata (multi)
    var pareja: String?      // ¿ya están los dos?

    init(manejo: String? = nil, reto: String? = nil, objetivos: [String] = [], pareja: String? = nil) {
        self.manejo = manejo
        self.reto = reto
        self.objetivos = objetivos
        self.pareja = pareja
    }
}

enum OnboardingSurveyStore {
    private static let key = "onboarding_survey_pending"

    /// Guarda las respuestas localmente hasta poder subirlas al perfil.
    static func savePending(_ survey: OnboardingSurvey) {
        if let data = try? JSONEncoder().encode(survey) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Lee las respuestas pendientes de subir (si las hay).
    static func loadPending() -> OnboardingSurvey? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(OnboardingSurvey.self, from: data)
    }

    /// Limpia las respuestas una vez subidas al perfil.
    static func clearPending() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
