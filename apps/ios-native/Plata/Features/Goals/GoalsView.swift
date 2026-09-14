import SwiftUI

// Metas de ahorro compartidas. Cada meta se presenta en una Card con un anillo
// de progreso pequeño, el nombre y el avance monto actual / objetivo. Tap abre
// el detalle con el anillo grande y las acciones de aportar / retirar.

struct GoalsView: View {
    @Environment(AppState.self) private var app

    private var activeGoals: [SavingsGoal] {
        app.goals.filter { $0.status != .cancelled }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Space.m) {
                if activeGoals.isEmpty {
                    GoalsEmptyState()
                        .padding(.top, Space.xxxl)
                } else {
                    SectionLabel(text: "Nuestras metas")
                        .padding(.horizontal, Space.xs)
                        .padding(.top, Space.s)

                    ForEach(Array(activeGoals.enumerated()), id: \.element.id) { index, goal in
                        NavigationLink(value: goal) {
                            GoalRowCard(goal: goal, index: index)
                        }
                        .buttonStyle(.plain)
                        .pressable()
                    }
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxxl)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Metas")
        .navigationDestination(for: SavingsGoal.self) { goal in
            GoalDetailView(goal: goal)
        }
    }
}

// MARK: - Fila de meta

private struct GoalRowCard: View {
    @Environment(AppState.self) private var app
    let goal: SavingsGoal
    let index: Int

    private var tint: Color {
        BudgetPalette.color(hex: goal.color, fallbackIndex: index)
    }

    private var symbol: String {
        goal.icon.contains(".") ? goal.icon : BudgetPalette.symbol(forName: goal.name)
    }

    var body: some View {
        Card {
            HStack(spacing: Space.l) {
                ZStack {
                    ProgressRing(progress: goal.progress, color: tint, lineWidth: 6, size: 56)
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(goal.name)
                        .font(Typo.headline)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)

                    HStack(spacing: Space.xs) {
                        AmountText(amount: goal.currentAmount, currency: app.currency, font: Typo.callout)
                        Text("/ \(CurrencyFormatter.compact(goal.targetAmount))")
                            .font(Typo.callout)
                            .foregroundStyle(Palette.inkTertiary)
                            .monospacedDigit()
                    }

                    if goal.status == .completed {
                        Text("Meta cumplida")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.green)
                    } else {
                        Text("\(Int((goal.progress * 100).rounded())) % ahorrado")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkSecondary)
                            .monospacedDigit()
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }
}

// MARK: - Estado vacío

private struct GoalsEmptyState: View {
    var body: some View {
        VStack(spacing: Space.m) {
            CategoryIcon(systemName: "target", color: Palette.accent, size: 64)
            Text("Sin metas todavía")
                .font(Typo.title)
                .foregroundStyle(Palette.ink)
            Text("Definan juntos una meta de ahorro y vean crecer el anillo con cada aporte.")
                .font(Typo.body)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
        .frame(maxWidth: .infinity)
    }
}
