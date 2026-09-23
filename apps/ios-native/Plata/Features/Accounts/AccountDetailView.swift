import SwiftUI

// Detalle de una cuenta. Paridad con app RN account/[id].tsx: la tarjeta estilo
// crédito de la cuenta (nombre, tipo, balance) — ÚNICA excepción permitida a
// "sin cards" — seguida del historial de movimientos de esa cuenta, ya PLANO
// (PlainSection + PlainList con hairlines, filas tipo Dashboard). Sin cards.
// Los datos salen de AppState (app.transactions filtrado por accountId), sin red.
// Tap en un movimiento → TransactionDetailView; long-press → Editar (AddTransactionView).

struct AccountDetailView: View {
    @Environment(AppState.self) private var app

    let account: Account

    // Detalle de un movimiento (tap) y edición de cuenta (toolbar).
    @State private var selectedTransaction: Transaction?
    @State private var showEditAccount = false
    @State private var showDeleteConfirm = false
    @State private var showPayCard = false
    @Environment(\.dismiss) private var dismiss
    // Long-press en un movimiento → editar (reutiliza la pantalla de alta).
    @State private var editTarget: Transaction?

    // La cuenta puede haber cambiado (balance) tras un refresh: relee de AppState.
    private var liveAccount: Account {
        app.accounts.first { $0.id == account.id } ?? account
    }

    private var accountTransactions: [Transaction] {
        app.transactions
            .filter { $0.accountId == account.id }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                // Excepción única a "sin cards": la tarjeta estilo crédito.
                AccountCreditCard(account: liveAccount, currency: app.currency)
                    .padding(.top, Space.s)

                // Tarjeta de crédito: botón para pagarla (libera cupo).
                if liveAccount.isCredit {
                    PrimaryButton(title: "Pagar tarjeta", icon: "creditcard.and.123") {
                        showPayCard = true
                    }
                }

                movements
            }
            .padding(.horizontal, Space.l)
        }
        .floatingTabBarInset()
        .scrollIndicators(.hidden)
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Detalle de cuenta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditAccount = true } label: { Label("Editar cuenta", systemImage: "pencil") }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Eliminar cuenta", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("¿Eliminar esta cuenta?", isPresented: $showDeleteConfirm) {
            Button("Eliminar", role: .destructive) {
                Task { await app.deleteAccount(id: liveAccount.id); dismiss() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminará la cuenta y TODOS sus movimientos. Esta acción no se puede deshacer.")
        }
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(Palette.accent)
        .sheet(item: $selectedTransaction) { tx in
            NavigationStack {
                TransactionDetailView(transaction: tx)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bg)
        }
        .sheet(item: $editTarget) { tx in
            // Edición real: reutiliza la pantalla de alta en modo edición.
            AddTransactionView(editing: tx)
        }
        .sheet(isPresented: $showEditAccount) {
            AddAccountView(editing: liveAccount)
        }
        .sheet(isPresented: $showPayCard) {
            PayCreditCardView(card: liveAccount)
        }
    }

    // MARK: - Historial de movimientos (plano)

    private var movements: some View {
        PlainSection(title: "Historial de movimientos") {
            if accountTransactions.isEmpty {
                AccountDetailEmpty()
            } else {
                // Lista plana con hairlines; el divisor arranca tras el ícono de
                // 40 + gap para alinearse con el texto (igual que el Dashboard).
                PlainList(accountTransactions, dividerInset: 40 + Space.m) { tx in
                    Button {
                        selectedTransaction = tx
                    } label: {
                        AccountDetailTxRow(
                            transaction: tx,
                            category: app.category(for: tx.categoryId),
                            member: app.member(for: tx.createdBy),
                            currency: app.currency
                        )
                    }
                    .buttonStyle(.plain)
                    .pressable()
                    .contextMenu {
                        Button {
                            selectedTransaction = tx
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

// MARK: - Fila de movimiento (plana, estilo Dashboard)

private struct AccountDetailTxRow: View {
    let transaction: Transaction
    let category: Category?
    let member: Profile?
    let currency: String

    var body: some View {
        PlainRow(
            leading: {
                RowLeadingIcon(
                    logo: logo,
                    categoryIcon: CategoryIconAsset.image(forSlug: category?.icon),
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
    /// (Netflix, Spotify…), con el mismo matching robusto de los recurrentes.
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

    /// Subtítulo: quién lo registró (miembro real) + categoría (si aporta) + fecha.
    private var subtitle: String {
        var parts: [String] = []
        if let name = member?.name, !name.isEmpty { parts.append(name) }
        if let category, !category.name.isEmpty,
           let desc = transaction.description, !desc.isEmpty {
            parts.append(category.name)
        }
        parts.append(AccountDetailDate.pretty(transaction.date))
        return parts.joined(separator: " · ")
    }

    private var tint: Color {
        TransactionVisual.color(for: category)
    }

    private var iconName: String {
        TransactionVisual.symbol(for: category, fallbackType: transaction.type)
    }
}

// MARK: - Estado vacío (amable, plano)

private struct AccountDetailEmpty: View {
    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "tray")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 56, height: 56)
                .background(Palette.surfaceElevated, in: Circle())

            Text("Sin movimientos en esta cuenta")
                .font(Typo.headline)
                .foregroundStyle(Palette.ink)

            Text("Cuando registres ingresos o gastos aquí, aparecerán en este historial.")
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
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
