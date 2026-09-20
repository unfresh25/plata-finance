import SwiftUI

// Tarjeta de "Resumen de la semana" (IA) en el Dashboard. Al aparecer intenta
// leer el resumen cacheado (GET /weekly/summary); si no existe, lo genera una vez
// (POST) con el resumen semanal que arma la app. Se oculta si falla o no hay datos.

@Observable
@MainActor
final class WeeklySummaryModel {
    private(set) var text: String?
    private(set) var loading = false

    func load(app: AppState) async {
        guard text == nil, !loading else { return }
        loading = true
        defer { loading = false }
        let (start, end) = Self.currentWeek()
        do {
            if let cached = try await get(weekStart: start) {
                text = cached
                return
            }
            let context = app.financeSummaryForWeek(weekStart: start, weekEnd: end)
            text = try await post(weekStart: start, context: context, currency: app.currency)
        } catch {
            text = nil   // silencioso: la tarjeta simplemente no se muestra
        }
    }

    // MARK: Red

    private func get(weekStart: String) async throws -> String? {
        let url = SupabaseConfig.apiURL.appendingPathComponent("weekly/summary")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "week_start", value: weekStart)]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(SupabaseClient.shared.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        // El backend devuelve null (sin cache) o el objeto.
        if let obj = try? JSONDecoder().decode(Wire.self, from: data) { return obj.summary_text }
        return nil
    }

    private func post(weekStart: String, context: String, currency: String) async throws -> String {
        let url = SupabaseConfig.apiURL.appendingPathComponent("weekly/summary")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(SupabaseClient.shared.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(PostBody(week_start: weekStart, context: context, currency: currency))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Wire.self, from: data).summary_text
    }

    private struct Wire: Decodable { let summary_text: String }
    private struct PostBody: Encodable { let week_start: String; let context: String; let currency: String }

    /// Lunes y domingo (ISO) de la semana actual, en YYYY-MM-DD.
    static func currentWeek() -> (String, String) {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let now = Date()
        let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? now
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return (f.string(from: start), f.string(from: end))
    }
}

struct WeeklySummaryCard: View {
    @Environment(AppState.self) private var app
    @State private var model = WeeklySummaryModel()

    var body: some View {
        Group {
            if let text = model.text {
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack(spacing: Space.xs) {
                        Image("GenerateIcon").renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 15, height: 15).foregroundStyle(Palette.accent)
                        Text("RESUMEN DE LA SEMANA")
                            .font(Typo.overline).tracking(0.8).foregroundStyle(Palette.inkTertiary)
                    }
                    Text(text)
                        .font(Typo.subhead).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
            }
        }
        .task { await model.load(app: app) }
    }
}
