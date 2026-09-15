import SwiftUI
import Charts

// Reports / "Estadísticas" — paridad total con apps/mobile/app/(tabs)/reports.tsx.
//
// Estructura (idéntica a la original RN, reinterpretada con el design system):
//   · Header "Estadísticas" + selector de mes con flechas (‹ SEP 2026 ›)
//   · Balance neto (ingresos − gastos del mes) con dos KPIs (Ingresos / Gastos)
//   · Toggle de línea Gastos / Ingresos (subrayado, sin contenedor)
//   · Barras comparativas Ingresos vs Gastos de los últimos 6 meses (Swift Charts)
//   · Lista de categorías con barra de porcentaje (del tab activo, orden desc)
//   · Tendencia (área) del tab activo sobre los 6 meses (Swift Charts)
//   · Presupuesto del mes (solo en tab Gastos): total + progreso por categoría
//   · Skeleton mientras carga y estados vacíos amables.
//
// Todo se calcula desde app.transactions / app.categories / app.budgets. El mes
// se filtra por prefijo "YYYY-MM" de la fecha (equivalente al monthRange del core).

struct ReportsView: View {
    @Environment(AppState.self) private var app

    // Primer día del mes visible.
    @State private var monthAnchor: Date = ReportsCalendar.startOfMonth(Date())
    @State private var activeTab: ReportsTab = .expense
    @Namespace private var tabNS

    // Datos base (derivados de AppState, ya en memoria).
    private var currency: String { app.currency }

    // Transacciones del mes visible (prefijo YYYY-MM).
    private var monthTxs: [Transaction] {
        let key = ReportsCalendar.monthKey(monthAnchor)
        return app.transactions.filter { $0.date.hasPrefix(key) }
    }

    private var income: Double {
        monthTxs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    private var expense: Double {
        monthTxs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    private var balance: Double { income - expense }

    // Historial de 6 meses (incluyendo el visible) para las gráficas.
    private var history: [ReportsMonthPoint] {
        (0..<6).reversed().map { back in
            let anchor = ReportsCalendar.addingMonths(-back, to: monthAnchor)
            let key = ReportsCalendar.monthKey(anchor)
            let txs = app.transactions.filter { $0.date.hasPrefix(key) }
            let inc = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let exp = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            return ReportsMonthPoint(
                id: key,
                label: ReportsCalendar.shortMonth(anchor),
                income: inc,
                expense: exp
            )
        }
    }

    // Agregado por categoría del tab activo, orden descendente.
    private var categoryRows: [ReportsCategoryRow] {
        let type: TransactionType = activeTab == .income ? .income : .expense
        var totals: [String: Double] = [:]
        for tx in monthTxs where tx.type == type {
            guard let catId = tx.categoryId else { continue }
            totals[catId, default: 0] += tx.amount
        }
        let total = totals.values.reduce(0, +)
        let rows = totals
            .sorted { $0.value > $1.value }
            .enumerated()
            .map { index, entry -> ReportsCategoryRow in
                let cat = app.category(for: entry.key)
                let pct = total > 0 ? entry.value / total : 0
                return ReportsCategoryRow(
                    id: entry.key,
                    name: cat?.name ?? "Otro",
                    symbol: ReportsCategoryStyle.symbol(for: cat),
                    color: ReportsCategoryStyle.color(for: cat, index: index),
                    amount: entry.value,
                    fraction: pct
                )
            }
        return rows
    }

    // Presupuestos vigentes del mes (mensuales) con lo gastado en el mes visible.
    private var budgetRows: [ReportsBudgetRow] {
        app.budgets
            .filter { $0.period == .monthly }
            .map { budget in
                let spent = monthTxs
                    .filter { $0.type == .expense && $0.categoryId == budget.categoryId }
                    .reduce(0) { $0 + $1.amount }
                let cat = app.category(for: budget.categoryId)
                return ReportsBudgetRow(
                    id: budget.id,
                    name: cat?.name ?? "Categoría",
                    symbol: ReportsCategoryStyle.symbol(for: cat),
                    spent: spent,
                    limit: budget.amount
                )
            }
    }

    private var isLoading: Bool {
        // Sin datos aún y AppState todavía sincronizando la primera carga.
        app.transactions.isEmpty && app.phase != .ready
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ReportsSkeleton()
            } else {
                VStack(spacing: 0) {
                    heroBlock
                    ReportsDivider()
                    tabBlock
                    ReportsDivider()
                    comparisonBlock
                    ReportsDivider()
                    if !categoryRows.isEmpty {
                        categoryBlock
                        ReportsDivider()
                    }
                    trendBlock
                    if activeTab == .expense && !budgetRows.isEmpty {
                        ReportsDivider()
                        budgetBlock
                    }
                }
                .padding(.bottom, Space.xxxl)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Estadísticas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Estadísticas")
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
            }
            ToolbarItem(placement: .topBarTrailing) {
                monthSelector
            }
        }
        .refreshable { await app.refreshAll() }
    }

