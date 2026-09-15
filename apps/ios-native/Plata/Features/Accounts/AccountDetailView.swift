import SwiftUI

// Detalle de una cuenta. Paridad con app RN account/[id].tsx: tarjeta de la
// cuenta (nombre, tipo, balance) e historial de movimientos de esa cuenta. Los
// datos salen de AppState (app.transactions filtrado por accountId), sin red.
// Cada movimiento abre su detalle vía sheet (TransactionDetailView).

struct AccountDetailView: View {
    @Environment(AppState.self) private var app

    let account: Account

    @State private var selectedTransaction: Transaction?

    // La cuenta puede haber cambiado (balance) tras un refresh: relee de AppState.
    private var liveAccount: Account {
        app.accounts.first { $0.id == account.id } ?? account
    }

    private var accountTransactions: [Transaction] {
        app.transactions
            .filter { $0.accountId == account.id }
            .sorted { $0.date > $1.date }
    }

    private var base: Color {
        AccountCreditCardStyle.color(from: liveAccount.color, id: liveAccount.id)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                accountCard
                    .padding(.top, Space.s)

                movements
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxxl)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Detalle de cuenta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $selectedTransaction) { tx in
            NavigationStack {
                TransactionDetailView(transaction: tx)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bg)
        }
    }

    // MARK: - Tarjeta de cuenta

    private var accountCard: some View {
        let acc = liveAccount
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(acc.name)
                    .font(Typo.headline)
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Image(systemName: acc.type.sfSymbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            }

            Spacer(minLength: Space.xl)

            Text(acc.type.label.uppercased())
                .font(Typo.overline)
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.bottom, Space.xs)

            Text(CurrencyFormatter.string(acc.balance, currency: app.currency))
                .font(Typo.amountLarge)
                .tracking(-0.5)
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(Space.l)
        .frame(height: 190)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                // Gradiente diagonal del color de la cuenta: clara → base → oscura.
                LinearGradient(
                    colors: [
                        AccountCreditCardStyle.lighten(base, by: 0.16),
                        base,
                        AccountCreditCardStyle.darken(base, by: 0.26),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Highlight de luz en la esquina superior (efecto tarjeta).
                RadialGradient(
                    colors: [.white.opacity(0.22), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 360
                )
                .blendMode(.softLight)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AccountCreditCardStyle.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AccountCreditCardStyle.radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }

    // MARK: - Historial

    private var movements: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel(text: "Historial de movimientos")

            if accountTransactions.isEmpty {
                AccountDetailEmpty()
            } else {
                VStack(spacing: Space.s) {
                    ForEach(accountTransactions) { tx in
                        Button {
                            selectedTransaction = tx
                        } label: {
                            AccountDetailTxRow(
                                transaction: tx,
                                category: app.category(for: tx.categoryId),
                                currency: app.currency
                            )
                        }
                        .pressable()
                    }
                }
            }
        }
    }
}

// MARK: - Fila de movimiento

private struct AccountDetailTxRow: View {
    let transaction: Transaction
    let category: Category?
    let currency: String

    private var isIncome: Bool { transaction.type == .income }

    private var title: String {
        if let d = transaction.description, !d.isEmpty { return d }
        return category?.name ?? transaction.type.label
    }

    var body: some View {
        Card(padding: Space.m) {
            HStack(spacing: Space.m) {
                CategoryIcon(
                    systemName: TransactionVisual.symbol(for: category, fallbackType: transaction.type),
                    color: TransactionVisual.color(for: category),
                    size: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typo.callout)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(AccountDetailDate.pretty(transaction.date))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
                Spacer()
                AmountText(
                    amount: isIncome ? transaction.amount : -transaction.amount,
                    currency: currency,
                    font: Typo.amount,
                    signed: true,
                    tintBySign: true
                )
            }
        }
    }
}

// MARK: - Estado vacío

private struct AccountDetailEmpty: View {
    var body: some View {
        VStack(spacing: Space.s) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(Palette.inkTertiary)
            Text("Sin movimientos en esta cuenta")
                .font(Typo.callout)
                .foregroundStyle(Palette.inkSecondary)
            Text("Cuando registres ingresos o gastos aquí, aparecerán en este historial.")
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
    }
}

// MARK: - Formato de fecha

enum AccountDetailDate {
    static func pretty(_ raw: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        guard let date = iso.date(from: String(raw.prefix(10))) else { return raw }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Hoy" }
        if cal.isDateInYesterday(date) { return "Ayer" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "es_CO")
        let sameYear = cal.component(.year, from: date) == cal.component(.year, from: Date())
        out.dateFormat = sameYear ? "d MMM" : "d MMM yyyy"
        let text = out.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
