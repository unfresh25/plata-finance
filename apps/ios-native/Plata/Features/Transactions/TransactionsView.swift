import SwiftUI

// Lista de movimientos agrupada por fecha, completamente PLANA (sin cards),
// replicando el patrón del Dashboard. Header custom con título grande
// "Movimientos" + buscador limpio. Arriba, los "highlights" del mes como una
// fila de InlineStat (total gastado + mayor gasto), no tarjetas. Cada grupo de
// día es una sección plana (etiqueta del día + neto a la derecha) con filas
// idénticas al DashboardTransactionRow, separadas por hairlines.

struct TransactionsView: View {
    @Environment(AppState.self) private var app

    @State private var query = ""
    @State private var showingAdd = false
    // Movimiento pendiente de mostrar en detalle desde el long-press "Ver detalle".
    @State private var detailTarget: Transaction?
    // Movimiento pendiente de editar desde el long-press "Editar".
    @State private var editTarget: Transaction?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    TransactionsHeader(query: $query) { showingAdd = true }

                    content
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
            }
            .floatingTabBarInset()
            .background(Palette.bg.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            // Sin navigation bar: el título vive en el header custom, así se
            // elimina el espacio fantasma sobre el buscador.
            .toolbar(.hidden, for: .navigationBar)
            // Destino de detalle disparado desde el long-press "Ver detalle".
            .navigationDestination(item: $detailTarget) { tx in
                TransactionDetailView(transaction: tx)
            }
        }
        .tint(Palette.accent)
        .sheet(isPresented: $showingAdd) {
            AddTransactionView()
        }
        .sheet(item: $editTarget) { tx in
            // Edición real: reutiliza la pantalla de alta en modo edición.
            AddTransactionView(editing: tx)
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

    // MARK: - Highlights del mes (planos, sin cards)

    /// "Este mes" como una fila de datos alineados a la izquierda: total gastado
    /// (pink) y mayor gasto (con el logo/ícono de la categoría top + su monto).
    /// Nada en cards — pura tipografía + espacio, igual que el Dashboard.
    @ViewBuilder
    private var monthHighlights: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel(text: "Este mes")

            HStack(alignment: .top, spacing: Space.xxl) {
                InlineStat(
                    label: "Total gastado",
                    amount: monthExpenseTotal,
                    currency: app.currency,
                    tint: Palette.pink,
                    icon: "arrow.up.right"
                )
                TransactionsTopCategoryStat(
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
                    // Header plano del día: etiqueta ("Hoy"/"Ayer"/fecha) + neto del
                    // día a la derecha. Sin card — igual que una PlainSection.
                    HStack {
                        Text(group.title.uppercased())
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

                    // Lista plana con separadores hairline (no card). El divisor
                    // arranca tras el logo/ícono de 40 + gap para alinearse al texto.
                    PlainList(group.items, dividerInset: 40 + Space.m) { tx in
                        NavigationLink {
                            TransactionDetailView(transaction: tx)
                        } label: {
                            TransactionsFlatRow(
                                transaction: tx,
                                category: app.category(for: tx.categoryId),
                                account: account(for: tx),
                                currency: app.currency
                            )
                        }
                        .buttonStyle(.plain)
                        .pressable()
                        .contextMenu {
                            Button {
                                detailTarget = tx
                            } label: {
                                Label("Ver detalle", systemImage: "doc.text.magnifyingglass")
                            }
                            Button {
                                editTarget = tx
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                        }
                    }
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

    // Prefijo YYYY-MM del mes actual, en hora local.
    private var currentMonthPrefix: String { TransactionMonth.prefix(monthsAgo: 0) }

    /// Gasto total (expense) del mes en curso.
    private var monthExpenseTotal: Double {
        app.transactions
            .filter { $0.type == .expense && $0.date.hasPrefix(currentMonthPrefix) }
            .reduce(0) { $0 + $1.amount }
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

// MARK: - Highlight plano "Mayor gasto" del mes

/// "Mayor gasto" del mes como dato plano (sin card): logo/ícono de la categoría
/// top + su nombre y monto. Alineado a la izquierda, hermano del InlineStat.
private struct TransactionsTopCategoryStat: View {
    let highlight: TopCategoryHighlight?
    let currency: String

    var body: some View {
        // Misma estructura que InlineStat (label chico arriba + monto grande
        // abajo) para que "Total gastado" y "Mayor gasto" compartan línea base.
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Space.xs) {
                categoryGlyph
                Text(labelText)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            if let highlight {
                Text(CurrencyFormatter.string(highlight.amount, currency: currency))
                    .font(Typo.amount)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("—")
                    .font(Typo.amount)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }

    /// Label: "Mayor gasto" + nombre de la categoría top si existe.
    private var labelText: String {
        guard let name = highlight?.category?.name, !name.isEmpty else { return "Mayor gasto" }
        return "Mayor gasto · \(name)"
    }

    /// Glifo pequeño de la categoría (10px, tinte de su color), como el ícono
    /// del InlineStat de "Total gastado".
    @ViewBuilder
    private var categoryGlyph: some View {
        let tint = TransactionVisual.color(for: highlight?.category)
        if let icon = CategoryIconAsset.image(forSlug: highlight?.category?.icon) {
            icon
                .resizable()
                .scaledToFit()
                .frame(width: 11, height: 11)
                .foregroundStyle(tint)
        } else {
            Image(systemName: TransactionVisual.symbol(for: highlight?.category, fallbackType: .expense))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Fila plana (idéntica al DashboardTransactionRow)

/// Fila de movimiento plana: RowLeadingIcon (logo de app si aplica, si no ícono
/// de categoría en su color) + descripción/categoría·cuenta + monto con signo y
/// color. Sin card — vive dentro de una PlainList con hairlines.
private struct TransactionsFlatRow: View {
    let transaction: Transaction
    let category: Category?
    let account: Account?
    let currency: String

    var body: some View {
        PlainRow(
            leading: {
                RowLeadingIcon(
                    logo: logo,
                    categoryIcon: categoryIcon,
                    systemName: iconName,
                    color: tint,
                    size: 40
                )
            },
            title: title,
            subtitle: subtitle,
            trailing: {
                AmountText(
                    amount: signedAmount,
                    currency: currency,
                    font: Typo.amount,
                    signed: true,
                    tintBySign: true
                )
                .lineLimit(1)
            }
        )
    }

    /// Logo de app si la descripción coincide con una suscripción conocida
    /// (Netflix, Spotify…); si no, cae al ícono de categoría.
    private var logo: Image? {
        SubscriptionLogo.image(for: RecurrentesVisual.slug(for: transaction.description ?? ""))
    }

    /// Hugeicon real de la categoría (el mismo del picker legacy), teñible.
    private var categoryIcon: Image? {
        CategoryIconAsset.image(forSlug: category?.icon)
    }

    private var signedAmount: Double {
        transaction.type == .income ? abs(transaction.amount) : -abs(transaction.amount)
    }

    private var title: String {
        if let desc = transaction.description, !desc.isEmpty { return desc }
        if let category, !category.name.isEmpty { return category.name }
        return transaction.type.label
    }

    /// Subtítulo: categoría · cuenta (si el título ya es la descripción); si no,
    /// solo la cuenta o la etiqueta del tipo.
    private var subtitle: String {
        let accountName = account?.name
        if let category, !category.name.isEmpty,
           let desc = transaction.description, !desc.isEmpty {
            if let acc = accountName, !acc.isEmpty { return "\(category.name) · \(acc)" }
            return category.name
        }
        if let acc = accountName, !acc.isEmpty { return acc }
        return transaction.type.label
    }

    private var tint: Color {
        TransactionVisual.color(for: category)
    }

    private var iconName: String {
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

    /// SF Symbol para la categoría. La BD guarda íconos con slugs legacy
    /// (Ionicons/Hugeicons: "restaurant", "cart", "gift"…) que NO son SF Symbols
    /// válidos y renderizarían vacíos. Por eso se resuelven SIEMPRE por
    /// `IconMapping` (tabla ~430 slugs→SF Symbol con fallback), igual que el
    /// Calendario — nunca se usa `category.icon` crudo como systemName.
    static func symbol(for category: Category?, fallbackType: TransactionType) -> String {
        if let category {
            // Resuelve por el icon guardado; si viene vacío, por el nombre.
            let key = category.icon.isEmpty ? category.name : category.icon
            let resolved = IconMapping.sfSymbol(for: key)
            // Si IconMapping no reconoció nada (fallback genérico), intenta por el
            // nombre de la categoría antes de rendirse.
            if resolved == "circle.grid.2x2.fill", !category.name.isEmpty {
                let byName = IconMapping.sfSymbol(for: category.name)
                if byName != "circle.grid.2x2.fill" { return byName }
                return category.type == .income ? "dollarsign.circle.fill" : "tag.fill"
            }
            return resolved
        }
        switch fallbackType {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

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