    // MARK: - Selector de mes

    private var monthSelector: some View {
        // Selector pill flotante (chrome) sobre el fondo → Liquid Glass en cápsula.
        HStack(spacing: Space.s) {
            Button {
                withAnimation(Motion.value) {
                    monthAnchor = ReportsCalendar.addingMonths(-1, to: monthAnchor)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.inkSecondary)
                    .contentShape(Rectangle())
            }
            .pressable(scale: 0.85)

            Text(ReportsCalendar.monthLabel(monthAnchor))
                .font(Typo.overline)
                .tracking(1.4)
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                .frame(minWidth: 78)
                .contentTransition(.numericText())

            Button {
                withAnimation(Motion.value) {
                    monthAnchor = ReportsCalendar.addingMonths(1, to: monthAnchor)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.inkSecondary)
                    .contentShape(Rectangle())
            }
            .pressable(scale: 0.85)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.xs)
        .liquidGlassCapsule()
        .overlay(Capsule().strokeBorder(Palette.stroke.opacity(0.5), lineWidth: 0.5))
    }

    // MARK: - Balance neto (hero)

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BALANCE NETO")
                .font(Typo.overline)
                .tracking(1.2)
                .foregroundStyle(Palette.inkTertiary)
                .padding(.bottom, Space.s)

            AmountText(
                amount: balance,
                currency: currency,
                font: Typo.amountHero(42),
                signed: true
            )
            // Cifra hero: tracking negativo sutil para que respire mejor a gran tamaño.
            .tracking(-0.8)
            .contentTransition(.numericText(value: balance))
            .animation(Motion.value, value: balance)
            .padding(.bottom, Space.xl)

            HStack(spacing: 0) {
                ReportsKPI(
                    icon: "arrow.up",
                    iconColor: Palette.green,
                    label: "Ingresos",
                    amount: income,
                    currency: currency
                )
                Rectangle()
                    .fill(Palette.stroke)
                    .frame(width: 1, height: 36)
                    .padding(.horizontal, Space.xl)
                ReportsKPI(
                    icon: "arrow.down",
                    iconColor: Palette.pink,
                    label: "Gastos",
                    amount: expense,
                    currency: currency
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.xl)
    }

    // MARK: - Toggle Gastos / Ingresos (subrayado)

