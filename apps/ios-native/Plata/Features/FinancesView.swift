import SwiftUI

// Hub de finanzas (era la tab "finances" de la app RN). Centro de navegación de
// todo lo que no es dashboard ni transacciones: cuentas, deudas, metas de ahorro,
// listas de compra, presupuestos y suscripciones/recurrentes. Cada sección tiene
// su SectionLabel, un acceso "Ver todas" que empuja la vista de lista completa, y
// un "+" para crear. Los ítems individuales navegan a su detalle cuando existe.
//
// Datos desde app.* (accounts, debts, goals, shoppingLists, budgets,
// recurringEvents, transactions, categories). Nada de red aquí salvo el conteo de
// ítems de las listas de compra, que se carga bajo demanda con el Repository.

struct FinancesView: View {
    @Environment(AppState.self) private var app

    @State private var showingAddAccount = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                FinanzashubAccountsSection(
                    accounts: app.accounts,
                    total: app.totalBalance,
                    currency: app.currency,
                    onAdd: { showingAddAccount = true }
                )

                FinanzashubDebtsSection(
                    debts: app.debts.filter { $0.status == .active },
                    currency: app.currency
                )

                FinanzashubGoalsSection(
                    goals: app.goals.filter { $0.status == .active },
                    currency: app.currency
                )

                FinanzashubShoppingSection(
                    lists: app.shoppingLists.filter { $0.status != .completed },
                    currency: app.currency
                )

                FinanzashubBudgetsSection(
                    budgets: app.budgets,
                    resolveCategory: { app.category(for: $0) },
                    spent: { FinanzashubMath.spent(for: $0, in: app.transactions) },
                    currency: app.currency
                )

                FinanzashubRecurringSection(
                    events: app.recurringEvents.filter { $0.isActive },
                    resolveCategory: { app.category(for: $0) },
                    currency: app.currency
                )
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.s)
            .padding(.bottom, Space.xxxl)
        }
        .background(Palette.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Finanzas")
        .navigationDestination(for: SavingsGoal.self) { GoalDetailView(goal: $0) }
        .navigationDestination(for: ShoppingList.self) { ShoppingListDetailView(list: $0) }
        .navigationDestination(for: FinanzashubRoute.self) { route in
            switch route {
            case .accounts: AccountsView()
            case .debts: DebtsView()
            case .goals: GoalsView()
            case .shopping: ShoppingView()
            case .budgets: BudgetsView()
            case .recurring: RecurringView()
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView()
        }
    }
}

// MARK: - Rutas de sección (vistas de lista completas)

private enum FinanzashubRoute: Hashable {
    case accounts, debts, goals, shopping, budgets, recurring
}

// MARK: - Encabezado de sección del hub (label + "ver todas" + "+")

private struct FinanzashubSectionHeader: View {
    let title: String
    var route: FinanzashubRoute? = nil
    var addAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: Space.s) {
            Text(title.uppercased())
                .font(Typo.overline)
                .tracking(0.8)
                .foregroundStyle(Palette.inkTertiary)

            Spacer()

            if let route {
                NavigationLink(value: route) {
                    Text("Ver todas")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
                .pressable(scale: 0.94)
            }

            if let addAction {
                Button(action: addAction) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 26, height: 26)
                        .background(Palette.accent.opacity(0.14), in: Circle())
                }
                .pressable(scale: 0.9)
                .accessibilityLabel("Añadir")
            }
        }
    }
}

// MARK: - Cuentas

private struct FinanzashubAccountsSection: View {
    let accounts: [Account]
    let total: Double
    let currency: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinanzashubSectionHeader(title: "Cuentas", route: .accounts, addAction: onAdd)

