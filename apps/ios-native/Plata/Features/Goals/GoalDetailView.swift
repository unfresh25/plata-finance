import SwiftUI

// Detalle de una meta: anillo grande con el % y el monto acumulado al centro,
// deadline si existe, y las acciones de aportar / retirar. El aporte usa
// Repository().addContribution cuando la meta tiene cuenta asociada; si no,
// pide elegir cuenta o informa amablemente.

struct GoalDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    let goal: SavingsGoal

    @State private var sheet: GoalMoveMode?
    @State private var isWorking = false
    @State private var feedback: String?
    @State private var showEdit = false

    // Índice para el color de respaldo: posición dentro de las metas del hogar.
    private var index: Int {
        app.goals.firstIndex(where: { $0.id == goal.id }) ?? 0
    }

    private var tint: Color {
        BudgetPalette.color(hex: goal.color, fallbackIndex: index)
    }

    private var symbol: String {
        goal.icon.contains(".") ? goal.icon : BudgetPalette.symbol(forName: goal.name)
    }

    private var remaining: Double { max(0, goal.targetAmount - goal.currentAmount) }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                ringHeader
                statsRow
                actions

                if let feedback {
                    Text(feedback)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.l)
        }
        .floatingTabBarInset()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $sheet) { mode in
            GoalAmountSheet(
                mode: mode,
                tint: tint,
                currency: app.currency,
                maxWithdraw: goal.currentAmount,
                isWorking: isWorking
            ) { amount in
                await perform(mode: mode, amount: amount)
            }
            .presentationDetents([.height(340)])
            .glassSheetBackground()
        }
        .sheet(isPresented: $showEdit) {
            AddGoalView(editing: goal)
        }
    }

    // MARK: Header con anillo grande

    private var ringHeader: some View {
        ZStack {
            ProgressRing(progress: goal.progress, color: tint, lineWidth: 14, size: 220)

            VStack(spacing: Space.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.bottom, 2)

                Text("\(Int((goal.progress * 100).rounded())) %")
                    .font(Typo.amountLarge)
                    .tracking(-0.5)
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()

                AmountText(amount: goal.currentAmount, currency: app.currency, font: Typo.amount)
            }
        }
        .padding(.top, Space.s)
    }

    // MARK: Stats (filas planas con separador, sin cards)

    private var statsRow: some View {
        VStack(spacing: 0) {
            GoalStatRow(
                label: "Objetivo",
                value: CurrencyFormatter.string(goal.targetAmount, currency: app.currency),
                color: Palette.ink
            )
            RowDivider()
            GoalStatRow(
                label: goal.status == .completed ? "Completada" : "Faltan",
                value: goal.status == .completed
                    ? "¡Listo!"
                    : CurrencyFormatter.string(remaining, currency: app.currency),
                color: goal.status == .completed ? Palette.green : tint
            )
            if let deadline = formattedDeadline {
                RowDivider()
                GoalStatRow(label: "Fecha límite", value: deadline, color: Palette.inkSecondary)
            }
        }
    }

    // MARK: Acciones

    private var actions: some View {
        VStack(spacing: Space.m) {
            PrimaryButton(title: "Añadir dinero", icon: "plus", tint: tint, fg: Palette.bg) {
                feedback = nil
                sheet = .add
            }
            SecondaryButton(title: "Retirar", icon: "arrow.down") {
                feedback = nil
                sheet = .withdraw
            }
            .disabled(goal.currentAmount <= 0)
            .opacity(goal.currentAmount <= 0 ? 0.5 : 1)

            SecondaryButton(title: "Editar meta", icon: "pencil") {
                feedback = nil
                showEdit = true
            }
        }
    }

    private var formattedDeadline: String? {
        guard let raw = goal.deadline else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        guard let date = iso.date(from: String(raw.prefix(10))) else { return nil }
        let out = DateFormatter()
        out.locale = Locale(identifier: "es_CO")
        out.dateFormat = "d MMM yyyy"
        return out.string(from: date)
    }

    // MARK: Ejecución de aporte / retiro

    private func perform(mode: GoalMoveMode, amount: Double) async {
        guard amount > 0 else { return }
        guard let accountId = goal.accountId ?? app.accounts.first?.id,
              let userId = app.user?.id else {
            feedback = "Vincula una cuenta a esta meta para mover dinero."
            sheet = nil
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let signed = mode == .add ? amount : -amount
            try await Repository().addContribution(
                goalId: goal.id,
                accountId: accountId,
                amount: signed,
                userId: userId
            )
            await app.refreshAll()
            withAnimation(Motion.ui) {
                feedback = mode == .add
                    ? "Aporte de \(CurrencyFormatter.string(amount, currency: app.currency)) registrado."
                    : "Retiro de \(CurrencyFormatter.string(amount, currency: app.currency)) registrado."
            }
        } catch {
            withAnimation(Motion.ui) {
                feedback = "No se pudo completar el movimiento. Inténtalo de nuevo."
            }
        }
        sheet = nil
    }
}

// MARK: - Modo de movimiento

enum GoalMoveMode: Identifiable {
    case add, withdraw
    var id: Int { self == .add ? 0 : 1 }

    var title: String { self == .add ? "Añadir dinero" : "Retirar dinero" }
    var cta: String { self == .add ? "Aportar" : "Retirar" }
}

// MARK: - Fila de estadística (plana, sin card)

private struct GoalStatRow: View {
    let label: String
    let value: String
    var color: Color = Palette.ink

    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(Typo.overline)
                .tracking(0.6)
                .foregroundStyle(Palette.inkTertiary)
            Spacer(minLength: Space.m)
            Text(value)
                .font(Typo.callout)
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Sheet de monto

private struct GoalAmountSheet: View {
    let mode: GoalMoveMode
    let tint: Color
    let currency: String
    let maxWithdraw: Double
    let isWorking: Bool
    let onConfirm: (Double) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    private var amount: Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var isValid: Bool {
        guard amount > 0 else { return false }
        if mode == .withdraw { return amount <= maxWithdraw }
        return true
    }

    var body: some View {
        VStack(spacing: Space.xl) {
            Capsule()
                .fill(Palette.stroke)
                .frame(width: 36, height: 5)
                .padding(.top, Space.s)

            Text(mode.title)
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

            PrimaryButton(title: mode.cta, tint: tint, fg: Palette.bg) {
                Task {
                    await onConfirm(amount)
                    dismiss()
                }
            }
            .disabled(!isValid || isWorking)
            .opacity(isValid && !isWorking ? 1 : 0.5)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.l)
        .padding(.bottom, Space.l)
    }
}
