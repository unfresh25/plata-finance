import SwiftUI

// Detalle de una deuda: progreso grande (pagado / total), acción de registrar
// un ABONO (crea transacción, ajusta el saldo de la cuenta y suma a amount_paid),
// e historial de abonos. Diseño plano, sin cards. Paridad con app/debt/[id].tsx.

struct DebtDetailView: View {
    @Environment(AppState.self) private var app

    let debt: Debt
    let tint: Color
    /// true = "nos deben" (income), false = "debemos" (expense).
    let positive: Bool
    let onEdit: () -> Void

    @State private var showPaymentSheet = false
    @State private var isWorking = false
    @State private var feedback: String?
    @State private var payments: [DebtPayment] = []
    @State private var loadingHistory = true

    // La deuda puede haber cambiado tras un abono: relee de AppState.
    private var liveDebt: Debt {
        app.debts.first { $0.id == debt.id } ?? debt
    }

    private var isSettled: Bool {
        liveDebt.status == .paid || liveDebt.remaining <= 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                header
                if !isSettled { registerButton }
                historySection

                if let feedback {
                    Text(feedback)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.l)
        }
        .floatingTabBarInset()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(liveDebt.personName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar", action: onEdit)
                    .foregroundStyle(Palette.accent)
            }
        }
        .sheet(isPresented: $showPaymentSheet) {
            DebtPaymentSheet(
                debt: liveDebt,
                tint: tint,
                positive: positive,
                currency: app.currency,
                accounts: app.accounts,
                isWorking: isWorking
            ) { amount, accountId in
                await registerPayment(amount: amount, accountId: accountId)
            }
            .presentationDetents([.height(440), .large])
            .glassSheetBackground()
        }
        .task { await loadHistory() }
    }

    // MARK: - Header (progreso grande)

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(positive ? "Nos deben" : "Debemos")
                    .font(Typo.overline)
                    .tracking(0.8)
                    .foregroundStyle(tint)
                Text((positive ? "+" : "−") + CurrencyFormatter.string(liveDebt.remaining, currency: app.currency))
                    .font(Typo.amountLarge)
                    .tracking(-0.5)
                    .monospacedDigit()
                    .foregroundStyle(isSettled ? Palette.inkSecondary : Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(isSettled ? "Saldado" : "restante de \(CurrencyFormatter.string(liveDebt.amount, currency: app.currency))")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
            }

            // Barra de progreso + %.
            HStack(spacing: Space.s) {
                DebtDetailProgressBar(progress: liveDebt.progress, tint: tint, height: 7)
                Text("\(Int((liveDebt.progress * 100).rounded())) %")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(width: 40, alignment: .trailing)
            }

            Text("Pagado \(CurrencyFormatter.string(liveDebt.amountPaid, currency: app.currency)) de \(CurrencyFormatter.string(liveDebt.amount, currency: app.currency))")
                .font(Typo.caption)
                .monospacedDigit()
                .foregroundStyle(Palette.inkTertiary)

            if let note = liveDebt.description, !note.isEmpty {
                Text(note)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if let due = liveDebt.dueDate, !due.isEmpty {
                Label("Vence \(DebtDetailDate.short(due))", systemImage: "calendar")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }

    private var registerButton: some View {
        PrimaryButton(title: "Registrar abono", icon: "plus", tint: tint, fg: Palette.bg) {
            showPaymentSheet = true
        }
        .disabled(app.accounts.isEmpty)
        .opacity(app.accounts.isEmpty ? 0.5 : 1)
    }

    // MARK: - Historial de abonos

    private var historySection: some View {
        PlainSection(title: "Historial de abonos") {
            if loadingHistory {
                HStack { Spacer(); ProgressView().tint(tint); Spacer() }
                    .padding(.vertical, Space.l)
            } else if payments.isEmpty {
                Text("Aún no hay abonos registrados.")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Space.l)
            } else {
                PlainList(payments, dividerInset: 40 + Space.m) { payment in
                    DebtPaymentRow(payment: payment, tint: tint, positive: positive, currency: app.currency)
                }
            }
        }
    }

    // MARK: - Acciones

    private func loadHistory() async {
        loadingHistory = true
        payments = (try? await Repository().fetchDebtPayments(debtId: debt.id)) ?? []
        loadingHistory = false
    }

    private func registerPayment(amount: Double, accountId: String) async {
        guard let uid = app.profile?.id, amount > 0 else { return }
        isWorking = true
        feedback = nil
        do {
            try await Repository().addDebtPayment(
                debt: liveDebt, accountId: accountId, amount: amount, userId: uid
            )
            await app.refreshAll()
            await loadHistory()
            withAnimation(Motion.value) {
                feedback = "Abono de \(CurrencyFormatter.string(amount, currency: app.currency)) registrado."
            }
        } catch {
            withAnimation(Motion.value) { feedback = error.localizedDescription }
        }
        isWorking = false
    }
}

