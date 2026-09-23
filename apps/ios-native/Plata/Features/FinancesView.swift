import SwiftUI

// Hub de finanzas (era la tab "finances" de la app RN). Centro de navegación de
// todo lo que no es dashboard ni transacciones: cuentas, deudas, metas de ahorro,
// presupuestos, suscripciones/recurrentes y listas de compra.
//
// Rediseño FLAT (Monarch/YNAB): NADA de cards. Título grande "Finanzas", y cada
// bloque es una sección plana (header overline + "Ver todas" + "+") con filas
// separadas por hairlines. La jerarquía se construye con tipografía y espaciado,
// no con contenedores. Progreso siempre inline y legible.
//
// Datos desde app.* (accounts, debts, goals, budgets, recurringEvents,
// shoppingLists, transactions, categories). Sin red aquí.

struct FinancesView: View {
    @Environment(AppState.self) private var app

    @State private var showingAddAccount = false
    @State private var showingAddDebt = false
    @State private var showingAddGoal = false
    @State private var showingAddBudget = false
    @State private var showingAddRecurring = false
    @State private var showingAddShopping = false
    @State private var selectedRecurring: RecurringEvent?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                // Título grande, tracking negativo sutil.
                Text("Finanzas")
                    .font(Typo.titleXL)
                    .tracking(-0.6)
                    .foregroundStyle(Palette.ink)
                    .padding(.bottom, Space.xs)

                FinHubAccountsSection(
                    accounts: app.accounts,
                    total: app.totalBalance,
                    currency: app.currency,
                    onAdd: { showingAddAccount = true }
                )

                FinHubDebtsSection(
                    debts: app.debts.filter { $0.status == .active },
                    currency: app.currency,
                    onAdd: { showingAddDebt = true }
                )

                FinHubGoalsSection(
                    goals: app.goals.filter { $0.status == .active },
                    currency: app.currency,
                    onAdd: { showingAddGoal = true }
                )

                FinHubBudgetsSection(
                    budgets: app.budgets,
                    resolveCategory: { app.category(for: $0) },
                    spent: { FinHubMath.spent(for: $0, in: app.transactions) },
                    currency: app.currency,
                    onAdd: { showingAddBudget = true }
                )

                FinHubRecurringSection(
                    events: app.recurringEvents.filter { $0.isActive },
                    resolveCategory: { app.category(for: $0) },
                    currency: app.currency,
                    onSelect: { selectedRecurring = $0 },
                    onAdd: { showingAddRecurring = true }
                )

                FinHubShoppingSection(
                    lists: app.shoppingLists.filter { $0.status != .completed },
                    onAdd: { showingAddShopping = true }
                )

                FinHubWishesSection()
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.l)
        }
        .floatingTabBarInset()
        .background(Palette.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SavingsGoal.self) { GoalDetailView(goal: $0) }
        .navigationDestination(for: ShoppingList.self) { ShoppingListDetailView(list: $0) }
        .navigationDestination(for: FinHubRoute.self) { route in
            switch route {
            case .accounts: AccountsView()
            case .debts: DebtsView()
            case .goals: GoalsView()
            case .shopping: ShoppingView()
            case .budgets: BudgetsView()
            case .recurring: RecurringView()
            case .wishes: WishlistView()
            }
        }
        .sheet(isPresented: $showingAddAccount) { AddAccountView() }
        .sheet(isPresented: $showingAddDebt) { AddDebtView() }
        .sheet(isPresented: $showingAddGoal) { AddGoalView() }
        .sheet(isPresented: $showingAddBudget) { AddBudgetView() }
        .sheet(isPresented: $showingAddRecurring) { AddRecurringView() }
        .sheet(isPresented: $showingAddShopping) { AddShoppingListView() }
        .sheet(item: $selectedRecurring) { ev in
            NavigationStack { RecurringDetailView(event: ev, asSheet: true) }
        }
    }
}

