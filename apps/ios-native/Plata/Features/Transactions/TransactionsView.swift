import SwiftUI

// Lista de movimientos agrupada por fecha. Header custom con título grande
// "Movimientos" y buscador limpio debajo (sin el espacio fantasma del
// navigationTitle .large + .searchable). Arriba de la lista, dos tarjetas de
// "highlights" del mes: total gastado (con % vs mes anterior) y mayor gasto por
// categoría. Cada fila reutiliza CategoryIcon + AmountText del design system.

struct TransactionsView: View {
    @Environment(AppState.self) private var app

    @State private var query = ""
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    TransactionsHeader(query: $query) { showingAdd = true }

                    content
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxxl)
            }
            .background(Palette.bg.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            // Sin navigation bar: el título vive en el header custom, así se
            // elimina el espacio fantasma sobre el buscador.
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Palette.accent)
        .sheet(isPresented: $showingAdd) {
            AddTransactionView()
        }
    }

    // MARK: - Contenido según estado

    @ViewBuilder
    private var content: some View {
        if app.transactions.isEmpty {
            TransactionsEmptyState { showingAdd = true }
                .padding(.top, Space.xxxl)
        } else if isSearching {
            // Buscando: solo la lista de resultados (los highlights estorbarían).
            if filtered.isEmpty {
                TransactionsNoResults(query: query)
                    .padding(.top, Space.xxxl)
            } else {
                transactionList
            }
        } else {
            monthHighlights
            transactionList
        }
    }

    // MARK: - Highlights del mes

    @ViewBuilder
    private var monthHighlights: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel(text: "Este mes")

            HStack(alignment: .top, spacing: Space.m) {
                MonthSpentCard(
                    total: monthExpenseTotal,
                    delta: expenseDeltaPercent,
                    currency: app.currency
                )
                TopCategoryCard(
                    highlight: topCategory,
                    currency: app.currency
                )
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Lista

    private var transactionList: some View {
        LazyVStack(alignment: .leading, spacing: Space.xl) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack {
                        Text(group.title)
                            .font(Typo.overline)
                            .tracking(0.8)
                            .foregroundStyle(Palette.inkTertiary)
                        Spacer()
                        AmountText(
                            amount: group.net,
                            currency: app.currency,
                            font: Typo.caption,
                            signed: true,
                            tintBySign: true
                        )
                    }
                    .padding(.horizontal, Space.xs)

                    VStack(spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, tx in
                            NavigationLink {
                                TransactionDetailView(transaction: tx)
                            } label: {
                                TransactionRow(transaction: tx)
                            }
                            .buttonStyle(.plain)
                            .pressable()
                            if index < group.items.count - 1 {
                                Divider()
                                    .overlay(Palette.stroke)
                                    .padding(.leading, 44 + Space.m + Space.l)
                            }
                        }
                    }
                    .background(
                        Palette.surface,
                        in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                            .strokeBorder(Palette.stroke, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Datos derivados

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var filtered: [Transaction] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return app.transactions }
        return app.transactions.filter { tx in
            if let d = tx.description?.lowercased(), d.contains(q) { return true }
            if let cat = app.category(for: tx.categoryId)?.name.lowercased(), cat.contains(q) { return true }
            if let acc = account(for: tx)?.name.lowercased(), acc.contains(q) { return true }
            return false
        }
    }

    private func account(for tx: Transaction) -> Account? {
        app.accounts.first { $0.id == tx.accountId }
    }

    /// Agrupa por prefijo YYYY-MM-DD y ordena por fecha descendente.
    private var groups: [TransactionDayGroup] {
        let grouped = Dictionary(grouping: filtered) { String($0.date.prefix(10)) }
        return grouped
            .map { key, items in
                TransactionDayGroup(
                    id: key,
                    title: TransactionDateFormat.header(for: key),
                    net: items.reduce(0.0) { $0 + ($1.type == .income ? $1.amount : -$1.amount) },
                    items: items
                )
            }
            .sorted { $0.id > $1.id }
    }

    // Prefijo YYYY-MM del mes actual y del anterior, en hora local.
    private var currentMonthPrefix: String { TransactionMonth.prefix(monthsAgo: 0) }
    private var previousMonthPrefix: String { TransactionMonth.prefix(monthsAgo: 1) }

    /// Gasto total (expense) del mes en curso.
    private var monthExpenseTotal: Double {
        app.transactions
            .filter { $0.type == .expense && $0.date.hasPrefix(currentMonthPrefix) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Gasto total del mes anterior (para el %).
    private var previousMonthExpenseTotal: Double {
        app.transactions
            .filter { $0.type == .expense && $0.date.hasPrefix(previousMonthPrefix) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Variación % del gasto vs mes anterior. Nil si el mes anterior fue 0
    /// (no hay base para comparar → no inventamos un porcentaje).
    private var expenseDeltaPercent: Double? {
        let prev = previousMonthExpenseTotal
        guard prev > 0 else { return nil }
        return (monthExpenseTotal - prev) / prev * 100
    }

    /// Categoría con más gasto este mes: agrupa los expense por categoryId.
    private var topCategory: TopCategoryHighlight? {
        let expenses = app.transactions.filter {
            $0.type == .expense && $0.date.hasPrefix(currentMonthPrefix)
        }
        guard !expenses.isEmpty else { return nil }

        let totals = Dictionary(grouping: expenses, by: { $0.categoryId })
            .mapValues { $0.reduce(0.0) { $0 + $1.amount } }

        guard let (categoryId, amount) = totals.max(by: { $0.value < $1.value }) else {
            return nil
        }
        return TopCategoryHighlight(
            category: app.category(for: categoryId),
            amount: amount
        )
    }
}

// MARK: - Modelos derivados (privados del feature)

private struct TransactionDayGroup: Identifiable {
    let id: String        // YYYY-MM-DD
    let title: String
    let net: Double
    let items: [Transaction]
}

private struct TopCategoryHighlight {
    let category: Category?
    let amount: Double
}

// MARK: - Header custom (título grande + buscador limpio)

private struct TransactionsHeader: View {
    @Binding var query: String
    var onAdd: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack(alignment: .firstTextBaseline) {
                Text("Movimientos")
                    .font(Typo.titleXL)
                    .tracking(-0.6) // tracking negativo sutil en título grande
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: Space.m)
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.bg)
                        .frame(width: 36, height: 36)
                        .background(Palette.ink, in: Circle())
                }
                .buttonStyle(.plain)
                .pressable(scale: 0.94)
                // Alinea el círculo con la baseline del título grande.
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
            }

            TransactionsSearchField(query: $query, focused: $searchFocused)
        }
    }
}

