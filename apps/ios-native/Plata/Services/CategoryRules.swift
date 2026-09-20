import Foundation

// Reglas de auto-categorización: si la descripción de un gasto contiene una
// palabra clave, se sugiere una categoría. Se guardan localmente (UserDefaults)
// y se aprenden solas: al guardar un gasto con descripción + categoría, se
// registra la regla keyword→categoría para la próxima vez.

struct CategoryRule: Codable, Identifiable, Hashable {
    var id = UUID()
    var keyword: String       // en minúsculas
    var categoryId: String
}

@MainActor
enum CategoryRules {
    private static let key = "category_rules_v1"

    static func all() -> [CategoryRule] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let rules = try? JSONDecoder().decode([CategoryRule].self, from: data) else { return [] }
        return rules
    }

    private static func save(_ rules: [CategoryRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Categoría sugerida para una descripción (primera regla cuyo keyword aparece).
    static func suggest(for description: String) -> String? {
        let d = description.lowercased()
        guard !d.isEmpty else { return nil }
        return all().first { !$0.keyword.isEmpty && d.contains($0.keyword) }?.categoryId
    }

    /// Aprende una regla del primer término significativo de la descripción.
    static func learn(description: String, categoryId: String) {
        let d = description.lowercased().trimmingCharacters(in: .whitespaces)
        guard let word = d.split(separator: " ").first.map(String.init), word.count >= 3 else { return }
        var rules = all()
        if let idx = rules.firstIndex(where: { $0.keyword == word }) {
            rules[idx].categoryId = categoryId   // actualiza
        } else {
            rules.append(CategoryRule(keyword: word, categoryId: categoryId))
        }
        save(rules)
    }

    static func remove(_ rule: CategoryRule) {
        save(all().filter { $0.id != rule.id })
    }
}
