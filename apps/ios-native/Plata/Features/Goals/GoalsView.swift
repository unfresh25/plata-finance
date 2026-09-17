import SwiftUI

// Metas de ahorro compartidas. Diseño PLANO: una sección con filas separadas por
// hairlines (sin cards). Cada fila lleva su anillo de progreso pequeño, nombre y
// el avance monto actual / objetivo. Tap abre el detalle con el anillo grande y
// las acciones de aportar / retirar.

struct GoalsView: View {
    @Environment(AppState.self) private var app

    private var activeGoals: [SavingsGoal] {
        app.goals.filter { $0.status != .cancelled }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if activeGoals.isEmpty {
                    GoalsEmptyState()
                        .padding(.top, Space.xxxl)
                } else {
                    PlainSection(title: "Nuestras metas") {
                        PlainList(indexed(activeGoals), dividerInset: 56 + Space.m) { pair in
                            NavigationLink(value: pair.goal) {
                                GoalPlainRow(goal: pair.goal, index: pair.index)
                            }
                            .buttonStyle(.plain)
                            .pressable()
                        }
                    }
                    .padding(.top, Space.s)
                }
            }
            .padding(.horizontal, Space.l)
        }
        .floatingTabBarInset()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Metas")
        .navigationDestination(for: SavingsGoal.self) { goal in
            GoalDetailView(goal: goal)
        }
    }

    /// Empareja cada meta con su índice para el color de respaldo, en una forma
    /// Identifiable estable para PlainList.
    private func indexed(_ goals: [SavingsGoal]) -> [GoalIndexPair] {
        goals.enumerated().map { GoalIndexPair(index: $0.offset, goal: $0.element) }
    }
}

private struct GoalIndexPair: Identifiable {
    let index: Int
    let goal: SavingsGoal
    var id: String { goal.id }
}

// MARK: - Fila de meta (plana, sin card)

private struct GoalPlainRow: View {
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
        HStack(spacing: Space.m) {
            ZStack {
                ProgressRing(progress: goal.progress, color: tint, lineWidth: 5, size: 56)
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

            Spacer(minLength: Space.s)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
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