// MARK: - Rutas de sección (vistas de lista completas)

private enum FinHubRoute: Hashable {
    case accounts, debts, goals, shopping, budgets, recurring, wishes
}

// MARK: - Encabezado de sección plano (label + "ver todas" + "+")

private struct FinHubHeader: View {
    let title: String
    var route: FinHubRoute? = nil
    var addAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: Space.s) {
            Text(title.uppercased())
                .font(Typo.overline)
                .tracking(0.8)
                .foregroundStyle(Palette.inkTertiary)

            Spacer(minLength: Space.s)

            if let route {
                NavigationLink(value: route) {
                    Text("Ver todas")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
                .pressable(scale: 0.96)
            }

            if let addAction {
                Button(action: addAction) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 26, height: 26)
                        .background(Palette.accent.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .pressable(scale: 0.94)
                .accessibilityLabel("Añadir \(title)")
            }
        }
    }
}

// MARK: - Estado vacío plano (sin card)

private struct FinHubEmptyRow: View {
    let icon: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(text)
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Space.s)
    }
}

// MARK: - Cuentas

private struct FinHubAccountsSection: View {
    let accounts: [Account]
    let total: Double
    let currency: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinHubHeader(title: "Cuentas", route: .accounts, addAction: onAdd)

            if accounts.isEmpty {
                FinHubEmptyRow(icon: "creditcard", tint: Palette.sky,
                               text: "Sin cuentas todavía. Usa el “+” para crear una.")
            } else {
                VStack(spacing: 0) {
                    // Balance total como fila destacada arriba.
                    HStack(alignment: .firstTextBaseline) {
                        Text("Balance total")
                            .font(Typo.headline)
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: Space.s)
                        AmountText(amount: total, currency: currency, font: Typo.amountMedium)
                    }
                    .padding(.vertical, Space.m)

                    RowDivider()

                    PlainList(accounts, dividerInset: 40 + Space.m) { account in
                        NavigationLink(value: FinHubRoute.accounts) {
                            FinHubAccountRow(account: account, currency: currency)
                        }
                        .buttonStyle(.plain)
                        .pressable()
                    }
                }
            }
        }
    }
}

private struct FinHubAccountRow: View {
    let account: Account
    let currency: String

    private var tint: Color { FinHubHex.color(account.color, fallbackFor: account.id) }

    var body: some View {
        HStack(spacing: Space.m) {
            RowLeadingIcon(systemName: account.type.sfSymbol, color: tint, size: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(account.name)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(account.type.label)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s)

            AmountText(amount: account.balance, currency: currency, font: Typo.amount)
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Deudas (Nos deben / Debemos)

private struct FinHubDebtsSection: View {
    let debts: [Debt]
    let currency: String
    let onAdd: () -> Void

    private var owedToUs: [Debt] { debts.filter { $0.direction == .owedToUs } }
    private var weOwe: [Debt] { debts.filter { $0.direction == .weOwe } }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinHubHeader(title: "Deudas", route: .debts, addAction: onAdd)

            if debts.isEmpty {
                FinHubEmptyRow(icon: "hand.thumbsup.fill", tint: Palette.green,
                               text: "Sin deudas registradas. Todo en paz.")
            } else {
                VStack(alignment: .leading, spacing: Space.l) {
                    if !owedToUs.isEmpty {
                        FinHubDebtGroup(
                            label: "Nos deben",
                            debts: owedToUs,
                            tint: Palette.green,
                            positive: true,
                            currency: currency
                        )
                    }
                    if !weOwe.isEmpty {
                        FinHubDebtGroup(
                            label: "Debemos",
                            debts: weOwe,
                            tint: Palette.pink,
                            positive: false,
                            currency: currency
                        )
                    }
                }
            }
        }
    }
}

private struct FinHubDebtGroup: View {
    let label: String
    let debts: [Debt]
    let tint: Color
    let positive: Bool
    let currency: String