// MARK: - Sheet de abono (monto + cuenta)

private struct DebtPaymentSheet: View {
    let debt: Debt
    let tint: Color
    let positive: Bool
    let currency: String
    let accounts: [Account]
    let isWorking: Bool
    let onConfirm: (Double, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var accountId: String?

    private var amount: Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var isValid: Bool {
        amount > 0 && accountId != nil
    }

    var body: some View {
        VStack(spacing: Space.xl) {
            Capsule()
                .fill(Palette.stroke)
                .frame(width: 36, height: 5)
                .padding(.top, Space.s)

            Text("Registrar abono")
                .font(Typo.title)
                .foregroundStyle(Palette.ink)

            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text("$")
                    .font(Typo.amountMedium)
                    .foregroundStyle(Palette.inkTertiary)
                TextField("0", text: $text)
                    .font(Typo.amountHero(44))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)

            // Selector de cuenta: de dónde sale/entra el dinero.
            VStack(alignment: .leading, spacing: Space.s) {
                Text(positive ? "Entra a la cuenta" : "Sale de la cuenta")
                    .font(Typo.overline)
                    .tracking(0.8)
                    .foregroundStyle(Palette.inkTertiary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(accounts) { acc in
                            DebtAccountChip(account: acc, isSelected: acc.id == accountId) {
                                accountId = acc.id
                            }
                        }
                    }
                }
            }

            PrimaryButton(title: "Confirmar abono", tint: tint, fg: Palette.bg) {
                guard let accountId else { return }
                Task {
                    await onConfirm(amount, accountId)
                    dismiss()
                }
            }
            .disabled(!isValid || isWorking)
            .opacity(isValid && !isWorking ? 1 : 0.5)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.l)
        .padding(.bottom, Space.l)
        .onAppear {
            // Precarga el restante y la primera cuenta.
            if text.isEmpty && debt.remaining > 0 {
                text = String(Int(debt.remaining.rounded()))
            }
            if accountId == nil { accountId = accounts.first?.id }
        }
    }
}

private struct DebtAccountChip: View {
    let account: Account
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(account.name)
                .font(Typo.subhead)
                .foregroundStyle(isSelected ? Palette.bg : Palette.ink)
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.s)
                .background(
                    isSelected ? Palette.ink : Palette.surfaceElevated,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .pressable()
    }
}

// MARK: - Fila de abono (historial)

private struct DebtPaymentRow: View {
    let payment: DebtPayment
    let tint: Color
    let positive: Bool
    let currency: String

    var body: some View {
        HStack(spacing: Space.m) {
            CategoryIcon(systemName: "arrow.down.circle.fill", color: tint, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("Abono")
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                Text(DebtDetailDate.short(payment.date))
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: Space.s)
            Text((positive ? "+" : "−") + CurrencyFormatter.string(payment.amount, currency: currency))
                .font(Typo.amount)
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.vertical, Space.m)
    }
}

// MARK: - Barra de progreso

private struct DebtDetailProgressBar: View {
    let progress: Double
    let tint: Color
    var height: CGFloat = 7

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

// MARK: - Fecha corta local

private enum DebtDetailDate {
    static func short(_ raw: String) -> String {
        guard let date = parse(raw) else { return raw }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Hoy" }
        if cal.isDateInYesterday(date) { return "Ayer" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
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
