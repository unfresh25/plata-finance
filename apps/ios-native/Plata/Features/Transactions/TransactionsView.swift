import SwiftUI

// Lista de movimientos agrupada por fecha. Headers amables ("Hoy", "Ayer",
// fecha formateada). Cada fila reutiliza CategoryIcon + AmountText del design
// system. Búsqueda opcional y estado vacío con copy en español.

struct TransactionsView: View {
    @Environment(AppState.self) private var app

    @State private var query = ""
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                Group {
                    if app.transactions.isEmpty {
                        TransactionsEmptyState { showingAdd = true }
                    } else if filtered.isEmpty {
                        TransactionsNoResults(query: query)
                    } else {
                        transactionList
                    }
                }
            }
            .navigationTitle("Movimientos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.bg)
                            .frame(width: 32, height: 32)
                            .background(Palette.ink, in: Circle())
                    }
                    .pressable()
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Buscar movimiento"
            )
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
        .sheet(isPresented: $showingAdd) {
            AddTransactionView()
        }
    }

    // MARK: - Lista

    private var transactionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.xl, pinnedViews: []) {
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
            .padding(.horizontal, Space.l)
            .padding(.top, Space.s)
            .padding(.bottom, Space.xxxl)
        }
    }

    // MARK: - Datos derivados

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
}

// MARK: - Modelo de grupo (privado del feature)

private struct TransactionDayGroup: Identifiable {
    let id: String        // YYYY-MM-DD
    let title: String
    let net: Double
    let items: [Transaction]
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