    private var tabBlock: some View {
        HStack(spacing: Space.xl) {
            ForEach(ReportsTab.allCases, id: \.self) { tab in
                let isActive = activeTab == tab
                Button {
                    withAnimation(Motion.ui) { activeTab = tab }
                } label: {
                    VStack(spacing: Space.s) {
                        Text(tab.title)
                            .font(Typo.callout)
                            .foregroundStyle(isActive ? tab.tint : Palette.inkTertiary)
                        ZStack {
                            Capsule().fill(Color.clear).frame(height: 2)
                            if isActive {
                                Capsule()
                                    .fill(tab.tint)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "tabUnderline", in: tabNS)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.m)
    }

    // MARK: - Comparativa Ingresos vs Gastos (barras)

    private var comparisonBlock: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            ReportsBlockTitle("Ingresos vs Gastos")

            if history.allSatisfy({ $0.income == 0 && $0.expense == 0 }) {
                ReportsInlineEmpty(text: "Sin movimientos en el periodo")
                    .frame(height: 140)
            } else {
                Chart {
                    ForEach(history) { point in
                        BarMark(
                            x: .value("Mes", point.label),
                            y: .value("Monto", point.income),
                            width: .fixed(11)
                        )
                        .position(by: .value("Tipo", "Ingresos"))
                        .foregroundStyle(Palette.ink.opacity(0.75))
                        .cornerRadius(2)

                        BarMark(
                            x: .value("Mes", point.label),
                            y: .value("Monto", point.expense),
                            width: .fixed(11)
                        )
                        .position(by: .value("Tipo", "Gastos"))
                        .foregroundStyle(Palette.pink.opacity(0.8))
                        .cornerRadius(2)
                    }
                }
                .chartForegroundStyleScale([
                    "Ingresos": Palette.ink.opacity(0.75),
                    "Gastos": Palette.pink.opacity(0.8)
                ])
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Palette.stroke.opacity(0.4))
                        AxisValueLabel {
                            if let raw = value.as(Double.self) {
                                Text(CurrencyFormatter.compact(raw))
                                    .font(.system(size: 8))
                                    .foregroundStyle(Palette.inkTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
                .frame(height: 140)

                // Leyenda manual (idéntica a la original).
                HStack(spacing: Space.xl) {
                    ReportsLegendDot(color: Palette.ink.opacity(0.75), text: "INGRESOS")
                    ReportsLegendDot(color: Palette.pink.opacity(0.8), text: "GASTOS")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.l)
    }

    // MARK: - Lista de categorías

    private var categoryBlock: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            ReportsBlockTitle("\(activeTab.title) — por categoría")

            VStack(spacing: Space.l) {
                ForEach(Array(categoryRows.enumerated()), id: \.element.id) { index, row in
                    VStack(spacing: Space.m) {
                        ReportsCategoryRowView(row: row, currency: currency)
                        if index < categoryRows.count - 1 {
                            Rectangle()
                                .fill(Palette.stroke.opacity(0.4))
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.l)
    }

    // MARK: - Tendencia (área)

    private var trendBlock: some View {
        let points = history.map { point in
            ReportsTrendPoint(
                id: point.id,
                label: point.label,
                value: activeTab == .income ? point.income : point.expense
            )
        }
        let tint = activeTab.tint
        let currentTotal = activeTab == .income ? income : expense

        return VStack(alignment: .leading, spacing: Space.l) {
            HStack(alignment: .firstTextBaseline) {
                ReportsBlockTitle(activeTab == .income ? "Tendencia ingresos" : "Tendencia gastos")
                Spacer()
                Text("\(ReportsCalendar.shortMonth(monthAnchor).uppercased())  \(CurrencyFormatter.string(currentTotal, currency: currency))")
                    .font(Typo.caption)
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }

            if points.allSatisfy({ $0.value == 0 }) {
                ReportsInlineEmpty(text: "Sin datos de tendencia")
                    .frame(height: 140)
            } else {
                Chart(points) { point in
                    AreaMark(
                        x: .value("Mes", point.label),
                        y: .value("Monto", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Mes", point.label),
                        y: .value("Monto", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Palette.stroke.opacity(0.4))
                        AxisValueLabel {
                            if let raw = value.as(Double.self) {
                                Text(CurrencyFormatter.compact(raw))
                                    .font(.system(size: 8))
                                    .foregroundStyle(Palette.inkTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
                .frame(height: 140)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.l)
    }

    // MARK: - Presupuesto del mes

    private var budgetBlock: some View {
        let totalSpent = budgetRows.reduce(0) { $0 + $1.spent }
        let totalLimit = budgetRows.reduce(0) { $0 + $1.limit }

        return VStack(alignment: .leading, spacing: Space.l) {
            ReportsBlockTitle("Presupuesto mensual")
            ReportsBudgetArch(spent: totalSpent, limit: totalLimit, currency: currency)

            VStack(spacing: Space.l) {
                ForEach(budgetRows) { row in
                    ReportsBudgetProgress(row: row, currency: currency)
                }
            }
            .padding(.top, Space.s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.l)
    }
}

// MARK: - Modelos de fila / datos

private enum ReportsTab: CaseIterable, Hashable {
    case expense, income

    var title: String {
        switch self {
        case .expense: return "Gastos"
        case .income: return "Ingresos"
        }
    }

    var tint: Color {
        switch self {
        case .expense: return Palette.pink
        case .income: return Palette.green
        }
    }
}

private struct ReportsMonthPoint: Identifiable {
    let id: String
    let label: String
    let income: Double
    let expense: Double
}

private struct ReportsTrendPoint: Identifiable {
    let id: String
    let label: String
    let value: Double
}

private struct ReportsCategoryRow: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let color: Color
    let amount: Double
    let fraction: Double // 0...1
}

private struct ReportsBudgetRow: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let spent: Double
    let limit: Double
}

// MARK: - Subcomponentes

private struct ReportsKPI: View {
    let icon: String
    let iconColor: Color
    let label: String
    let amount: Double
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Text(CurrencyFormatter.string(amount, currency: currency))
                .font(Typo.amount)
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                .contentTransition(.numericText(value: amount))
                .animation(Motion.value, value: amount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReportsCategoryRowView: View {
    let row: ReportsCategoryRow
    let currency: String

    var body: some View {
        VStack(spacing: Space.s) {
            HStack(spacing: Space.m) {
                Image(systemName: row.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(row.color)
                    .frame(width: 20)

                Text(row.name)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Spacer(minLength: Space.s)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(CurrencyFormatter.string(row.amount, currency: currency))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                    Text("\(Int((row.fraction * 100).rounded())) %")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(row.color)
                        .monospacedDigit()
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.stroke.opacity(0.5))
                    Capsule()
                        .fill(row.color)
                        .frame(width: max(2, geo.size.width * min(1, max(0, row.fraction))))
                        .animation(Motion.value, value: row.fraction)
                }
            }
            .frame(height: 3)
        }
    }
}

private struct ReportsBudgetArch: View {
    let spent: Double
    let limit: Double
    let currency: String

    private var ratio: Double { limit > 0 ? min(spent / limit, 1) : 0 }
    private var barColor: Color {
        switch ratio {
        case ..<0.7: return Palette.ink
        case ..<0.9: return Palette.inkSecondary
        default: return Palette.pink
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("GASTO TOTAL")
                        .font(Typo.overline)
                        .tracking(1.2)
                        .foregroundStyle(Palette.inkTertiary)
                    Text(CurrencyFormatter.string(spent, currency: currency))
                        .font(Typo.amountMedium)
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Space.xs) {
                    Text("Límite")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                    Text(CurrencyFormatter.string(limit, currency: currency))
                        .font(Typo.callout)
                        .foregroundStyle(Palette.inkSecondary)
                        .monospacedDigit()
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surfaceElevated)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(4, geo.size.width * ratio))
                        .animation(Motion.value, value: ratio)
                }
            }
            .frame(height: 4)

            Text("\(Int((ratio * 100).rounded())) % consumido")
                .font(Typo.caption)
                .foregroundStyle(barColor)
                .monospacedDigit()
        }
    }
}

private struct ReportsBudgetProgress: View {
    let row: ReportsBudgetRow
    let currency: String

    private var ratio: Double { row.limit > 0 ? min(row.spent / row.limit, 1) : 0 }
    private var barColor: Color {
        switch ratio {
        case ..<0.7: return Palette.ink
        case ..<0.9: return Palette.inkSecondary
        default: return Palette.pink
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                Image(systemName: row.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
                Text(row.name)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer()
                Text("\(CurrencyFormatter.compact(row.spent)) / \(CurrencyFormatter.compact(row.limit))")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surfaceElevated)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(3, geo.size.width * ratio))
                        .animation(Motion.value, value: ratio)
                }
            }
            .frame(height: 3)

            Text("\(Int((ratio * 100).rounded())) % usado")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(barColor)
                .monospacedDigit()
        }
    }
}

private struct ReportsBlockTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(Typo.overline)
            .tracking(1.4)
            .foregroundStyle(Palette.inkTertiary)
    }
}

private struct ReportsLegendDot: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: Space.s) {
            Capsule()
                .fill(color)
                .frame(width: 10, height: 3)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Palette.inkTertiary)
        }
    }
}

private struct ReportsInlineEmpty: View {
    let text: String
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: Space.s) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Palette.inkTertiary)
                Text(text)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer()
        }
    }
}

