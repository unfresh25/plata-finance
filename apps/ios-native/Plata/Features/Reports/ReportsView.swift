import SwiftUI
import Charts

// Estadísticas — rediseño 2026. Estructura (investigación fintech: Copilot,
// Monarch, Revolut, Cash App…):
//   · Selector de periodo (Semana / Mes / 3M / 6M / Año) con flechas ‹ ›
//   · HERO: gasto del periodo + delta vs. periodo anterior + neto
//   · Donut de gasto por categoría (≤5 + "Otros"), total al centro
//   · División por PAREJA (quién gastó cuánto) — el diferenciador de Plata
//   · Banner de insight (ahorro / categoría que sube)
//   · Lista de categorías con barra semáforo vs. presupuesto
//   · Suscripciones: total mensual comprometido
// Todo se deriva de app.transactions / categories / budgets / members /
// recurringEvents. Diseño flat, sin cards; acento violeta.

struct ReportsView: View {
    @Environment(AppState.self) private var app

    @State private var period: StatsPeriod = .month
    /// Desplazamiento de periodos hacia atrás (0 = actual, 1 = anterior…).
    @State private var offset: Int = 0
    @Namespace private var periodNS

    private var currency: String { app.currency }

    // MARK: Rango del periodo visible

    private var range: DateInterval { StatsCalendar.interval(period, offset: offset) }
    private var prevRange: DateInterval { StatsCalendar.interval(period, offset: offset + 1) }

    private func txs(in interval: DateInterval) -> [Transaction] {
        app.transactions.filter { tx in
            guard let d = StatsCalendar.parse(tx.date) else { return false }
            return interval.contains(d)
        }
    }

    private var periodTxs: [Transaction] { txs(in: range) }
    private var prevTxs: [Transaction] { txs(in: prevRange) }

    // MARK: Agregados

