import SwiftUI

// MARK: - Dashboard

/// Pantalla de inicio. Saludo + balance total gigante, KPIs del mes,
/// carrusel de cuentas y movimientos recientes. Todo tappable con press feedback.
struct DashboardView: View {
    @Environment(AppState.self) private var app

    /// Cuántos movimientos mostramos en la vista previa del inicio.
    private let recentCount = 6

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                DashboardHeader(name: app.profile?.name, avatarUrl: app.profile?.avatarUrl)

                DashboardBalanceCard(
                    balance: app.totalBalance,
                    currency: app.currency
                )

                DashboardKPIRow(
                    income: app.monthIncome,
                    expense: app.monthExpense,
                    currency: app.currency
                )

                if !app.accounts.isEmpty {
                    DashboardAccountsCarousel(
                        accounts: app.accounts,
                        currency: app.currency
                    )
                }

                DashboardRecentSection(
                    transactions: Array(app.transactions.prefix(recentCount)),
                    hasAnyData: !app.transactions.isEmpty,
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
    }
}

// MARK: - Header (saludo + fecha)

private struct DashboardHeader: View {
    let name: String?
    var avatarUrl: String?

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(greeting)
                    .font(Typo.title)
                    .tracking(-0.4)
                    .foregroundStyle(Palette.ink)
                Text(todayString)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: Space.m)
            // Chrome flotante: los tres botones fusionan como un solo grupo glass (iOS 26).
            GlassGroup(spacing: Space.s) {
                HStack(spacing: Space.s) {
                    DashboardHeaderIcon(systemName: "calendar", destination: AnyView(CalendarView()))
                    DashboardHeaderIcon(systemName: "chart.bar.fill", destination: AnyView(ReportsView()))
                    // Avatar: foto real; al tocar abre Ajustes.
                    NavigationLink { SettingsView() } label: {
                        AvatarView(name: name, urlString: avatarUrl, size: 40)
                    }
                    .buttonStyle(.plain)
                    .pressable(scale: 0.96)
                }
            }
        }
    }

    private var greeting: String {
        if let name, !name.isEmpty { return "Hola, \(name)" }
        return "Hola"
    }

    @ViewBuilder
    private func DashboardHeaderIcon(systemName: String, destination: AnyView) -> some View {
        NavigationLink {
            destination
        } label: {
            Image(systemName: systemName)
                // Sobre glass el ícono necesita un pelo más de contraste que el gris plano.
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 40, height: 40)
                .liquidGlass(cornerRadius: 20, interactive: true)
                .clipShape(Circle())
                // Borde superior luminoso: la luz cae sobre el material desde arriba.
                .overlay(Circle().strokeBorder(DashboardStyle.topEdge, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
        .pressable(scale: 0.96)
    }

    private var todayString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.dateFormat = "EEEE, d 'de' MMMM"
        return f.string(from: Date()).capitalizedFirst
    }
}

// MARK: - Balance total gigante

private struct DashboardBalanceCard: View {
    let balance: Double
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            SectionLabel(text: "Balance total")
            AmountText(
                amount: balance,
                currency: currency,
                font: Typo.amountHero(52)
            )
            .tracking(-0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Space.s)
    }
}

// MARK: - Fila de KPIs (ingreso / gasto del mes)

private struct DashboardKPIRow: View {
    let income: Double
    let expense: Double
    let currency: String

    var body: some View {
        HStack(spacing: Space.m) {
            DashboardKPICard(
                title: "Ingresos del mes",
                amount: income,
                tint: Palette.green,
                icon: "arrow.up.right",
                currency: currency
            )
            DashboardKPICard(
                title: "Gastos del mes",
                amount: expense,
                tint: Palette.pink,
                icon: "arrow.down.right",
                currency: currency
            )
        }
    }
}

private struct DashboardKPICard: View {
    let title: String
    let amount: Double
    let tint: Color
    let icon: String
    let currency: String