private struct ReportsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.stroke.opacity(0.6))
            .frame(height: 1)
    }
}

// MARK: - Skeleton (pulso mientras carga)

private struct ReportsSkeleton: View {
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero
            VStack(alignment: .leading, spacing: Space.m) {
                bone(width: 80, height: 11)
                bone(width: 180, height: 40)
                HStack(spacing: Space.xxl) {
                    VStack(alignment: .leading, spacing: Space.s) {
                        bone(width: 60, height: 10)
                        bone(width: 110, height: 18)
                    }
                    VStack(alignment: .leading, spacing: Space.s) {
                        bone(width: 60, height: 10)
                        bone(width: 110, height: 18)
                    }
                }
                .padding(.top, Space.s)
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.xl)

            ReportsDivider()

            // Barras
            VStack(alignment: .leading, spacing: Space.m) {
                bone(width: 120, height: 10)
                HStack(alignment: .bottom, spacing: Space.s) {
                    ForEach([80, 50, 60, 90, 70, 110, 45, 100, 55, 130, 75, 140], id: \.self) { h in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Palette.inkTertiary.opacity(pulse ? 0.18 : 0.07))
                            .frame(width: 12, height: CGFloat(h))
                    }
                }
                .frame(height: 140, alignment: .bottom)
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.l)

            ReportsDivider()

            // Lista de categorías
            VStack(alignment: .leading, spacing: Space.l) {
                bone(width: 140, height: 10)
                ForEach([100, 70, 55], id: \.self) { w in
                    VStack(spacing: Space.s) {
                        HStack {
                            bone(width: 16, height: 16)
                            bone(width: CGFloat(w), height: 12)
                            Spacer()
                            bone(width: 70, height: 12)
                        }
                        bone(width: .infinity, height: 3)
                    }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.l)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func bone(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Palette.inkTertiary.opacity(pulse ? 0.18 : 0.07))
            .frame(width: width == .infinity ? nil : width, height: height)
            .frame(maxWidth: width == .infinity ? .infinity : nil)
    }
}

