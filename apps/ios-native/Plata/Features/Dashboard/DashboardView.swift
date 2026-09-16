import SwiftUI

// MARK: - Dashboard

/// Pantalla de inicio. Saludo + balance total gigante, KPIs del mes,
/// carrusel de cuentas y movimientos recientes. Todo tappable con press feedback.
struct DashboardView: View {
    @Environment(AppState.self) private var app

    /// Cuántos movimientos mostramos en la vista previa del inicio.
    private let recentCount = 6

    // Long-press en un movimiento reciente → editar (reutiliza la pantalla de alta).
    @State private var editTarget: Transaction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                DashboardHeader(name: app.profile?.name, avatarUrl: app.profile?.avatarUrl)

                // Balance total + ingresos/gastos del mes, todo plano y alineado
                // a la izquierda. Sin cards: la jerarquía es puro tipo + espacio.
                DashboardBalanceBlock(
                    balance: app.totalBalance,
                    income: app.monthIncome,
                    expense: app.monthExpense,
                    currency: app.currency
                )

                // ÚNICA excepción a "sin cards": el carrusel de tarjetas de cuenta
                // estilo crédito (AccountCreditCard) — esas sí son tarjetas de verdad.
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
                    currency: app.currency,
                    onEdit: { editTarget = $0 }
                )
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.m)
            .padding(.bottom, Space.xxxl)
        }
        .scrollIndicators(.hidden)
        .background(Palette.bg.ignoresSafeArea())
        .sheet(item: $editTarget) { tx in
            // Edición real: reutiliza la pantalla de alta en modo edición.
            AddTransactionView(editing: tx)
        }
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

// MARK: - Balance total + ingresos/gastos del mes (bloque plano)

/// Bloque de cabecera del dashboard, completamente plano (sin cards):
/// - overline "Balance total"
/// - monto grande (~42pt) con tracking negativo sutil y tabular-nums
/// - fila de InlineStat con ingresos (verde) y gastos (pink) del mes
/// Todo alineado a la izquierda, como el diseño legacy.
private struct DashboardBalanceBlock: View {
    let balance: Double
    let income: Double
    let expense: Double
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Balance total".uppercased())
                    .font(Typo.overline)
                    .tracking(0.8)
                    .foregroundStyle(Palette.inkTertiary)

                AmountText(
                    amount: balance,
                    currency: currency,
                    font: Typo.amountHero(42)
                )
                // Tracking negativo sutil: aprieta el número grande sin estirarlo.
                .tracking(-1)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            }

            // Ingresos / Gastos del mes, en fila, planos, a la izquierda.
            HStack(alignment: .top, spacing: Space.xxl) {
                InlineStat(
                    label: "Ingresos del mes",
                    amount: income,
                    currency: currency,
                    tint: Palette.green,
                    icon: "arrow.up.right"
                )
                InlineStat(
                    label: "Gastos del mes",
                    amount: expense,
                    currency: currency,
                    tint: Palette.pink,
                    icon: "arrow.down.right"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    var onEdit: (Transaction) -> Void = { _ in }

    // Destino de detalle disparado desde el long-press "Ver detalle".
    @State private var detailTarget: Transaction?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            // Header plano: overline + acción "Ver todos" que navega a Movimientos.
            HStack {
                Text("Movimientos recientes".uppercased())
                    .font(Typo.overline)
                    .tracking(0.8)
                    .foregroundStyle(Palette.inkTertiary)
                Spacer()
                if !transactions.isEmpty {
                    NavigationLink {
                        TransactionsView()
                    } label: {
                        Text("Ver todos")
                            .font(Typo.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Palette.accent)
                    }
                    .buttonStyle(.plain)
                    .pressable(scale: 0.94)
                }
            }

            if transactions.isEmpty {
                DashboardEmptyState(hasAnyData: hasAnyData)
            } else {
                // Lista plana con separadores hairline (no card). El divisor arranca
                // tras el logo/ícono de 40 + gap para alinearse con el texto.
                PlainList(transactions, dividerInset: 40 + Space.m) { tx in
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
                    .contextMenu {
                        Button {
                            detailTarget = tx
                        } label: {
                            Label("Ver detalle", systemImage: "doc.text.magnifyingglass")
                        }
                        Button {
                            onEdit(tx)
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                    }
                }
                .navigationDestination(item: $detailTarget) { tx in
                    TransactionDetailView(transaction: tx)
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
        PlainRow(
            leading: {
                RowLeadingIcon(
                    logo: logo,
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
    /// (Netflix, Apple Music Familiar…). Usa el mismo matching robusto de los
    /// recurrentes (maneja sufijos, "+", etc.) para no depender de un match exacto.
    private var logo: Image? {
        SubscriptionLogo.image(for: RecurrentesVisual.slug(for: transaction.description ?? ""))
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

    /// Subtítulo: categoría (si hay descripción distinta) + fecha relativa.
    private var subtitle: String {
        let relative = DashboardStyle.relativeDate(from: transaction.date)
        if let category, !category.name.isEmpty,
           let desc = transaction.description, !desc.isEmpty {
            return "\(category.name) · \(relative)"
        }
        return relative
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
        // Estado vacío plano (sin card): ícono suave centrado + mensaje amable.
        VStack(spacing: Space.m) {
            Image(systemName: "tray")
                .font(.system(size: 26, weight: .regular))
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
        .padding(.vertical, Space.xl)
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

    /// Deriva un slug de logo de app a partir de la descripción de un movimiento
    /// (p.ej. "Netflix febrero" → "netflix"). Devuelve `nil` si no hay match en el
    /// catálogo, para caer al ícono de categoría. Prueba la descripción completa
    /// normalizada y cada palabra suelta.
    static func logoSlug(from description: String?) -> String? {
        guard let raw = description?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !raw.isEmpty else { return nil }

        // "youtube music" / "apple music" → "youtube-music" / "apple-music".
        let joined = raw.replacingOccurrences(of: " ", with: "-")
        if SubscriptionLogo.all.contains(joined) { return joined }

        // Palabra a palabra: la primera que coincida exactamente con un logo.
        for word in raw.split(separator: " ") {
            let w = String(word)
            if SubscriptionLogo.all.contains(w) { return w }
        }
        return nil
    }

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