    private func expense(_ list: [Transaction]) -> Double {
        list.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    private func income(_ list: [Transaction]) -> Double {
        list.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var spent: Double { expense(periodTxs) }
    private var earned: Double { income(periodTxs) }
    private var net: Double { earned - spent }
    private var prevSpent: Double { expense(prevTxs) }

    /// Delta de gasto vs. periodo anterior (fracción). Menos gasto = "bueno".
    private var spendDelta: Double? {
        guard prevSpent > 0 else { return nil }
        return (spent - prevSpent) / prevSpent
    }

    /// Tasa de ahorro del periodo: (ingreso − gasto) / ingreso.
    private var savingsRate: Double? {
        guard earned > 0 else { return nil }
        return max(-1, (earned - spent) / earned)
    }

    // Categorías de gasto del periodo, orden desc, con "Otros" agrupado a 5.
    private var categorySlices: [StatsSlice] {
        var totals: [String: Double] = [:]
        for tx in periodTxs where tx.type == .expense {
            let key = tx.categoryId ?? "—"
            totals[key, default: 0] += tx.amount
        }
        let total = totals.values.reduce(0, +)
        guard total > 0 else { return [] }
        let sorted = totals.sorted { $0.value > $1.value }
        var slices: [StatsSlice] = []
        for (i, entry) in sorted.enumerated() {
            if i < 5 {
                let cat = app.category(for: entry.key)
                slices.append(StatsSlice(
                    id: entry.key,
                    name: cat?.name ?? "Otro",
                    slug: cat?.icon,
                    symbol: StatsStyle.symbol(for: cat),
                    color: StatsStyle.color(for: cat, index: i),
                    amount: entry.value,
                    fraction: entry.value / total
                ))
            } else {
                // Agrupa el resto en "Otros".
                if slices.last?.id == "__otros__" {
                    slices[slices.count - 1].amount += entry.value
                    slices[slices.count - 1].fraction += entry.value / total
                } else {
                    slices.append(StatsSlice(
                        id: "__otros__", name: "Otros", slug: nil,
                        symbol: "ellipsis", color: Palette.inkTertiary,
                        amount: entry.value, fraction: entry.value / total
                    ))
                }
            }
        }
        return slices
    }

    // Gasto por miembro del hogar (el diferenciador de pareja, usa createdBy).
    private var memberSpend: [StatsMemberSpend] {
        var totals: [String: Double] = [:]
        for tx in periodTxs where tx.type == .expense {
            totals[tx.createdBy, default: 0] += tx.amount
        }
        let total = totals.values.reduce(0, +)
        guard total > 0 else { return [] }
        return totals
            .sorted { $0.value > $1.value }
            .enumerated()
            .map { i, entry in
                let profile = app.member(for: entry.key)
                return StatsMemberSpend(
                    id: entry.key,
                    name: profile?.name ?? "Miembro",
                    avatarUrl: profile?.avatarUrl,
                    amount: entry.value,
                    fraction: entry.value / total,
                    color: StatsStyle.memberColor(i)
                )
            }
    }

    // Presupuestos mensuales con lo gastado en el periodo → estado semáforo.
    private var budgetRows: [StatsBudgetRow] {
        guard period == .month else { return [] }
        return app.budgets
            .filter { $0.period == .monthly }
            .map { budget in
                let spent = periodTxs
                    .filter { $0.type == .expense && $0.categoryId == budget.categoryId }
                    .reduce(0) { $0 + $1.amount }
                let cat = app.category(for: budget.categoryId)
                return StatsBudgetRow(
                    id: budget.id,
                    name: cat?.name ?? "Categoría",
                    slug: cat?.icon,
                    symbol: StatsStyle.symbol(for: cat),
                    color: StatsStyle.color(for: cat, index: 0),
                    spent: spent,
                    limit: budget.amount
                )
            }
            .sorted { $0.ratio > $1.ratio }
    }

    // Total mensual comprometido en suscripciones activas.
    private var subscriptionsMonthly: Double {
        app.recurringEvents
            .filter { $0.isActive }
            .reduce(0) { $0 + $1.amount * $1.frequency.monthlyFactor }
    }

    private var isLoading: Bool {
        app.transactions.isEmpty && app.phase != .ready
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            if isLoading {
                StatsSkeleton()
            } else {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    periodSelector
                    hero
                    if categorySlices.isEmpty {
                        StatsEmpty()
                    } else {
                        donutBlock
                        if let banner = insightBanner { banner }
                        if !memberSpend.isEmpty { memberBlock }
                        categoryBlock
                        if !budgetRows.isEmpty { budgetBlock }
                        if subscriptionsMonthly > 0 { subscriptionsBlock }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxxl)
                .animation(Motion.value, value: period)
                .animation(Motion.value, value: offset)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Estadísticas")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await app.refreshAll() }
    }

    // MARK: - Selector de periodo

    private var periodSelector: some View {
        VStack(spacing: Space.m) {
            // Segmented pills flat; activa = violeta con matchedGeometry.
            HStack(spacing: 0) {
                ForEach(StatsPeriod.allCases) { p in
                    Button {
                        withAnimation(Motion.ui) { period = p; offset = 0 }
                    } label: {
                        Text(p.label)
                            .font(Typo.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(p == period ? Palette.onAccent : Palette.inkSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.s)
                            .background {
                                if p == period {
                                    Capsule().fill(Palette.accent)
                                        .matchedGeometryEffect(id: "periodPill", in: periodNS)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Palette.surfaceElevated, in: Capsule())

            // Rango navegable con flechas.
            HStack {
                navArrow("chevron.left") { offset += 1 }
                Spacer()
                Text(StatsCalendar.label(period, offset: offset))
                    .font(Typo.subhead)
                    .fontWeight(.medium)
                    .foregroundStyle(Palette.inkSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer()
                navArrow("chevron.right", disabled: offset == 0) { if offset > 0 { offset -= 1 } }
            }
            .padding(.horizontal, Space.s)
        }
    }

    private func navArrow(_ system: String, disabled: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Motion.value, action)
        } label: {
            Image(systemName: system)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(disabled ? Palette.inkTertiary.opacity(0.4) : Palette.inkSecondary)
                .frame(width: 32, height: 32)
                .background(Palette.surfaceElevated, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .pressable(scale: 0.9)
    }

    // MARK: - Hero (gasto del periodo)

    private var hero: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("GASTO \(period.heroLabel)")
                .font(Typo.overline)
                .tracking(1.2)
                .foregroundStyle(Palette.inkTertiary)

            Text(CurrencyFormatter.string(spent, currency: currency))
                .font(Typo.amountHero(44))
                .tracking(-1)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())

            HStack(spacing: Space.s) {
                if let delta = spendDelta {
                    // Menos gasto = verde (positivo); más gasto = rojo.
                    let down = delta < 0
                    HStack(spacing: 2) {
                        Image(systemName: down ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(abs(Int((delta * 100).rounded()))) %")
                            .font(Typo.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(down ? Palette.positive : Palette.negative)
                    .padding(.horizontal, Space.s)
                    .padding(.vertical, 3)
                    .background((down ? Palette.positive : Palette.negative).opacity(0.14), in: Capsule())

                    Text("vs. \(period.prevLabel)")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
                Spacer(minLength: 0)
                Text("Neto \(net >= 0 ? "+" : "")\(CurrencyFormatter.string(net, currency: currency))")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(net >= 0 ? Palette.positive : Palette.negative)
            }
        }
    }

    // MARK: - Donut de categorías

    private var donutBlock: some View {
        VStack(spacing: Space.l) {
            ZStack {
                Chart(categorySlices) { slice in
                    SectorMark(
                        angle: .value("Monto", slice.amount),
                        innerRadius: .ratio(0.66),
                        angularInset: 2
                    )
                    .cornerRadius(5)
                    .foregroundStyle(slice.color)
                }
                .frame(height: 200)

                VStack(spacing: 2) {
                    Text("TOTAL")
                        .font(Typo.overline)
                        .tracking(1)
                        .foregroundStyle(Palette.inkTertiary)
                    Text(CurrencyFormatter.string(spent, currency: currency))
                        .font(Typo.amountMedium)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("\(categorySlices.count) categorías")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
                .frame(width: 130)
            }

            // Leyenda de puntos (envuelve).
            FlowLegend(slices: categorySlices)
        }
    }

    // MARK: - División por pareja

    private var memberBlock: some View {
        PlainSection(title: "Quién gastó") {
            VStack(spacing: Space.m) {
                // Barra 100% apilada de los miembros.
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(memberSpend) { m in
                            Capsule()
                                .fill(m.color)
                                .frame(width: max(4, geo.size.width * m.fraction))
                        }
                    }
                }
                .frame(height: 10)

                ForEach(memberSpend) { m in
                    HStack(spacing: Space.m) {
                        AvatarView(name: m.name, urlString: m.avatarUrl, size: 34)
                            .overlay(Circle().strokeBorder(m.color, lineWidth: 2))
                        Text(m.name)
                            .font(Typo.callout)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: Space.s)
                        Text("\(Int((m.fraction * 100).rounded())) %")
                            .font(Typo.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkTertiary)
                        Text(CurrencyFormatter.string(m.amount, currency: currency))
                            .font(Typo.amount)
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                    }
                }
            }
        }
    }

    // MARK: - Banner de insight

    @ViewBuilder
    private var insightBanner: (some View)? {
        if let text = insightText {
            StatsBanner(icon: insightIcon, text: text, tint: insightTint)
        } else {
            nil as StatsBanner?
        }
    }

    private var insightText: String? {
        // 1) Categoría que más sube vs. periodo anterior.
        if let up = topRisingCategory {
            return "\(up.name) subió \(Int((up.delta * 100).rounded())) % vs. \(period.prevLabel)."
        }
        // 2) Tasa de ahorro positiva.
        if let rate = savingsRate, rate > 0 {
            return "Ahorraron el \(Int((rate * 100).rounded())) % de sus ingresos. ¡Bien!"
        }
        // 3) Gasto menor que el periodo anterior.
        if let d = spendDelta, d < -0.02 {
            return "Gastaron \(abs(Int((d * 100).rounded()))) % menos que \(period.prevLabel)."
        }
        return nil
    }

    private var insightIcon: String {
        if topRisingCategory != nil { return "chart.line.uptrend.xyaxis" }
        return "sparkles"
    }
    private var insightTint: Color {
        topRisingCategory != nil ? Palette.warning : Palette.accent
    }

    /// Categoría de gasto que más creció respecto al periodo anterior (≥25%).
    private var topRisingCategory: (name: String, delta: Double)? {
        var cur: [String: Double] = [:], prev: [String: Double] = [:]
        for tx in periodTxs where tx.type == .expense { cur[tx.categoryId ?? "—", default: 0] += tx.amount }
        for tx in prevTxs where tx.type == .expense { prev[tx.categoryId ?? "—", default: 0] += tx.amount }
        var best: (String, Double)?
        for (id, now) in cur {
            guard let before = prev[id], before > 0 else { continue }
            let delta = (now - before) / before
            if delta >= 0.25, delta > (best?.1 ?? 0) { best = (id, delta) }
        }
        guard let best else { return nil }
        return (app.category(for: best.0)?.name ?? "Una categoría", best.1)
    }

    // MARK: - Lista de categorías (barra semáforo)

    private var categoryBlock: some View {
        PlainSection(title: "Por categoría") {
            PlainList(categorySlices, dividerInset: 40 + Space.m) { slice in
                StatsCategoryRow(slice: slice, budget: budgetFor(slice.id), currency: currency)
            }
        }
    }

    private func budgetFor(_ categoryId: String) -> Double? {
        app.budgets.first { $0.categoryId == categoryId && $0.period == .monthly }?.amount
    }

    // MARK: - Presupuestos (semáforo)

    private var budgetBlock: some View {
        PlainSection(title: "Presupuestos") {
            VStack(spacing: Space.l) {
                ForEach(budgetRows) { row in
                    StatsBudgetRowView(row: row, currency: currency)
                }
            }
        }
    }

    // MARK: - Suscripciones

    private var subscriptionsBlock: some View {
        PlainSection(title: "Suscripciones") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gasto mensual comprometido")
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.inkSecondary)
                    Text("\(app.recurringEvents.filter(\.isActive).count) activas")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
                Spacer()
                Text(CurrencyFormatter.string(subscriptionsMonthly, currency: currency))
                    .font(Typo.amountMedium)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            .padding(.vertical, Space.s)
        }
    }
}

// MARK: - Modelos de fila / slice

private struct StatsSlice: Identifiable {
    let id: String
    let name: String
    let slug: String?
    let symbol: String
    let color: Color
    var amount: Double
    var fraction: Double
}

private struct StatsMemberSpend: Identifiable {
    let id: String
    let name: String
    let avatarUrl: String?
    let amount: Double
    let fraction: Double
    let color: Color
}

private struct StatsBudgetRow: Identifiable {
    let id: String
    let name: String
    let slug: String?
    let symbol: String
    let color: Color
    let spent: Double
    let limit: Double
    var ratio: Double { limit > 0 ? spent / limit : 0 }
}

// MARK: - Fila de categoría (con barra de % o semáforo de presupuesto)

private struct StatsCategoryRow: View {
    let slice: StatsSlice
    let budget: Double?
    let currency: String

    private var ratio: Double { budget.map { $0 > 0 ? slice.amount / $0 : 0 } ?? slice.fraction }
    private var barColor: Color {
        guard budget != nil else { return slice.color }
        switch ratio {
        case ..<0.8: return Palette.positive
        case ..<1.0: return Palette.warning
        default: return Palette.negative
        }
    }

    var body: some View {
        VStack(spacing: Space.s) {
            HStack(spacing: Space.m) {
                RowLeadingIcon(
                    categoryIcon: CategoryIconAsset.image(forSlug: slice.slug),
                    systemName: slice.symbol,
                    color: slice.color,
                    size: 40
                )
                Text(slice.name)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: Space.s)
                Text("\(Int((slice.fraction * 100).rounded())) %")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
                Text(CurrencyFormatter.string(slice.amount, currency: currency))
                    .font(Typo.amount)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            StatsBar(fraction: budget != nil ? ratio : slice.fraction, color: barColor)
                .padding(.leading, 40 + Space.m)
        }
        .padding(.vertical, Space.m)
    }
}

private struct StatsBudgetRowView: View {
    let row: StatsBudgetRow
    let currency: String

    private var barColor: Color {
        switch row.ratio {
        case ..<0.8: return Palette.positive
        case ..<1.0: return Palette.warning
        default: return Palette.negative
        }
    }

    var body: some View {
        VStack(spacing: Space.s) {
            HStack {
                RowLeadingIcon(
                    categoryIcon: CategoryIconAsset.image(forSlug: row.slug),
                    systemName: row.symbol,
                    color: row.color,
                    size: 34
                )
                Text(row.name)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: Space.s)
                Text("\(CurrencyFormatter.string(row.spent, currency: currency)) / \(CurrencyFormatter.compact(row.limit))")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(row.ratio >= 1 ? Palette.negative : Palette.inkSecondary)
            }
            StatsBar(fraction: row.ratio, color: barColor)
                .padding(.leading, 34 + Space.m)
        }
    }
}

// MARK: - Barra de progreso inline

private struct StatsBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0, min(1, fraction))
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceElevated)
                Capsule()
                    .fill(color)
                    .frame(width: max(height, geo.size.width * clamped))
                    .animation(Motion.value, value: clamped)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Leyenda que envuelve (puntos + label)

private struct FlowLegend: View {
    let slices: [StatsSlice]

    var body: some View {
        // Grid de 2 columnas para que quepan hasta 6 entradas ordenadas.
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                            GridItem(.flexible(), alignment: .leading)],
                  alignment: .leading, spacing: Space.s) {
            ForEach(slices) { s in
                HStack(spacing: Space.s) {
                    Circle().fill(s.color).frame(width: 8, height: 8)
                    Text(s.name)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                    Text("\(Int((s.fraction * 100).rounded())) %")
                        .font(Typo.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
        }
    }
}

// MARK: - Banner de insight (flat, fondo tinte)

private struct StatsBanner: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(Typo.subhead)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
        .padding(Space.m)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
    }
}

// MARK: - Estados vacío / carga

private struct StatsEmpty: View {
    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "chart.pie")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
            Text("Sin gastos en este periodo")
                .font(Typo.headline)
                .foregroundStyle(Palette.ink)
            Text("Cuando registren movimientos aparecerán aquí sus estadísticas.")
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.xxxl)
    }
}

