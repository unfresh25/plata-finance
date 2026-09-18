import Foundation

// Resumen financiero del hogar en texto plano, para dárselo al chat IA como
// contexto (enfoque "resumen precomputado"). Es la única fuente de datos que ve
// el asistente, así que se incluye lo relevante de forma compacta y legible.

extension AppState {
    /// Construye el resumen que se envía al backend de chat como `context`.
    func financeSummaryForChat() -> String {
        let cur = currency
        func money(_ v: Double) -> String {
            CurrencyFormatter.string(v, currency: cur)
        }

        var lines: [String] = []

        // Encabezado.
        if let hh = household?.name { lines.append("Hogar: \(hh)") }
        lines.append("Moneda: \(cur)")
        lines.append("Fecha de hoy: \(Self.todayISO())")
        lines.append("")

        // Balance y mes en curso.
        lines.append("BALANCE TOTAL: \(money(totalBalance))")
        lines.append("Este mes — ingresos: \(money(monthIncome)), gastos: \(money(monthExpense))")
        lines.append("")

        // Cuentas.
        lines.append("CUENTAS:")
        if accounts.isEmpty {
            lines.append("- (sin cuentas)")
        } else {
            for a in accounts {
                lines.append("- \(a.name) (\(a.type.label)): \(money(a.balance))")
            }
        }
        lines.append("")

        // Gasto del mes por categoría (top, de mayor a menor).
        let byCat = expenseByCategoryThisMonth()
        if !byCat.isEmpty {
            lines.append("GASTO DEL MES POR CATEGORÍA:")
            for (name, total) in byCat.prefix(12) {
                lines.append("- \(name): \(money(total))")
            }
            lines.append("")
        }

        // Presupuestos.
        if !budgets.isEmpty {
            lines.append("PRESUPUESTOS:")
            for b in budgets {
                let cat = category(for: b.categoryId)?.name ?? "General"
                lines.append("- \(cat): límite \(money(b.amount))")
            }
            lines.append("")
        }

        // Deudas.
        if !debts.isEmpty {
            lines.append("DEUDAS:")
            for d in debts {
                let quien = d.direction == .owedToUs ? "me debe" : "le debo a"
                let detalle = d.description?.isEmpty == false ? " (\(d.description!))" : ""
                lines.append("- \(quien) \(d.personName)\(detalle): total \(money(d.amount)), pagado \(money(d.amountPaid)), falta \(money(d.remaining))")
            }
            lines.append("")
        }

        // Metas de ahorro.
        if !goals.isEmpty {
            lines.append("METAS DE AHORRO:")
            for g in goals {
                let pct = g.targetAmount > 0 ? Int((g.currentAmount / g.targetAmount) * 100) : 0
                lines.append("- \(g.name): \(money(g.currentAmount)) de \(money(g.targetAmount)) (\(pct)%)")
            }
            lines.append("")
        }

        // Últimos movimientos.
        let recent = transactions
            .sorted { $0.date > $1.date }
            .prefix(15)
        if !recent.isEmpty {
            lines.append("ÚLTIMOS MOVIMIENTOS:")
            for t in recent {
                let cat = category(for: t.categoryId)?.name ?? "—"
                let sign = t.type == .income ? "+" : (t.type == .expense ? "-" : "")
                let desc = t.description?.isEmpty == false ? t.description! : cat
                lines.append("- \(String(t.date.prefix(10))) \(sign)\(money(t.amount)) · \(cat) · \(desc)")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Gasto del mes en curso agrupado por categoría, de mayor a menor.
    private func expenseByCategoryThisMonth() -> [(String, Double)] {
        let prefix = String(Self.todayISO().prefix(7))   // YYYY-MM
        var totals: [String: Double] = [:]
        for t in transactions where t.type == .expense && t.date.hasPrefix(prefix) {
            let name = category(for: t.categoryId)?.name ?? "Sin categoría"
            totals[name, default: 0] += t.amount
        }
        return totals.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private static func todayISO() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
