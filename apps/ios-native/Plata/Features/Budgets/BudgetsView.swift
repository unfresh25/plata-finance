import SwiftUI

// Presupuestos por categoría. Cada presupuesto muestra la categoría, cuánto se
// ha gastado en el periodo vigente y una barra de progreso cuyo color avisa del
// riesgo: verde (holgado), ámbar (cerca del límite), rosa (al tope / excedido).

struct BudgetsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Space.m) {
                if app.budgets.isEmpty {
                    BudgetsEmptyState()
                        .padding(.top, Space.xxxl)
                } else {
                    SectionLabel(text: "Presupuestos del mes")
                        .padding(.horizontal, Space.xs)
                        .padding(.top, Space.s)

                    ForEach(Array(app.budgets.enumerated()), id: \.element.id) { index, budget in
                        BudgetRowCard(budget: budget, index: index)
                    }
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxxl)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Presupuestos")
    }
}

// MARK: - Fila de presupuesto

private struct BudgetRowCard: View {
    @Environment(AppState.self) private var app
    let budget: Budget
    let index: Int

    private var category: Category? { app.category(for: budget.categoryId) }

    private var spent: Double { BudgetMath.spent(for: budget, in: app.transactions) }

    private var ratio: Double { budget.amount > 0 ? spent / budget.amount : 0 }

    private var remaining: Double { budget.amount - spent }

    private var barColor: Color { BudgetMath.color(for: ratio) }

    private var tint: Color {
        BudgetPalette.color(hex: category?.color, fallbackIndex: index)
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: Space.m) {
                    CategoryIcon(
                        systemName: BudgetPalette.symbol(for: category),
                        color: tint,
                        size: 40
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category?.name ?? "Sin categoría")
                            .font(Typo.headline)
                            .foregroundStyle(Palette.ink)
                        Text(budget.period == .weekly ? "Semanal" : "Mensual")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        AmountText(amount: spent, currency: app.currency, font: Typo.amount)
                        Text("de \(CurrencyFormatter.compact(budget.amount))")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkTertiary)
                            .monospacedDigit()
                    }
                }

                BudgetProgressBar(ratio: ratio, color: barColor)

                HStack {
                    Text("\(Int((ratio * 100).rounded())) % usado")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .monospacedDigit()
                    Spacer()
                    Text(remaining >= 0
                         ? "Quedan \(CurrencyFormatter.string(remaining, currency: app.currency))"
                         : "Excedido \(CurrencyFormatter.string(-remaining, currency: app.currency))")
                        .font(Typo.caption)
                        .foregroundStyle(remaining >= 0 ? Palette.inkSecondary : Palette.negative)
                        .monospacedDigit()
                }
            }
        }
    }
}

// MARK: - Barra de progreso

private struct BudgetProgressBar: View {
    var ratio: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.surfaceElevated)
                Capsule()
                    .fill(color)
                    .frame(width: max(6, geo.size.width * min(1, max(0, ratio))))
                    .animation(Motion.value, value: ratio)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Estado vacío

private struct BudgetsEmptyState: View {
    var body: some View {
        VStack(spacing: Space.m) {
            CategoryIcon(systemName: "chart.pie.fill", color: Palette.amber, size: 64)
            Text("Aún no hay presupuestos")
                .font(Typo.title)
                .foregroundStyle(Palette.ink)
            Text("Crea un presupuesto por categoría para cuidar el gasto del mes en pareja.")
                .font(Typo.body)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cálculo de gasto y color de riesgo

enum BudgetMath {
    /// Gasto acumulado en la categoría del presupuesto durante el periodo vigente
    /// (mes en curso para mensual, semana en curso para semanal).
    static func spent(for budget: Budget, in transactions: [Transaction]) -> Double {
        let prefix = periodPrefix(for: budget.period)
        return transactions
            .filter { tx in
                tx.type == .expense
                && tx.categoryId == budget.categoryId
                && matches(date: tx.date, period: budget.period, prefix: prefix)
            }
            .reduce(0) { $0 + $1.amount }
    }

    /// Color de la barra según el % consumido: <70 % verde, <90 % ámbar, >=90 % rosa.
    static func color(for ratio: Double) -> Color {
        switch ratio {
        case ..<0.7: return Palette.green
        case ..<0.9: return Palette.amber
        default: return Palette.pink
        }
    }

    // Para mensual comparamos YYYY-MM; para semanal comparamos por semana ISO.
    private static func periodPrefix(for period: BudgetPeriod) -> String {
        String(ISO8601DateFormatter().string(from: Date()).prefix(period == .weekly ? 10 : 7))
    }

    private static func matches(date: String, period: BudgetPeriod, prefix: String) -> Bool {
        switch period {
        case .monthly:
            return date.hasPrefix(prefix) // YYYY-MM
        case .weekly:
            return sameWeek(dateString: date)
        }
    }

    private static func sameWeek(dateString: String) -> Bool {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let plain = String(dateString.prefix(10))
        guard let date = iso.date(from: plain) else { return false }
        let cal = Calendar(identifier: .iso8601)
        return cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

// MARK: - Color / símbolo de categoría (compartido con la feature)

enum BudgetPalette {
    /// Parsea un color hex "#RRGGBB" o "0xRRGGBB"; si falla usa la rueda por índice.
    static func color(hex: String?, fallbackIndex: Int) -> Color {
        if let value = parse(hex) { return value }
        return Palette.categoryColor(for: fallbackIndex)
    }

    static func parse(_ hex: String?) -> Color? {
        guard var s = hex?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s.removeFirst(2) }
        guard s.count == 6, let value = UInt(s, radix: 16) else { return nil }
        return Color(hex: value)
    }

    /// Mapea la categoría a un SF Symbol. Usa su `icon` si ya es un SF válido,
    /// si no traduce nombres comunes en español, y finalmente cae a un default.
    static func symbol(for category: Category?) -> String {
        guard let category else { return "circle.grid.2x2.fill" }
        if category.icon.contains(".") { return category.icon } // parece SF Symbol
        return symbol(forName: category.name)
    }

    static func symbol(forName name: String) -> String {
        let n = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        switch true {
        case n.contains("aliment"), n.contains("comida"), n.contains("mercado"): return "fork.knife"
        case n.contains("transp"), n.contains("carro"), n.contains("auto"): return "car.fill"
        case n.contains("vivienda"), n.contains("casa"), n.contains("arriendo"), n.contains("hogar"): return "house.fill"
        case n.contains("salud"), n.contains("medic"): return "heart.fill"
        case n.contains("entreten"), n.contains("ocio"): return "tv.fill"
        case n.contains("ropa"): return "tshirt.fill"
        case n.contains("educ"), n.contains("estudio"): return "book.fill"
        case n.contains("salario"), n.contains("sueldo"): return "dollarsign.circle.fill"
        case n.contains("ahorro"): return "banknote.fill"
        case n.contains("compra"), n.contains("shopping"): return "bag.fill"
        default: return "circle.grid.2x2.fill"
        }
    }
}