private struct StatsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            RoundedRectangle(cornerRadius: Radius.pill).fill(Palette.surfaceElevated).frame(height: 40)
            RoundedRectangle(cornerRadius: Radius.s).fill(Palette.surfaceElevated).frame(width: 220, height: 44)
            Circle().fill(Palette.surfaceElevated).frame(width: 200, height: 200).frame(maxWidth: .infinity)
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Radius.s).fill(Palette.surfaceElevated).frame(height: 44)
            }
        }
        .padding(Space.l)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Periodo

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week, month, quarter, semester, year
    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return "Sem"
        case .month: return "Mes"
        case .quarter: return "3M"
        case .semester: return "6M"
        case .year: return "Año"
        }
    }
    /// Sufijo del label del hero ("GASTO DE LA SEMANA/DEL MES…").
    var heroLabel: String {
        switch self {
        case .week: return "DE LA SEMANA"
        case .month: return "DEL MES"
        case .quarter: return "DEL TRIMESTRE"
        case .semester: return "DEL SEMESTRE"
        case .year: return "DEL AÑO"
        }
    }
    var prevLabel: String {
        switch self {
        case .week: return "la semana pasada"
        case .month: return "el mes pasado"
        case .quarter: return "el trimestre pasado"
        case .semester: return "el semestre pasado"
        case .year: return "el año pasado"
        }
    }
}

