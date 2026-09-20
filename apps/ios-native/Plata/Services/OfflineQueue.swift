import Foundation

// Cola de ESCRITURA offline: si crear un movimiento falla por red, se guarda en
// disco y se reintenta al volver la conexión (en el próximo refresh/arranque).
// Alcance: alta de transacciones (el caso más frecuente sin señal). No cubre
// ediciones/borrados offline — esos siguen requiriendo red.

struct QueuedTransaction: Codable, Identifiable {
    var id = UUID()
    let accountId: String
    let amount: Double
    let type: String
    let categoryId: String?
    let description: String?
    let date: String
    let splitMode: String
    let householdId: String
    let userId: String

    var asPayload: NewTransaction {
        NewTransaction(accountId: accountId, amount: amount,
                       type: TransactionType(rawValue: type) ?? .expense,
                       categoryId: categoryId, description: description, date: date,
                       splitMode: SplitMode(rawValue: splitMode) ?? .shared)
    }
}

@MainActor
enum OfflineQueue {
    private static let key = "offline_tx_queue_v1"

    static func all() -> [QueuedTransaction] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let q = try? JSONDecoder().decode([QueuedTransaction].self, from: data) else { return [] }
        return q
    }

    private static func save(_ q: [QueuedTransaction]) {
        if let data = try? JSONEncoder().encode(q) { UserDefaults.standard.set(data, forKey: key) }
    }

    static func enqueue(_ tx: QueuedTransaction) {
        var q = all(); q.append(tx); save(q)
    }

    static var count: Int { all().count }

    /// Reintenta enviar todo lo encolado. Quita las que logran subir.
    static func flush(repo: Repository) async {
        var q = all()
        guard !q.isEmpty else { return }
        var remaining: [QueuedTransaction] = []
        for item in q {
            do {
                try await repo.addTransaction(item.asPayload, householdId: item.householdId, userId: item.userId)
            } catch {
                remaining.append(item)   // sigue sin poder; se queda para el próximo intento
            }
        }
        q = remaining
        save(q)
    }
}