// MARK: - Utilidades de calendario / mes

private enum ReportsCalendar {
    private static let months = [
        "Ene", "Feb", "Mar", "Abr", "May", "Jun",
        "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
    ]

    static func startOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    static func addingMonths(_ delta: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: delta, to: date) ?? date
    }

    /// Clave "YYYY-MM" para filtrar por prefijo de fecha.
    static func monthKey(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        return String(format: "%04d-%02d", y, m)
    }

    /// "Sep" — nombre corto del mes.
    static func shortMonth(_ date: Date) -> String {
        let m = Calendar.current.component(.month, from: date)
        return months[(m - 1 + 12) % 12]
    }

    /// "SEP 2026" — etiqueta del selector.
    static func monthLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        return "\(shortMonth(date).uppercased()) \(y)"
    }
}

// MARK: - Estilo de categoría (color hex + símbolo SF)

private enum ReportsCategoryStyle {
    static func color(for category: Category?, index: Int) -> Color {
        if let parsed = parseHex(category?.color) { return parsed }
        return Palette.categoryColor(for: index)
    }

    static func symbol(for category: Category?) -> String {
        guard let category else { return "circle.grid.2x2.fill" }
        if category.icon.contains(".") { return category.icon } // ya parece SF Symbol
        return IconMapping.sfSymbol(for: category.icon.isEmpty ? category.name : category.icon)
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
    NavigationStack {
        ReportsView()
    }
    .environment(AppState.previewMocked)
    .preferredColorScheme(.dark)
}