// MARK: - Cálculo de rangos y etiquetas

enum StatsCalendar {
    private static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // lunes
        return c
    }

    /// Intervalo de fechas del periodo, desplazado `offset` periodos hacia atrás.
    static func interval(_ period: StatsPeriod, offset: Int) -> DateInterval {
        let now = Date()
        switch period {
        case .week:
            let start = startOfWeek(cal.date(byAdding: .weekOfYear, value: -offset, to: now) ?? now)
            return DateInterval(start: start, end: cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start)
        case .month:
            let base = cal.date(byAdding: .month, value: -offset, to: now) ?? now
            let start = startOfMonth(base)
            return DateInterval(start: start, end: cal.date(byAdding: .month, value: 1, to: start) ?? start)
        case .quarter:
            let base = cal.date(byAdding: .month, value: -offset * 3, to: now) ?? now
            let start = startOfMonth(cal.date(byAdding: .month, value: -2, to: base) ?? base)
            return DateInterval(start: start, end: cal.date(byAdding: .month, value: 3, to: start) ?? start)
        case .semester:
            let base = cal.date(byAdding: .month, value: -offset * 6, to: now) ?? now
            let start = startOfMonth(cal.date(byAdding: .month, value: -5, to: base) ?? base)
            return DateInterval(start: start, end: cal.date(byAdding: .month, value: 6, to: start) ?? start)
        case .year:
            let base = cal.date(byAdding: .year, value: -offset, to: now) ?? now
            let start = startOfYear(base)
            return DateInterval(start: start, end: cal.date(byAdding: .year, value: 1, to: start) ?? start)
        }
    }

    /// Etiqueta legible del periodo visible.
    static func label(_ period: StatsPeriod, offset: Int) -> String {
        let iv = interval(period, offset: offset)
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        switch period {
        case .week:
            f.dateFormat = "d MMM"
            let endDay = cal.date(byAdding: .day, value: -1, to: iv.end) ?? iv.end
            return "\(f.string(from: iv.start)) – \(f.string(from: endDay))".replacingOccurrences(of: ".", with: "")
        case .month:
            f.dateFormat = "MMMM yyyy"
            return f.string(from: iv.start).capitalized
        case .quarter, .semester:
            f.dateFormat = "MMM"
            let endMonth = cal.date(byAdding: .day, value: -1, to: iv.end) ?? iv.end
            return "\(f.string(from: iv.start)) – \(f.string(from: endMonth)) \(cal.component(.year, from: endMonth))".replacingOccurrences(of: ".", with: "")
        case .year:
            return "\(cal.component(.year, from: iv.start))"
        }
    }

    static func parse(_ raw: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = cal.timeZone
        df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: String(raw.prefix(10))) { return d }
        return ISO8601DateFormatter().date(from: raw)
    }

    private static func startOfWeek(_ d: Date) -> Date {
        cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
    }
    private static func startOfMonth(_ d: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
    }
    private static func startOfYear(_ d: Date) -> Date {
        cal.date(from: cal.dateComponents([.year], from: d)) ?? d
    }
}

// MARK: - Estilo de categoría / colores

private enum StatsStyle {
    static func color(for category: Category?, index: Int) -> Color {
        if let parsed = parseHex(category?.color) { return parsed }
        return Palette.categoryColor(for: index)
    }
    static func symbol(for category: Category?) -> String {
        guard let category else { return "circle.grid.2x2.fill" }
        if category.icon.contains(".") { return category.icon }
        return IconMapping.sfSymbol(for: category.icon.isEmpty ? category.name : category.icon)
    }
    /// Color por miembro: violeta de marca para el 1º, luego CustomPalette.
    static func memberColor(_ index: Int) -> Color {
        index == 0 ? Palette.accent : CustomPalette.colors[(index + 4) % CustomPalette.colors.count]
    }
    private static func parseHex(_ hex: String?) -> Color? {
        guard var s = hex?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s.removeFirst(2) }
        guard s.count == 6, let value = UInt(s, radix: 16) else { return nil }
        return Color(hex: value)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { ReportsView() }
        .environment(AppState.previewMocked)
        .preferredColorScheme(.dark)
}