    var body: some View {
        Card(padding: Space.l) {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: Space.s) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 24, height: 24)
                        .background(tint.opacity(0.16), in: Circle())
                        // Hairline del propio color: define el chip sin glow (coherente con CategoryIcon).
                        .overlay(Circle().strokeBorder(tint.opacity(0.22), lineWidth: 0.5))
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(CurrencyFormatter.string(amount, currency: currency))
                        .font(Typo.amountMedium)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(title)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
    }
}

// MARK: - Carrusel de cuentas

private struct DashboardAccountsCarousel: View {
    let accounts: [Account]
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel(text: "Cuentas")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.l) {
                    ForEach(accounts) { account in
                        NavigationLink {
                            AccountDetailView(account: account)
                        } label: {
                            DashboardAccountCard(account: account, currency: currency)
                        }
                        .buttonStyle(.plain)
                        .pressable()
                    }
                }
                .padding(.horizontal, Space.l)
            }
            .padding(.horizontal, -Space.l)
        }
    }
}

/// Tarjeta de cuenta del carrusel del Dashboard: ahora con estética de tarjeta
/// de crédito real (ver `AccountCreditCard`). Ancho fijo, apilable en el scroll.
private struct DashboardAccountCard: View {
    let account: Account
    let currency: String

    var body: some View {
        AccountCreditCard(account: account, currency: currency)
    }
}

// MARK: - Movimientos recientes

private struct DashboardRecentSection: View {
    let transactions: [Transaction]
    let hasAnyData: Bool
    let resolveCategory: (String?) -> Category?
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel(text: "Movimientos recientes")

