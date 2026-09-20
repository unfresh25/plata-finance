import Foundation

// Exporta movimientos a un archivo CSV temporal, para compartir vía ShareLink.

enum CSVExporter {
    static func transactionsCSV(_ txs: [Transaction], app: AppState) -> URL? {
        var rows = ["Fecha,Tipo,Monto,Moneda,Categoría,Cuenta,Descripción,División"]
        let cur = app.currency
        func esc(_ s: String) -> String {
            s.contains(",") || s.contains("\"") || s.contains("\n")
                ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                : s
        }
        for t in txs.sorted(by: { $0.date > $1.date }) {
            let cat = app.category(for: t.categoryId)?.name ?? ""
            let acc = app.accounts.first { $0.id == t.accountId }?.name ?? ""
            let split = t.type == .expense ? t.splitMode.label : ""
            let cells = [
                String(t.date.prefix(10)),
                t.type.label,
                String(format: "%.2f", t.amount),
                cur,
                cat,
                acc,
                t.description ?? "",
                split,
            ].map(esc)
            rows.append(cells.joined(separator: ","))
        }
        let csv = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plata-movimientos.csv")
        do {
            try csv.data(using: .utf8)?.write(to: url)
            return url
        } catch { return nil }
    }
}
