import SwiftUI

// Detalle de una categoría: encabezado con su ícono coloreado, el total
// gastado/ingresado en esa categoría, el número de movimientos y la lista de
// transacciones (filtradas de app.transactions por categoryId) agrupada por
// fecha. Acción de editar en la barra de navegación.

struct CategoryDetailView: View {
    @Environment(AppState.self) private var app

    let category: Category
    var onEdit: (() -> Void)? = nil

    private var tint: Color { CategorasVisual.color(for: category) }

    private var symbol: String { IconMapping.sfSymbol(for: category.icon) }

    private var transactions: [Transaction] {
        app.transactions
            .filter { $0.categoryId == category.id }
            .sorted { $0.date > $1.date }
    }

    private var total: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    private var isIncome: Bool { category.type == .income }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                header

                if transactions.isEmpty {
                    CategoryDetailEmptyState(isIncome: isIncome)
                        .padding(.top, Space.xl)
                } else {
                    transactionList
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.l)
            .padding(.bottom, Space.xxxl)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Editar", action: onEdit)
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: Encabezado con total

    /// Glifo grande de la categoría: Hugeicon real si existe, si no SF Symbol.
    @ViewBuilder
    private var headerGlyph: some View {
        if let hugeicon = CategoryIconAsset.image(forSlug: category.icon) {
            hugeicon.resizable().scaledToFit().frame(width: 40, height: 40)
        } else {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .semibold))
        }
    }

    private var header: some View {
        VStack(spacing: Space.l) {
            headerGlyph
                .foregroundStyle(tint)
                .frame(width: 96, height: 96)
                .background(
                    tint.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(tint.opacity(0.22), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)

            VStack(spacing: Space.xs) {
                Text(isIncome ? "Total ingresado" : "Total gastado")
                    .font(Typo.overline)
                    .tracking(0.8)
                    .foregroundStyle(Palette.inkTertiary)

                Text(CurrencyFormatter.string(total, currency: app.currency))
                    .font(Typo.amountLarge)
                    .tracking(-0.5)
                    .foregroundStyle(isIncome ? Palette.green : Palette.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(movementsLabel)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.s)
    }

    private var movementsLabel: String {
        let n = transactions.count
        return n == 1 ? "1 movimiento" : "\(n) movimientos"
    }

    // MARK: Lista de movimientos agrupada por fecha

    private var transactionList: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(group.title)
                        .font(Typo.overline)
                        .tracking(0.8)
                        .foregroundStyle(Palette.inkTertiary)
                        .padding(.horizontal, Space.xs)

                    VStack(spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, tx in
                            CategoryDetailRow(transaction: tx, tint: tint, symbol: symbol, slug: category.icon, isIncome: isIncome)
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

    private var groups: [CategoryDetailDayGroup] {
        let grouped = Dictionary(grouping: transactions) { String($0.date.prefix(10)) }
        return grouped
            .map { key, items in
                CategoryDetailDayGroup(
                    id: key,
                    title: CategoryDetailDateFormat.header(for: key),
                    items: items
                )
            }
            .sorted { $0.id > $1.id }
    }
}

// MARK: - Grupo de día

private struct CategoryDetailDayGroup: Identifiable {
    let id: String
    let title: String
    let items: [Transaction]
}

// MARK: - Fila de movimiento

private struct CategoryDetailRow: View {
    @Environment(AppState.self) private var app
    let transaction: Transaction
    let tint: Color
    let symbol: String
    let slug: String
    let isIncome: Bool

    var body: some View {
        HStack(spacing: Space.m) {
            CategoryIcon(systemName: symbol, color: tint, size: 44, slug: slug)

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
    }

    private var title: String {
        if let desc = transaction.description, !desc.isEmpty { return desc }
        return transaction.type.label
    }

    private var subtitle: String {
        app.accounts.first { $0.id == transaction.accountId }?.name ?? transaction.type.label
    }

    private var signedAmount: Double {
        transaction.type == .income ? transaction.amount : -transaction.amount
    }
}

// MARK: - Estado vacío

private struct CategoryDetailEmptyState: View {
    let isIncome: Bool

    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 72, height: 72)
                .background(Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))

            Text("Sin movimientos")
                .font(Typo.headline)
                .foregroundStyle(Palette.ink)
            Text(isIncome
                 ? "Aún no hay ingresos registrados en esta categoría."
                 : "Aún no hay gastos registrados en esta categoría.")
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }
}

// MARK: - Formato de fecha (privado del feature)

enum CategoryDetailDateFormat {
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