            if transactions.isEmpty {
                DashboardEmptyState(hasAnyData: hasAnyData)
            } else {
                Card(padding: Space.xs) {
                    VStack(spacing: 0) {
                        ForEach(Array(transactions.enumerated()), id: \.element.id) { index, tx in
                            NavigationLink {
                                TransactionDetailView(transaction: tx)
                            } label: {
                                DashboardTransactionRow(
                                    transaction: tx,
                                    category: resolveCategory(tx.categoryId),
                                    currency: currency
                                )
                            }
                            .buttonStyle(.plain)
                            .pressable()

                            if index < transactions.count - 1 {
                                Divider()
                                    .overlay(Palette.stroke)
                                    .padding(.leading, 44 + Space.m + Space.m)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct DashboardTransactionRow: View {
    let transaction: Transaction
    let category: Category?
    let currency: String

    var body: some View {
        HStack(spacing: Space.m) {
            CategoryIcon(
                systemName: iconName,
                color: tint,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(DashboardStyle.relativeDate(from: transaction.date))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }

            Spacer(minLength: Space.s)

            AmountText(
                amount: signedAmount,
                currency: currency,
                font: Typo.amount,
                signed: true,
                tintBySign: true
            )
            .lineLimit(1)
        }
        .padding(.vertical, Space.s)
        .padding(.horizontal, Space.m)
        .contentShape(Rectangle())
    }

    /// Ingreso positivo, gasto/transferencia negativo — coherente con el color por signo.
    private var signedAmount: Double {
        transaction.type == .income ? abs(transaction.amount) : -abs(transaction.amount)
    }

    private var title: String {
        if let desc = transaction.description, !desc.isEmpty { return desc }
        if let category, !category.name.isEmpty { return category.name }
        return transaction.type.label
    }

    private var tint: Color {
        if let category { return DashboardStyle.color(from: category.color) }
        switch transaction.type {
        case .income: return Palette.green
        case .expense: return Palette.pink
        case .transfer: return Palette.sky
        }
    }

    private var iconName: String {
        if let category { return DashboardStyle.symbol(icon: category.icon, name: category.name) }
        switch transaction.type {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Estado vacío

private struct DashboardEmptyState: View {
    let hasAnyData: Bool

    var body: some View {
        Card {
            VStack(spacing: Space.m) {
                Image(systemName: "tray")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(width: 56, height: 56)
                    .background(Palette.surfaceElevated, in: Circle())

                Text("Aún no hay movimientos")
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)

                Text("Registra tu primer ingreso o gasto y lo verás aquí.")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.l)
        }
    }
}

// MARK: - Helpers de estilo locales de la feature

/// Utilidades específicas del Dashboard: conversión de color hex de datos y
/// mapeo de íconos de categoría (nombres del backend) a SF Symbols.
private enum DashboardStyle {
    /// Borde superior luminoso para chrome glass: la luz cae desde arriba sobre
    /// el material y se apaga hacia abajo. Blanco muy tenue, sin glow de color.
    static let topEdge = LinearGradient(
        colors: [.white.opacity(0.20), .white.opacity(0.04)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Convierte un color hex de datos (`"#RRGGBB"` o `"RRGGBB"`) a `Color`.
    /// Fallback al acento de marca si no se puede parsear.
    static func color(from hex: String) -> Color {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s.removeFirst(2) }
        guard s.count == 6, let value = UInt(s, radix: 16) else { return Palette.accent }
        return Color(hex: value)
    }

    /// Mapea el `icon` del backend (o el nombre) a un SF Symbol consistente.
    static func symbol(icon: String, name: String) -> String {
        let key = icon.trimmingCharacters(in: .whitespaces).lowercased()
        if let mapped = symbolMap[key] { return mapped }
        // Si el icon ya parece un SF Symbol válido (contiene punto), úsalo tal cual.
        if key.contains(".") { return icon }
        if let byName = matchByName(name.lowercased()) { return byName }
        return "circle.grid.2x2.fill"
    }

    private static func matchByName(_ name: String) -> String? {
        for (needle, symbol) in nameHints where name.contains(needle) {
            return symbol
        }
        return nil
    }

    /// Fecha relativa amable en español: "Hoy", "Ayer", o "d MMM".
    static func relativeDate(from raw: String) -> String {
        guard let date = parseDate(raw) else { return raw }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Hoy" }
        if cal.isDateInYesterday(date) { return "Ayer" }

        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        if cal.component(.year, from: date) == cal.component(.year, from: Date()) {
            f.dateFormat = "d 'de' MMM"
        } else {
            f.dateFormat = "d MMM yyyy"
        }
        return f.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private static func parseDate(_ raw: String) -> Date? {
        // Intenta ISO8601 completo primero, luego solo fecha YYYY-MM-DD.
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            df.dateFormat = format
            if let d = df.date(from: raw) { return d }
        }
        // Último recurso: primeros 10 caracteres como YYYY-MM-DD.
        if raw.count >= 10 {
            df.dateFormat = "yyyy-MM-dd"
            if let d = df.date(from: String(raw.prefix(10))) { return d }
        }
        return nil
    }

    /// Íconos del backend (packages/core) → SF Symbols.
    private static let symbolMap: [String: String] = [
        "restaurant": "fork.knife",
        "food": "fork.knife",
        "car": "car.fill",
        "transport": "car.fill",
        "home": "house.fill",
        "house": "house.fill",
        "heart": "heart.fill",
        "health": "heart.fill",
        "tv": "tv.fill",
        "entertainment": "tv.fill",
        "shirt": "tshirt.fill",
        "clothes": "tshirt.fill",
        "book": "book.fill",
        "education": "book.fill",
        "money": "dollarsign.circle.fill",
        "salary": "dollarsign.circle.fill",
        "laptop": "laptopcomputer",
        "chart": "chart.line.uptrend.xyaxis",
        "wallet": "wallet.pass.fill",
        "bag": "bag.fill",
        "shopping": "bag.fill",
        "bank": "banknote.fill",
        "savings": "banknote.fill",
    ]

    /// Pistas por nombre de categoría (español) cuando el icon no basta.
    private static let nameHints: [(String, String)] = [
        ("aliment", "fork.knife"),
        ("comida", "fork.knife"),
        ("transport", "car.fill"),
        ("vivienda", "house.fill"),
        ("hogar", "house.fill"),
        ("salud", "heart.fill"),
        ("entreten", "tv.fill"),
        ("ropa", "tshirt.fill"),
        ("educ", "book.fill"),
        ("salario", "dollarsign.circle.fill"),
        ("sueldo", "dollarsign.circle.fill"),
        ("ahorro", "banknote.fill"),
        ("compra", "bag.fill"),
    ]
}

// MARK: - String helper

private extension String {
    /// Capitaliza solo la primera letra (para fechas en español).
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
