import SwiftUI

// Aviso de posibles anomalías (duplicados / gastos inusuales) detectadas por IA.
// Escanea los movimientos recientes vía backend /anomalies/scan y muestra un
// banner discreto arriba de la lista. Si no hay nada, no se muestra.

@Observable
@MainActor
final class AnomalyModel {
    private(set) var anomalies: [Anomaly] = []
    private var scanned = false

    struct Anomaly: Decodable, Identifiable, Hashable {
        let id: String
        let type: String
        let reason: String
    }

    func scan(app: AppState) async {
        guard !scanned else { return }
        scanned = true
        let recent = Array(app.transactions.sorted { $0.date > $1.date }.prefix(40))
        guard recent.count >= 3 else { return }
        let wire = recent.map { t in
            TxWire(id: t.id, date: String(t.date.prefix(10)), amount: t.amount,
                   category: app.category(for: t.categoryId)?.name,
                   description: t.description)
        }
        do {
            let url = SupabaseConfig.apiURL.appendingPathComponent("anomalies/scan")
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(SupabaseClient.shared.accessToken ?? "")", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONEncoder().encode(ReqBody(transactions: wire))
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            anomalies = try JSONDecoder().decode(RespBody.self, from: data).anomalies
        } catch { /* silencioso */ }
    }

    func dismiss(_ a: Anomaly) { anomalies.removeAll { $0.id == a.id } }

    private struct TxWire: Encodable {
        let id: String; let date: String; let amount: Double
        let category: String?; let description: String?
    }
    private struct ReqBody: Encodable { let transactions: [TxWire] }
    private struct RespBody: Decodable { let anomalies: [Anomaly] }
}

struct AnomalyBanner: View {
    let anomalies: [AnomalyModel.Anomaly]
    let resolve: (String) -> Transaction?
    var onOpen: (Transaction) -> Void
    var onDismiss: (AnomalyModel.Anomaly) -> Void

    var body: some View {
        if !anomalies.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.amber)
                    Text("REVISA ESTOS MOVIMIENTOS")
                        .font(Typo.overline).tracking(0.8).foregroundStyle(Palette.inkTertiary)
                }
                ForEach(anomalies) { a in
                    Button {
                        if let tx = resolve(a.id) { onOpen(tx) }
                    } label: {
                        HStack(spacing: Space.s) {
                            Text(a.reason)
                                .font(Typo.subhead).foregroundStyle(Palette.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: Space.s)
                            Button { onDismiss(a) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkTertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .pressable()
                }
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.amber.opacity(0.3), lineWidth: 1))
        }
    }
}