            if accounts.isEmpty {
                FinanzashubEmptyCard(
                    icon: "creditcard",
                    tint: Palette.sky,
                    text: "Sin cuentas todavía. Usa el “+” para crear una."
                )
            } else {
                Card {
                    VStack(spacing: 0) {
                        // Total del hogar arriba.
                        HStack {
                            Text("Balance total")
                                .font(Typo.callout)
                                .foregroundStyle(Palette.inkSecondary)
                            Spacer()
                            AmountText(amount: total, currency: currency, font: Typo.amountMedium)
                        }
                        .padding(.bottom, Space.m)

                        Divider().overlay(Palette.stroke)
                            .padding(.bottom, Space.s)

                        ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                            NavigationLink(value: FinanzashubRoute.accounts) {
                                FinanzashubAccountRow(account: account, currency: currency)
                            }
                            .buttonStyle(.plain)
                            .pressable()

                            if index < accounts.count - 1 {
                                Divider().overlay(Palette.stroke)
                                    .padding(.leading, 40 + Space.m)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct FinanzashubAccountRow: View {
    let account: Account
    let currency: String

    private var tint: Color { FinanzashubHex.color(account.color, fallbackFor: account.id) }

    var body: some View {
        HStack(spacing: Space.m) {
            CategoryIcon(systemName: account.type.sfSymbol, color: tint, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(account.type.label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }

            Spacer(minLength: Space.s)

            AmountText(amount: account.balance, currency: currency, font: Typo.amount)
        }
        .padding(.vertical, Space.s)
        .contentShape(Rectangle())
    }
}

// MARK: - Deudas

private struct FinanzashubDebtsSection: View {
    let debts: [Debt]
    let currency: String

    private var owedToUs: [Debt] { debts.filter { $0.direction == .owedToUs } }
    private var weOwe: [Debt] { debts.filter { $0.direction == .weOwe } }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinanzashubSectionHeader(title: "Deudas", route: .debts)

            if debts.isEmpty {
                FinanzashubEmptyCard(
                    icon: "hand.thumbsup.fill",
                    tint: Palette.green,
                    text: "Sin deudas registradas."
                )
            } else {
                Card {
                    VStack(spacing: 0) {
                        let rows = owedToUs + weOwe
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, debt in
                            NavigationLink(value: FinanzashubRoute.debts) {
                                FinanzashubDebtRow(debt: debt, currency: currency)
                            }
                            .buttonStyle(.plain)
                            .pressable()

                            if index < rows.count - 1 {
                                Divider().overlay(Palette.stroke)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct FinanzashubDebtRow: View {
    let debt: Debt
    let currency: String

    private var isOwedToUs: Bool { debt.direction == .owedToUs }
    private var tint: Color { isOwedToUs ? Palette.green : Palette.pink }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .top, spacing: Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(debt.description?.isEmpty == false ? debt.description! : "Deuda")
                        .font(Typo.callout)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: Space.s)

                VStack(alignment: .trailing, spacing: 2) {
                    Text((isOwedToUs ? "+" : "−") + CurrencyFormatter.string(debt.remaining, currency: currency))
                        .font(Typo.amount)
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    Text("Restante")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
            }

            HStack(spacing: Space.s) {
                FinanzashubProgressBar(progress: debt.progress, tint: tint)
                Text("\(Int((debt.progress * 100).rounded())) %")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(width: 34, alignment: .trailing)
            }
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        let base = isOwedToUs ? "Nos deben" : "Debemos"
        return debt.personName.isEmpty ? base : "\(base) • \(debt.personName)"
    }
}

// MARK: - Metas de ahorro

private struct FinanzashubGoalsSection: View {
    let goals: [SavingsGoal]
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinanzashubSectionHeader(title: "Metas de ahorro", route: .goals)

            if goals.isEmpty {
                FinanzashubEmptyCard(
                    icon: "target",
                    tint: Palette.accent,
                    text: "Sin metas establecidas."
                )
            } else {
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                            NavigationLink(value: goal) {
                                FinanzashubGoalRow(goal: goal, index: index, currency: currency)
                            }
                            .buttonStyle(.plain)
                            .pressable()

                            if index < goals.count - 1 {
                                Divider().overlay(Palette.stroke)
                                    .padding(.leading, 44 + Space.m)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct FinanzashubGoalRow: View {
    let goal: SavingsGoal
    let index: Int
    let currency: String

    private var tint: Color { FinanzashubHex.color(goal.color, fallbackIndex: index) }
    private var symbol: String {
        goal.icon.contains(".") ? goal.icon : IconMapping.sfSymbol(for: goal.icon)
    }

    var body: some View {
        HStack(spacing: Space.m) {
            ZStack {
                ProgressRing(progress: goal.progress, color: tint, lineWidth: 5, size: 44)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s)

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.string(goal.currentAmount, currency: currency))
                    .font(Typo.amount)
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text("de \(CurrencyFormatter.compact(goal.targetAmount))")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .padding(.vertical, Space.s)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        if let deadline = goal.deadline, !deadline.isEmpty {
            return "Objetivo: \(FinanzashubDate.short(deadline))"
        }
        return "Ahorro libre"
    }
}

// MARK: - Listas de compra

private struct FinanzashubShoppingSection: View {
    let lists: [ShoppingList]
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinanzashubSectionHeader(title: "Listas de compra", route: .shopping)

            if lists.isEmpty {
                FinanzashubEmptyCard(
                    icon: "cart",
                    tint: Palette.sky,
                    text: "Sin listas de compra."
                )
            } else {
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(lists.enumerated()), id: \.element.id) { index, list in
                            NavigationLink(value: list) {
                                FinanzashubShoppingRow(list: list)
                            }
                            .buttonStyle(.plain)
                            .pressable()

                            if index < lists.count - 1 {
                                Divider().overlay(Palette.stroke)
                                    .padding(.leading, 40 + Space.m)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct FinanzashubShoppingRow: View {
    let list: ShoppingList

    private var tint: Color { ShoppingStatusStyle.tint(for: list.status) }

    var body: some View {
        HStack(spacing: Space.m) {
            CategoryIcon(systemName: "cart.fill", color: tint, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(.vertical, Space.s)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        ShoppingStatusStyle.label(for: list.status)
            + ((list.store?.isEmpty == false) ? " • \(list.store!)" : "")
    }
}

// MARK: - Presupuestos

private struct FinanzashubBudgetsSection: View {
    let budgets: [Budget]
    let resolveCategory: (String?) -> Category?
    let spent: (Budget) -> Double
    let currency: String

    private var totalSpent: Double { budgets.reduce(0) { $0 + spent($1) } }
    private var totalLimit: Double { budgets.reduce(0) { $0 + $1.amount } }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinanzashubSectionHeader(title: "Presupuestos", route: .budgets)

            if budgets.isEmpty {
                FinanzashubEmptyCard(
                    icon: "chart.pie.fill",
                    tint: Palette.amber,
                    text: "Sin presupuestos este mes."
                )
            } else {
                Card {
                    VStack(alignment: .leading, spacing: Space.l) {
                        // Resumen mensual arriba.
                        HStack(alignment: .firstTextBaseline) {
                            Text("Gasto del mes")
                                .font(Typo.callout)
                                .foregroundStyle(Palette.inkSecondary)
                            Spacer()
                            Text("\(CurrencyFormatter.string(totalSpent, currency: currency)) / \(CurrencyFormatter.compact(totalLimit))")
                                .font(Typo.callout)
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                        }

                        FinanzashubProgressBar(
                            progress: totalLimit > 0 ? totalSpent / totalLimit : 0,
                            tint: FinanzashubMath.color(for: totalLimit > 0 ? totalSpent / totalLimit : 0),
                            height: 8
                        )

                        Divider().overlay(Palette.stroke)

                        ForEach(Array(budgets.enumerated()), id: \.element.id) { index, budget in
                            FinanzashubBudgetRow(
                                budget: budget,
                                category: resolveCategory(budget.categoryId),
                                spent: spent(budget),
                                index: index,
                                currency: currency
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct FinanzashubBudgetRow: View {
    let budget: Budget
    let category: Category?
    let spent: Double
    let index: Int
    let currency: String

    private var ratio: Double { budget.amount > 0 ? spent / budget.amount : 0 }
    private var tint: Color { FinanzashubHex.color(category?.color, fallbackIndex: index) }
    private var barColor: Color { FinanzashubMath.color(for: ratio) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                Image(systemName: IconMapping.sfSymbol(for: category?.icon))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20)
                Text(category?.name ?? "Sin categoría")
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: Space.s)
                Text("\(CurrencyFormatter.string(spent, currency: currency)) / \(CurrencyFormatter.compact(budget.amount))")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkSecondary)
            }

            FinanzashubProgressBar(progress: ratio, tint: barColor)
        }
    }
}

// MARK: - Suscripciones / Recurrentes

private struct FinanzashubRecurringSection: View {
    let events: [RecurringEvent]
    let resolveCategory: (String?) -> Category?
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinanzashubSectionHeader(title: "Suscripciones", route: .recurring)

            if events.isEmpty {
                FinanzashubEmptyCard(
                    icon: "repeat",
                    tint: Palette.purple,
                    text: "Sin pagos recurrentes."
                )
            } else {
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            FinanzashubRecurringRow(
                                event: event,
                                category: resolveCategory(event.categoryId),
                                index: index,
                                currency: currency
                            )

                            if index < events.count - 1 {
                                Divider().overlay(Palette.stroke)
                                    .padding(.leading, 40 + Space.m)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct FinanzashubRecurringRow: View {
    let event: RecurringEvent
    let category: Category?
    let index: Int
    let currency: String

    // Slug de logo derivado del nombre del evento (Spotify, Netflix, …).
    private var logo: Image? { SubscriptionLogo.image(for: FinanzashubLogo.slug(for: event.name)) }
    private var tint: Color { FinanzashubHex.color(category?.color, fallbackIndex: index) }
    private var symbol: String { IconMapping.sfSymbol(for: category?.icon ?? "repeat") }

    var body: some View {
        HStack(spacing: Space.m) {
            // Logo de la app si lo tenemos; si no, ícono de categoría en círculo.
            if let logo {
                logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .frame(width: 40, height: 40)
                    .background(Palette.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
            } else {
                CategoryIcon(systemName: symbol, color: tint, size: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("\(event.frequency.label) • Próximo: \(FinanzashubDate.short(event.nextDate))")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s)

            Text(CurrencyFormatter.string(event.amount, currency: currency))
                .font(Typo.amount)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .padding(.vertical, Space.s)
        .contentShape(Rectangle())
    }
}

// MARK: - Barra de progreso reutilizable del hub

private struct FinanzashubProgressBar: View {
    var progress: Double
    var tint: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0, min(1, progress))
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceElevated)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, geo.size.width * clamped))
                    .animation(Motion.value, value: clamped)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Tarjeta de estado vacío del hub

private struct FinanzashubEmptyCard: View {
    let icon: String
    let tint: Color
    let text: String

    var body: some View {
        Card {
            HStack(spacing: Space.m) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                Text(text)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Helpers privados del hub (nombres únicos para evitar colisiones)

/// Cálculo de gasto por presupuesto y color de riesgo. Réplica local para el hub.
private enum FinanzashubMath {
    static func spent(for budget: Budget, in transactions: [Transaction]) -> Double {
        let prefix = String(ISO8601DateFormatter().string(from: Date()).prefix(budget.period == .weekly ? 10 : 7))
        return transactions
            .filter { tx in
                tx.type == .expense
                && tx.categoryId == budget.categoryId
                && matches(date: tx.date, period: budget.period, prefix: prefix)
            }
            .reduce(0) { $0 + $1.amount }
    }

    static func color(for ratio: Double) -> Color {
        switch ratio {
        case ..<0.7: return Palette.green
        case ..<0.9: return Palette.amber
        default: return Palette.pink
        }
    }

    private static func matches(date: String, period: BudgetPeriod, prefix: String) -> Bool {
        switch period {
        case .monthly:
            return date.hasPrefix(prefix)
        case .weekly:
            return sameWeek(date)
        }
    }

    private static func sameWeek(_ dateString: String) -> Bool {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        guard let date = iso.date(from: String(dateString.prefix(10))) else { return false }
        let cal = Calendar(identifier: .iso8601)
        return cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

/// Parseo de color hex del backend ("#RRGGBB" / "RRGGBB") con fallback estable.
private enum FinanzashubHex {
    static func color(_ hex: String?, fallbackIndex: Int) -> Color {
        parse(hex) ?? Palette.categoryColor(for: fallbackIndex)
    }

    static func color(_ hex: String?, fallbackFor id: String) -> Color {
        parse(hex) ?? Palette.categoryColor(for: abs(id.hashValue))
    }

    static func parse(_ hex: String?) -> Color? {
        guard var s = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s.removeFirst(2) }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let value = UInt(s, radix: 16) else { return nil }
        return Color(hex: value)
    }
}

/// Fecha corta "d MMM" en español para deadlines y próximos pagos.
private enum FinanzashubDate {
    static func short(_ raw: String) -> String {
        guard let date = parse(raw) else { return raw }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        let cal = Calendar.current
        f.dateFormat = cal.component(.year, from: date) == cal.component(.year, from: Date())
            ? "d 'de' MMM" : "d MMM yyyy"
        return f.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private static func parse(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        df.dateFormat = "yyyy-MM-dd"
        if raw.count >= 10 { return df.date(from: String(raw.prefix(10))) }
        return nil
    }
}

/// Deriva el slug de logo de suscripción a partir del nombre del evento
/// recurrente (ej. "Spotify Premium" → "spotify"), comparando contra el catálogo.
private enum FinanzashubLogo {
    static func slug(for name: String) -> String? {
        let n = name
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return nil }

        // Coincidencia por palabra clave: el slug (sin guiones) contenido en el nombre.
        for slug in SubscriptionLogo.all {
            let key = slug.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespaces)
            guard key.count >= 2 else { continue }
            if n.contains(key) { return slug }
        }
        return nil
    }
}