    private var total: Double { debts.reduce(0) { $0 + $1.remaining } }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            // Etiqueta de subsección con total al lado, en el color de la dirección.
            HStack(spacing: Space.s) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                Text(label)
                    .font(Typo.caption)
                    .tracking(0.4)
                    .foregroundStyle(tint)
                Spacer(minLength: Space.s)
                Text((positive ? "+" : "−") + CurrencyFormatter.string(total, currency: currency))
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
            .padding(.top, Space.xs)

            PlainList(debts, dividerInset: 0) { debt in
                NavigationLink(value: FinHubRoute.debts) {
                    FinHubDebtRow(debt: debt, tint: tint, positive: positive, currency: currency)
                }
                .buttonStyle(.plain)
                .pressable()
            }
        }
    }
}

private struct FinHubDebtRow: View {
    let debt: Debt
    let tint: Color
    let positive: Bool
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(debt.personName.isEmpty ? "Sin nombre" : debt.personName)
                        .font(Typo.headline)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if let note = debt.description, !note.isEmpty {
                        Text(note)
                            .font(Typo.subhead)
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: Space.s)

                VStack(alignment: .trailing, spacing: 1) {
                    Text((positive ? "+" : "−") + CurrencyFormatter.string(debt.remaining, currency: currency))
                        .font(Typo.amount)
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    Text("de \(CurrencyFormatter.compact(debt.amount))")
                        .font(Typo.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkTertiary)
                }
            }

            // Progreso inline delgado + porcentaje, muy legible.
            HStack(spacing: Space.s) {
                FinHubProgressBar(progress: debt.progress, tint: tint, height: 5)
                Text("\(Int((debt.progress * 100).rounded())) %")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Metas de ahorro

private struct FinHubGoalsSection: View {
    let goals: [SavingsGoal]
    let currency: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinHubHeader(title: "Metas", route: .goals, addAction: onAdd)

            if goals.isEmpty {
                FinHubEmptyRow(icon: "target", tint: Palette.accent,
                               text: "Sin metas de ahorro todavía.")
            } else {
                PlainList(goals, dividerInset: 44 + Space.m) { goal in
                    NavigationLink(value: goal) {
                        FinHubGoalRow(goal: goal, currency: currency)
                    }
                    .buttonStyle(.plain)
                    .pressable()
                }
            }
        }
    }
}

private struct FinHubGoalRow: View {
    let goal: SavingsGoal
    let currency: String

    private var tint: Color { FinHubHex.color(goal.color, fallbackFor: goal.id) }
    private var symbol: String {
        goal.icon.contains(".") ? goal.icon : IconMapping.sfSymbol(for: goal.icon)
    }

    var body: some View {
        HStack(spacing: Space.m) {
            ZStack {
                ProgressRing(progress: goal.progress, color: tint, lineWidth: 4, size: 44)
                Text("\(Int((goal.progress * 100).rounded()))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(goal.name)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s)

            VStack(alignment: .trailing, spacing: 1) {
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
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        if let deadline = goal.deadline, !deadline.isEmpty {
            return "Objetivo: \(FinHubDate.short(deadline))"
        }
        return "Ahorro libre"
    }
}

// MARK: - Presupuestos

private struct FinHubBudgetsSection: View {
    let budgets: [Budget]
    let resolveCategory: (String?) -> Category?
    let spent: (Budget) -> Double
    let currency: String
    let onAdd: () -> Void

    private var totalSpent: Double { budgets.reduce(0) { $0 + spent($1) } }
    private var totalLimit: Double { budgets.reduce(0) { $0 + $1.amount } }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinHubHeader(title: "Presupuestos", route: .budgets, addAction: onAdd)

            if budgets.isEmpty {
                FinHubEmptyRow(icon: "chart.pie.fill", tint: Palette.amber,
                               text: "Sin presupuestos este mes.")
            } else {
                VStack(spacing: 0) {
                    // Resumen del mes como fila destacada arriba.
                    VStack(alignment: .leading, spacing: Space.s) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Gasto del mes")
                                .font(Typo.headline)
                                .foregroundStyle(Palette.ink)
                            Spacer(minLength: Space.s)
                            Text("\(CurrencyFormatter.string(totalSpent, currency: currency)) / \(CurrencyFormatter.compact(totalLimit))")
                                .font(Typo.subhead)
                                .monospacedDigit()
                                .foregroundStyle(Palette.inkSecondary)
                        }
                        FinHubProgressBar(
                            progress: totalLimit > 0 ? totalSpent / totalLimit : 0,
                            tint: FinHubMath.color(for: totalLimit > 0 ? totalSpent / totalLimit : 0),
                            height: 6
                        )
                    }
                    .padding(.vertical, Space.m)

                    RowDivider()

                    PlainList(budgets, dividerInset: 0) { budget in
                        NavigationLink(value: FinHubRoute.budgets) {
                            FinHubBudgetRow(
                                budget: budget,
                                category: resolveCategory(budget.categoryId),
                                spent: spent(budget),
                                currency: currency
                            )
                        }
                        .buttonStyle(.plain)
                        .pressable()
                    }
                }
            }
        }
    }
}

