import SwiftUI

// Insight contextual del coach IA: una frase que liga el gasto reciente con las
// metas/presupuestos. Se pide al abrir el Dashboard; se oculta si falla o vacío.

@Observable
@MainActor
final class CoachModel {
    private(set) var insight: String?
    private var asked = false

    func load(app: AppState) async {
        guard !asked else { return }
        asked = true
        // Solo tiene sentido con algo de historial y alguna meta/presupuesto.
        guard app.transactions.count >= 5, (!app.goals.isEmpty || !app.budgets.isEmpty) else { return }
        do {
            let url = SupabaseConfig.apiURL.appendingPathComponent("coach/insight")
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(SupabaseClient.shared.accessToken ?? "")", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONEncoder().encode(Body(context: app.financeSummaryForChat(), currency: app.currency))
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return }
            let text = try JSONDecoder().decode(Wire.self, from: data).insight
            insight = text.isEmpty ? nil : text
        } catch { insight = nil }
    }

    private struct Body: Encodable { let context: String; let currency: String }
    private struct Wire: Decodable { let insight: String }
}

struct CoachInsightCard: View {
    @Environment(AppState.self) private var app
    @State private var model = CoachModel()

    var body: some View {
        Group {
            if let insight = model.insight {
                HStack(alignment: .top, spacing: Space.s) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.accent)
                    Text(insight)
                        .font(Typo.subhead).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.accent.opacity(0.2), lineWidth: 1))
            }
        }
        .task { await model.load(app: app) }
    }
}
