import Foundation
import Realtime

// Suscripción en tiempo real a los cambios del hogar (Supabase Realtime sobre
// websockets). Cuando cambian transactions/accounts/goals/budgets del hogar,
// dispara un refresh de AppState. Reemplaza el polling.

@MainActor
final class RealtimeService {
    private var client: RealtimeClientV2?
    private var channel: RealtimeChannelV2?
    private var tasks: [Task<Void, Never>] = []

    /// Conecta y se suscribe a los cambios del hogar dado. Idempotente.
    func start(householdId: String, accessToken: String, onChange: @escaping () -> Void) {
        stop()
        let options = RealtimeClientOptions(
            headers: ["apikey": SupabaseConfig.anonKey],
            accessToken: { accessToken }
        )
        let url = SupabaseConfig.url.appendingPathComponent("realtime/v1")
        let client = RealtimeClientV2(url: url, options: options)
        self.client = client

        let channel = client.channel("household:\(householdId)")
        self.channel = channel

        // Un stream por tabla; cualquier cambio (INSERT/UPDATE/DELETE) del hogar
        // dispara onChange en el main actor.
        let tables = ["transactions", "accounts", "savings_goals", "budgets"]
        for t in tables {
            let stream = channel.postgresChange(AnyAction.self, schema: "public", table: t,
                                                filter: "household_id=eq.\(householdId)")
            tasks.append(Task { @MainActor in
                for await _ in stream { onChange() }
            })
        }
        tasks.append(Task { await channel.subscribe() })
    }

    func stop() {
        tasks.forEach { $0.cancel() }; tasks = []
        if let channel { Task { await channel.unsubscribe() } }
        channel = nil
        client = nil
    }
}