private struct FinHubBudgetRow: View {
    let budget: Budget
    let category: Category?
    let spent: Double
    let currency: String

    private var ratio: Double { budget.amount > 0 ? spent / budget.amount : 0 }
    private var tint: Color { FinHubHex.color(category?.color, fallbackFor: budget.id) }
    private var barColor: Color { FinHubMath.color(for: ratio) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                Image(systemName: IconMapping.sfSymbol(for: category?.icon))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22)
                Text(category?.name ?? "Sin categoría")
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: Space.s)
                Text("\(CurrencyFormatter.string(spent, currency: currency)) / \(CurrencyFormatter.compact(budget.amount))")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkSecondary)
            }

            HStack(spacing: Space.s) {
                FinHubProgressBar(progress: ratio, tint: barColor, height: 5)
                    .padding(.leading, 22 + Space.s)
                Text("\(Int((min(1, ratio) * 100).rounded())) %")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Suscripciones / Recurrentes

private struct FinHubRecurringSection: View {
    let events: [RecurringEvent]
    let resolveCategory: (String?) -> Category?
    let currency: String
    let onSelect: (RecurringEvent) -> Void
    let onAdd: () -> Void

    // Total mensual normalizado (todas las frecuencias a base mensual).
    private var monthlyTotal: Double {
        events.reduce(0) { $0 + FinHubMath.monthlyEquivalent(event: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinHubHeader(title: "Suscripciones", route: .recurring, addAction: onAdd)

            if events.isEmpty {
                FinHubEmptyRow(icon: "repeat", tint: Palette.purple,
                               text: "Sin pagos recurrentes.")
            } else {
                VStack(spacing: 0) {
                    // Total mensual como fila destacada arriba.
                    HStack(alignment: .firstTextBaseline) {
                        Text("Total mensual")
                            .font(Typo.headline)
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: Space.s)
                        AmountText(amount: monthlyTotal, currency: currency, font: Typo.amountMedium)
                    }
                    .padding(.vertical, Space.m)

                    RowDivider()

                    PlainList(events, dividerInset: 40 + Space.m) { event in
                        Button {
                            onSelect(event)
                        } label: {
                            FinHubRecurringRow(
                                event: event,
                                category: resolveCategory(event.categoryId),
                                currency: currency
                            )
                        }
                        .buttonStyle(.plain)
                        .pressable()
                    }
                }
            }
        }
    }
}

private struct FinHubRecurringRow: View {
    let event: RecurringEvent
    let category: Category?
    let currency: String

    // Prioriza el logo real guardado; si no, deriva del nombre; si no, ícono.
    private var logo: Image? {
        SubscriptionLogo.imageForStoredId(event.logoId)
            ?? SubscriptionLogo.image(for: FinHubLogo.slug(for: event.name))
    }
    private var tint: Color { FinHubHex.color(category?.color, fallbackFor: event.id) }
    private var symbol: String { IconMapping.sfSymbol(for: category?.icon ?? "repeat") }

    var body: some View {
        HStack(spacing: Space.m) {
            RowLeadingIcon(logo: logo, categoryIcon: CategoryIconAsset.image(forSlug: category?.icon), systemName: symbol, color: tint, size: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.name)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("\(event.frequency.label) • \(FinHubDate.short(event.nextDate))")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s)

            AmountText(amount: event.amount, currency: currency, font: Typo.amount)
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Listas de compra

private struct FinHubShoppingSection: View {
    let lists: [ShoppingList]
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinHubHeader(title: "Listas de compra", route: .shopping, addAction: onAdd)

            if lists.isEmpty {
                FinHubEmptyRow(icon: "cart", tint: Palette.sky,
                               text: "Sin listas de compra activas.")
            } else {
                PlainList(lists, dividerInset: 40 + Space.m) { list in
                    NavigationLink(value: list) {
                        FinHubShoppingRow(list: list)
                    }
                    .buttonStyle(.plain)
                    .pressable()
                }
            }
        }
    }
}

private struct FinHubShoppingRow: View {
    let list: ShoppingList

    private var tint: Color { ShoppingStatusStyle.tint(for: list.status) }

    var body: some View {
        HStack(spacing: Space.m) {
            RowLeadingIcon(systemName: "cart.fill", color: tint, size: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(list.name)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        ShoppingStatusStyle.label(for: list.status)
            + ((list.store?.isEmpty == false) ? " • \(list.store!)" : "")
    }
}

// MARK: - Lista de deseos (Dreamboard)

private struct FinHubWishesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FinHubHeader(title: "Lista de deseos", route: .wishes)

            NavigationLink(value: FinHubRoute.wishes) {
                HStack(spacing: Space.m) {
                    RowLeadingIcon(systemName: "sparkles", color: Palette.accent, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tableros de deseos")
                            .font(Typo.headline)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text("Neveras, muebles, viajes… con foto, precio y link")
                            .font(Typo.subhead)
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: Space.s)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                }
                .padding(.vertical, Space.m)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pressable()
        }
    }
}

// MARK: - Barra de progreso inline (plana, delgada)

private struct FinHubProgressBar: View {
    var progress: Double
    var tint: Color
    var height: CGFloat = 5

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

// MARK: - Helpers privados del hub (nombres únicos)

/// Cálculo de gasto por presupuesto, color de riesgo y normalización mensual.
private enum FinHubMath {
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

    /// Aproxima el costo mensual de un evento recurrente según su frecuencia.
    static func monthlyEquivalent(event: RecurringEvent) -> Double {
        switch event.frequency {
        case .daily: return event.amount * 30
        case .weekly: return event.amount * 52 / 12
        case .biweekly: return event.amount * 2
        case .monthly: return event.amount
        case .yearly: return event.amount / 12
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
        guard iso.date(from: String(dateString.prefix(10))) != nil else { return false }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: String(dateString.prefix(10))) else { return false }
        let cal = Calendar(identifier: .iso8601)
        return cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

/// Parseo de color hex del backend ("#RRGGBB" / "RRGGBB") con fallback estable.
private enum FinHubHex {
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
private enum FinHubDate {
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

/// Deriva el slug de logo de suscripción a partir del nombre del evento.
private enum FinHubLogo {
    static func slug(for name: String) -> String? {
        // Se normaliza quitando tildes, espacios y guiones para que "Apple Music"
        // matchee el slug "apple-music" (antes el espacio rompía el contains).
        let n = name
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return nil }
        for slug in SubscriptionLogo.all {
            let key = slug.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespaces)
            guard key.count >= 2 else { continue }
            if n.contains(key) { return slug }
        }
        return nil
    }
}