private struct TransactionsSearchField: View {
    @Binding var query: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)

            TextField("Buscar movimiento", text: $query)
                .font(Typo.body)
                .foregroundStyle(Palette.ink)
                .tint(Palette.accent)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(focused)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, Space.m)
        .frame(height: 44)
        .liquidGlassCapsule()
        .overlay(
            Capsule().strokeBorder(Palette.stroke.opacity(0.6), lineWidth: 1)
        )
        .animation(Motion.ui, value: query.isEmpty)
    }
}

// MARK: - Tarjetas de highlights del mes

/// "Total gastado" este mes, con la variación % vs el mes anterior si existe.
private struct MonthSpentCard: View {
    let total: Double
    let delta: Double?          // % vs mes anterior; nil si no comparable
    let currency: String

    var body: some View {
        Card(padding: Space.l) {
            VStack(alignment: .leading, spacing: Space.s) {
                Label {
                    Text("Total gastado")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkSecondary)
                } icon: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.negative)
                }
                .labelStyle(.titleAndIcon)

                Text(CurrencyFormatter.string(total, currency: currency))
                    .font(Typo.amountMedium)
                    .tracking(-0.5)
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                deltaBadge
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var deltaBadge: some View {
        if let delta {
            let up = delta >= 0
            // Gastar más = negativo (rojo), gastar menos = positivo (verde).
            let tint = up ? Palette.negative : Palette.positive
            HStack(spacing: 3) {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                Text("\(abs(delta), specifier: "%.0f")% vs mes anterior")
                    .font(Typo.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        } else {
            Text("Primer mes con registros")
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// "Mayor gasto" del mes: categoría con más gasto, con su ícono, color y monto.
private struct TopCategoryCard: View {
    let highlight: TopCategoryHighlight?
    let currency: String

    var body: some View {
        Card(padding: Space.l) {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Mayor gasto")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkSecondary)

                if let highlight {
                    HStack(spacing: Space.s) {
                        CategoryIcon(systemName: icon(for: highlight), color: color(for: highlight), size: 30)
                        Text(name(for: highlight))
                            .font(Typo.callout)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Text(CurrencyFormatter.string(highlight.amount, currency: currency))
                        .font(Typo.amount)
                        .tracking(-0.3)
                        .foregroundStyle(color(for: highlight))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("Sin gastos aún")
                        .font(Typo.callout)
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Space.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func name(for highlight: TopCategoryHighlight) -> String {
        highlight.category?.name ?? "Sin categoría"
    }

    private func color(for highlight: TopCategoryHighlight) -> Color {
        TransactionVisual.color(for: highlight.category)
    }

    private func icon(for highlight: TopCategoryHighlight) -> String {
        TransactionVisual.symbol(for: highlight.category, fallbackType: .expense)
    }
}

// MARK: - Fila

private struct TransactionRow: View {
    @Environment(AppState.self) private var app
    let transaction: Transaction

    var body: some View {
        HStack(spacing: Space.m) {
            CategoryIcon(systemName: icon, color: color, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s)

            AmountText(
                amount: signedAmount,
                currency: app.currency,
                font: Typo.amount,
                signed: true,
                tintBySign: true
            )
        }
        .padding(Space.l)
        .contentShape(Rectangle())
    }

    private var category: Category? { app.category(for: transaction.categoryId) }

    private var title: String {
        if let desc = transaction.description, !desc.isEmpty { return desc }
        if let name = category?.name { return name }
        return transaction.type.label
    }

    private var subtitle: String {
        let accountName = app.accounts.first { $0.id == transaction.accountId }?.name
        if let name = category?.name, transaction.description?.isEmpty == false {
            // Título ya es la descripción → subtítulo muestra categoría · cuenta.
            if let acc = accountName { return "\(name) · \(acc)" }
            return name
        }
        return accountName ?? transaction.type.label
    }

    private var signedAmount: Double {
        transaction.type == .income ? transaction.amount : -transaction.amount
    }

    private var color: Color {
        TransactionVisual.color(for: category)
    }

    private var icon: String {
        TransactionVisual.symbol(for: category, fallbackType: transaction.type)
    }
}

// MARK: - Estados vacíos

private struct TransactionsEmptyState: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: Space.l) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 84, height: 84)
                .background(Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))

            VStack(spacing: Space.xs) {
                Text("Aún no hay movimientos")
                    .font(Typo.title)
                    .foregroundStyle(Palette.ink)
                Text("Registra tu primer ingreso o gasto para empezar a llevar las cuentas juntos.")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xl)
            }

            PrimaryButton(title: "Agregar movimiento", icon: "plus", action: onAdd)
                .frame(maxWidth: 260)
                .padding(.top, Space.s)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity)
    }
}

private struct TransactionsNoResults: View {
    let query: String

    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(Palette.inkTertiary)
            Text("Sin resultados")
                .font(Typo.headline)
                .foregroundStyle(Palette.ink)
            Text("No encontramos movimientos para «\(query)».")
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Prefijo de mes local (privado del feature)

enum TransactionMonth {
    /// Prefijo "YYYY-MM" para el mes actual (monthsAgo: 0) o anteriores, en la
    /// zona horaria local — evita el desfase de UTC de ISO8601DateFormatter.
    static func prefix(monthsAgo: Int) -> String {
        let cal = Calendar.current
        let base = cal.date(byAdding: .month, value: -monthsAgo, to: Date()) ?? Date()
        let comps = cal.dateComponents([.year, .month], from: base)
        let year = comps.year ?? 2000
        let month = comps.month ?? 1
        return String(format: "%04d-%02d", year, month)
    }
}

// MARK: - Formato de fecha (privado del feature)

enum TransactionDateFormat {
    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let display: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.dateFormat = "d 'de' MMMM"
        return f
    }()

    private static let displayWithYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.dateFormat = "d 'de' MMMM, yyyy"
        return f
    }()

    /// "Hoy" / "Ayer" / "12 de septiembre" (o con año si es otro año).
    static func header(for key: String) -> String {
        guard let date = parser.date(from: key) else { return key }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Hoy" }
        if cal.isDateInYesterday(date) { return "Ayer" }
        let sameYear = cal.component(.year, from: date) == cal.component(.year, from: Date())
        let text = (sameYear ? display : displayWithYear).string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

// MARK: - Resolución de color/ícono de categoría (compartido con Add)

enum TransactionVisual {
    /// Color de la categoría: parsea su hex ("#RRGGBB") o cae en la rueda.
    static func color(for category: Category?) -> Color {
        guard let category else { return Palette.inkSecondary }
        if let parsed = Color(hexString: category.color) { return parsed }
        return Palette.categoryColor(for: abs(category.id.hashValue))
    }

    /// SF Symbol para la categoría. Usa su `icon` si ya es un SF Symbol válido,
    /// si no lo mapea por nombre, con un fallback por tipo de transacción.
    static func symbol(for category: Category?, fallbackType: TransactionType) -> String {
        if let category {
            if isLikelySFSymbol(category.icon) { return category.icon }
            if let mapped = symbolByName(category.name) { return mapped }
            return category.type == .income ? "dollarsign.circle.fill" : "tag.fill"
        }
        switch fallbackType {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    private static func isLikelySFSymbol(_ raw: String) -> Bool {
        // Los nombres de SF Symbols son ascii en minúscula con puntos; los emojis
        // o strings vacíos no lo son.
        guard !raw.isEmpty else { return false }
        return raw.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." ) }
            && raw.contains(where: { $0.isLetter })
    }

    private static func symbolByName(_ name: String) -> String? {
        let n = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        for (keys, symbol) in mapping {
            if keys.contains(where: { n.contains($0) }) { return symbol }
        }
        return nil
    }

    private static let mapping: [(keys: [String], symbol: String)] = [
        (["aliment", "comida", "restaurante", "mercado"], "fork.knife"),
        (["transport", "carro", "auto", "gasolina", "uber", "taxi"], "car.fill"),
        (["vivienda", "arriendo", "renta", "hogar", "casa"], "house.fill"),
        (["salud", "medic", "farmacia"], "heart.fill"),
        (["entreten", "ocio", "cine", "streaming"], "tv.fill"),
        (["ropa", "vestuario"], "tshirt.fill"),
        (["educac", "estudio", "curso"], "book.fill"),
        (["salario", "sueldo", "nomina", "pago"], "dollarsign.circle.fill"),
        (["ahorro", "inversion"], "banknote.fill"),
        (["compra", "shopping"], "bag.fill"),
        (["servicio", "factura", "luz", "agua", "internet"], "bolt.fill"),
        (["regalo", "gift"], "gift.fill"),
        (["viaje", "vacacion"], "airplane"),
    ]
}

// MARK: - Parseo de color hex string ("#RRGGBB")

extension Color {
    /// Inicializa desde un string hex tipo "#818CF8" o "818CF8". Nil si inválido.
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        self.init(hex: UInt(value))
    }
}
