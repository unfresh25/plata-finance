import SwiftUI

// Pantalla de deudas de la pareja: qué nos deben y qué debemos, con progreso.
// Verde para lo que nos deben (a favor), pink para lo que debemos (en contra).

struct DebtsView: View {
    @Environment(AppState.self) private var app

    private var owedToUs: [Debt] {
        app.debts.filter { $0.direction == .owedToUs }
    }
    private var weOwe: [Debt] {
        app.debts.filter { $0.direction == .weOwe }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    if app.debts.isEmpty {
                        DebtsEmptyState()
                            .padding(.top, Space.xxxl)
                    } else {
                        DebtsSection(
                            title: "Nos deben",
                            debts: owedToUs,
                            tint: Palette.green,
                            emptyHint: "Nadie te debe por ahora.",
                            currency: app.currency
                        )
                        DebtsSection(
                            title: "Debemos",
                            debts: weOwe,
                            tint: Palette.pink,
                            emptyHint: "No deben nada. Bien ahí.",
                            currency: app.currency
                        )
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.l)
            }
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Deudas")
        }
    }
}

// MARK: - Sección (nos deben / debemos)

private struct DebtsSection: View {
    let title: String
    let debts: [Debt]
    let tint: Color
    let emptyHint: String
    let currency: String

    private var total: Double {
        debts.reduce(0) { $0 + $1.remaining }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: title)
                Spacer()
                if !debts.isEmpty {
                    Text(CurrencyFormatter.string(total, currency: currency))
                        .font(Typo.caption)
                        .monospacedDigit()
                        .foregroundStyle(tint)
                }
            }

            if debts.isEmpty {
                Card {
                    Text(emptyHint)
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.inkTertiary)
                }
            } else {
                VStack(spacing: Space.m) {
                    ForEach(debts) { debt in
                        DebtsRowCard(debt: debt, tint: tint, currency: currency)
                    }
                }
            }
        }
    }
}

// MARK: - Tarjeta de deuda

private struct DebtsRowCard: View {
    let debt: Debt
    let tint: Color
    let currency: String

    private var isSettled: Bool { debt.status == .paid || debt.remaining <= 0 }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: Space.m) {
                    CategoryIcon(
                        systemName: "person.fill",
                        color: tint,
                        size: 44
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(debt.personName)
                            .font(Typo.headline)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        if let description = debt.description, !description.isEmpty {
                            Text(description)
                                .font(Typo.subhead)
                                .foregroundStyle(Palette.inkSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: Space.s)

                    VStack(alignment: .trailing, spacing: 4) {
                        AmountText(
                            amount: debt.remaining,
                            currency: currency,
                            font: Typo.amount
                        )
                        .foregroundStyle(isSettled ? Palette.inkSecondary : tint)
                        // Badge de estado sobre Card glass → capa teñida sutil, no glass.
                        Text(isSettled ? "Saldado" : "Pendiente")
                            .font(Typo.caption)
                            .foregroundStyle(isSettled ? Palette.inkTertiary : tint)
                            .padding(.horizontal, Space.s)
                            .padding(.vertical, 2)
                            .background(
                                (isSettled ? Palette.inkTertiary : tint).opacity(0.14),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    (isSettled ? Palette.inkTertiary : tint).opacity(0.26),
                                    lineWidth: 0.5
                                )
                            )
                    }
                }

                DebtsProgressBar(progress: debt.progress, tint: tint)

                HStack {
                    Text("Pagado \(CurrencyFormatter.string(debt.amountPaid, currency: currency))")
                        .font(Typo.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkSecondary)
                    Spacer()
                    Text("de \(CurrencyFormatter.string(debt.amount, currency: currency))")
                        .font(Typo.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
        }
    }
}

// MARK: - Barra de progreso de deuda

private struct DebtsProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0, min(1, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.surfaceElevated)
                Capsule()
                    .fill(tint)
                    .frame(width: max(6, geo.size.width * clamped))
                    .animation(Motion.value, value: clamped)
            }
        }
        .frame(height: 6)
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
