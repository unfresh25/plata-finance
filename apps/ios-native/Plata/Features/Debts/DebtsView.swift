import SwiftUI

// Pantalla de deudas de la pareja: qué nos deben y qué debemos, con progreso.
// Rediseño FLAT (Monarch/YNAB): sin cards. Dos secciones planas "Nos deben"
// (verde, a favor) y "Debemos" (pink, en contra), cada una con su total y filas
// separadas por hairlines. Progreso inline delgado y muy legible por fila.

struct DebtsView: View {
    @Environment(AppState.self) private var app

    @State private var showAdd = false
    @State private var editingDebt: Debt?

    private var owedToUs: [Debt] {
        app.debts.filter { $0.direction == .owedToUs && $0.status == .active }
    }
    private var weOwe: [Debt] {
        app.debts.filter { $0.direction == .weOwe && $0.status == .active }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                // Título grande, tracking negativo sutil.
                HStack(alignment: .firstTextBaseline) {
                    Text("Deudas")
                        .font(Typo.titleXL)
                        .tracking(-0.6)
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.accent)
                            .frame(width: 32, height: 32)
                            .background(Palette.accent.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .pressable(scale: 0.94)
                    .accessibilityLabel("Añadir deuda")
                }

                if owedToUs.isEmpty && weOwe.isEmpty {
                    DebtsEmptyState()
                        .padding(.top, Space.xxl)
                } else {
                    DebtsSection(
                        title: "Nos deben",
                        debts: owedToUs,
                        tint: Palette.green,
                        positive: true,
                        emptyHint: "Nadie te debe por ahora.",
                        currency: app.currency,
                        onEdit: { editingDebt = $0 }
                    )
                    DebtsSection(
                        title: "Debemos",
                        debts: weOwe,
                        tint: Palette.pink,
                        positive: false,
                        emptyHint: "No deben nada. Bien ahí.",
                        currency: app.currency,
                        onEdit: { editingDebt = $0 }
                    )
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.l)
            .padding(.bottom, Space.xxxl)
        }
        .background(Palette.bg.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) { AddDebtView() }
        .sheet(item: $editingDebt) { debt in AddDebtView(editing: debt) }
    }
}

// MARK: - Sección plana (nos deben / debemos)

private struct DebtsSection: View {
    let title: String
    let debts: [Debt]
    let tint: Color
    let positive: Bool
    let emptyHint: String
    let currency: String
    let onEdit: (Debt) -> Void

    private var total: Double { debts.reduce(0) { $0 + $1.remaining } }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            // Header: label con punto de color + total a la derecha.
            HStack(spacing: Space.s) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                Text(title.uppercased())
                    .font(Typo.overline)
                    .tracking(0.8)
                    .foregroundStyle(tint)
                Spacer(minLength: Space.s)
                if !debts.isEmpty {
                    Text((positive ? "+" : "−") + CurrencyFormatter.string(total, currency: currency))
                        .font(Typo.callout)
                        .monospacedDigit()
                        .foregroundStyle(tint)
                }
            }

            if debts.isEmpty {
                Text(emptyHint)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.vertical, Space.s)
            } else {
                PlainList(debts, dividerInset: 0) { debt in
                    Button {
                        onEdit(debt)
                    } label: {
                        DebtsRow(debt: debt, tint: tint, positive: positive, currency: currency)
                    }
                    .buttonStyle(.plain)
                    .pressable()
                }
            }
        }
    }
}

// MARK: - Fila de deuda plana (progreso inline legible)

private struct DebtsRow: View {
    let debt: Debt
    let tint: Color
    let positive: Bool
    let currency: String

    private var isSettled: Bool { debt.status == .paid || debt.remaining <= 0 }

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
                    } else if let due = debt.dueDate, !due.isEmpty {
                        Text("Vence \(DebtsDate.short(due))")
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
                        .foregroundStyle(isSettled ? Palette.inkSecondary : tint)
                    Text(isSettled ? "Saldado" : "de \(CurrencyFormatter.compact(debt.amount))")
                        .font(Typo.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkTertiary)
                }
            }

            // Progreso inline delgado + monto pagado, muy legible.
            HStack(spacing: Space.s) {
                DebtsProgressBar(progress: debt.progress, tint: tint, height: 5)
                Text("\(Int((debt.progress * 100).rounded())) %")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(width: 36, alignment: .trailing)
            }

            Text("Pagado \(CurrencyFormatter.string(debt.amountPaid, currency: currency)) de \(CurrencyFormatter.string(debt.amount, currency: currency))")
                .font(Typo.caption)
                .monospacedDigit()
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Barra de progreso inline (plana)

private struct DebtsProgressBar: View {
    let progress: Double
    let tint: Color
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

// MARK: - Estado vacío

private struct DebtsEmptyState: View {
    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "hand.thumbsup.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Palette.green)
            Text("Sin deudas")
                .font(Typo.title)
                .foregroundStyle(Palette.ink)
            Text("Ni les deben ni deben. Cuando registres una deuda aparecerá aquí con su progreso.")
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Fecha corta local

private enum DebtsDate {
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
