import SwiftUI

// Crear un presupuesto: monto GIGANTE (amber, color de presupuesto), selector de
// categoría de tipo gasto en píldoras horizontales, y periodo mensual/semanal.
// Paridad con app RN add-budget.tsx (categoría + límite mensual), extendido con
// el periodo que soporta el schema (weekly/monthly). Inserta en `budgets` vía
// SupabaseClient y refresca AppState.

struct AddBudgetView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @Namespace private var periodNS

    // Formulario
    @State private var amountDigits = ""
    @State private var categoryId: String?
    @State private var period: BudgetPeriod = .monthly

    @State private var isSaving = false
    @State private var saveError: String?

    private var expenseCategories: [Category] {
        app.categories.filter { $0.type == .expense }
    }

    private var amountValue: Double { Double(amountDigits) ?? 0 }

    private var canSave: Bool { amountValue > 0 && categoryId != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                // Velo tenue en vez de opaco: deja leer el material del sheet (glass).
                Palette.bg.opacity(0.6).ignoresSafeArea()

                if expenseCategories.isEmpty {
                    AddBudgetEmptyState()
                } else {
                    content
                }
            }
            .navigationTitle("Nuevo presupuesto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .tint(Palette.accent)
        .presentationDragIndicator(.visible)
        .glassSheetBackground()
        .onAppear {
            if categoryId == nil { categoryId = expenseCategories.first?.id }
        }
        .alert("No se pudo guardar", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(saveError ?? "Inténtalo de nuevo.")
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Space.xl) {
                    amountDisplay
                        .padding(.top, Space.l)

                    // Periodo
                    VStack(alignment: .leading, spacing: Space.s) {
                        SectionLabel(text: "Periodo")
                        PillToggle(options: periodOptions, selection: $period, namespace: periodNS)
                    }

                    // Categoría (solo gasto)
                    VStack(alignment: .leading, spacing: Space.m) {
                        SectionLabel(text: "Categoría del presupuesto")
                        categoryGrid
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.l)
            }

            keypad

            PrimaryButton(
                title: isSaving ? "Guardando…" : "Guardar presupuesto",
                icon: isSaving ? nil : "checkmark",
                tint: canSave ? Palette.amber : Palette.surfaceElevated,
                fg: canSave ? Palette.bg : Palette.inkTertiary
            ) {
                save()
            }
            .disabled(!canSave || isSaving)
            .padding(.horizontal, Space.l)
            .padding(.top, Space.m)
            .padding(.bottom, Space.s)
        }
    }

    // MARK: - Monto gigante

    private var amountDisplay: some View {
        VStack(spacing: Space.xs) {
            Text("LÍMITE DE GASTO")
                .font(Typo.overline)
                .tracking(1.2)
                .foregroundStyle(Palette.amber)

            Text(CurrencyFormatter.string(amountValue, currency: app.currency))
                .font(Typo.amountHero(amountFontSize))
                .monospacedDigit()
                .tracking(-0.5) // tracking negativo sutil en cifra display grande
                .foregroundStyle(amountValue > 0 ? Palette.ink : Palette.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText(value: amountValue))
                .animation(Motion.value, value: amountValue)
                .frame(maxWidth: .infinity)
        }
    }

    private var amountFontSize: CGFloat {
        switch CurrencyFormatter.string(amountValue, currency: app.currency).count {
        case ...9: return 56
        case 10...12: return 46
        case 13...15: return 38
        default: return 30
        }
    }

    // MARK: - Grid de categorías

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: Space.m)]

    private var categoryGrid: some View {
        LazyVGrid(columns: columns, spacing: Space.m) {
            ForEach(expenseCategories) { cat in
                Button {
                    withAnimation(Motion.ui) { categoryId = cat.id }
                } label: {
                    AddBudgetCategoryCell(category: cat, isSelected: categoryId == cat.id)
                }
                .pressable()
            }
        }
    }

    // MARK: - Teclado numérico

    private var keypad: some View {
        VStack(spacing: Space.s) {
            ForEach(keypadRows, id: \.self) { row in
                HStack(spacing: Space.s) {
                    ForEach(row, id: \.self) { key in
                        AddBudgetKeypadButton(key: key) { tap(key) }
                    }
                }
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
    }

    private let keypadRows: [[KeypadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.clear, .digit("0"), .delete],
    ]

    private func tap(_ key: KeypadKey) {
        switch key {
        case .digit(let d):
            guard amountDigits.count < 12 else { return }
            if amountDigits.isEmpty && d == "0" { return }
            amountDigits.append(d)
        case .delete:
            if !amountDigits.isEmpty { amountDigits.removeLast() }
        case .clear:
            amountDigits = ""
        }
    }

    // MARK: - Guardar

    private var periodOptions: [(value: BudgetPeriod, label: String, tint: Color)] {
        [
            (.monthly, "Mensual", Palette.amber),
            (.weekly, "Semanal", Palette.orange),
        ]
    }

    private func save() {
        guard canSave, let categoryId, let hh = app.household?.id else { return }
        isSaving = true
        saveError = nil

        let payload = AddBudgetInsert(
            household_id: hh,
            category_id: categoryId,
            amount: amountValue,
            period: period.rawValue,
            start_date: Self.periodStart(period)
        )

        Task {
            do {
                let _: [Budget] = try await SupabaseClient.shared.insert("budgets", values: payload)
                await app.refreshAll()
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    /// Inicio del periodo actual: primer día del mes para mensual, del día actual
    /// para semanal (el schema exige una fecha; el original usa inicio de mes).
    private static func periodStart(_ period: BudgetPeriod) -> String {
        let cal = Calendar.current
        let date: Date
        switch period {
        case .monthly:
            date = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        case .weekly:
            date = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Payload de inserción

private struct AddBudgetInsert: Encodable {
    let household_id: String
    let category_id: String
    let amount: Double
    let period: String
    let start_date: String
}

// MARK: - Celda de categoría

private struct AddBudgetCategoryCell: View {
    let category: Category
    let isSelected: Bool

    private var color: Color { TransactionVisual.color(for: category) }

    var body: some View {
        VStack(spacing: Space.s) {
            CategoryIcon(
                systemName: TransactionVisual.symbol(for: category, fallbackType: .expense),
                color: color,
                size: 48
            )
            Text(category.name)
                .font(Typo.caption)
                .foregroundStyle(isSelected ? Palette.ink : Palette.inkSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.m)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(isSelected ? color : Palette.stroke, lineWidth: isSelected ? 1.5 : 1)
        )
    }
}

// MARK: - Botón de teclado (prefijo único de feature)

private struct AddBudgetKeypadButton: View {
    let key: KeypadKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            content
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Rectangle())
        }
        .pressable(scale: 0.94)
    }

    @ViewBuilder private var content: some View {
        switch key {
        case .digit(let d): Text(d).monospacedDigit()
        case .delete: Image(systemName: "delete.left")
        case .clear: Image(systemName: "xmark")
        }
    }

    private var foreground: Color {
        switch key {
        case .digit: return Palette.ink
        case .delete: return Palette.inkSecondary
        case .clear: return Palette.inkTertiary
        }
    }
}

// MARK: - Estado vacío

private struct AddBudgetEmptyState: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Space.l) {
            Image(systemName: "chart.pie")
                .font(.system(size: 36))
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 84, height: 84)
                .background(Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))

            VStack(spacing: Space.xs) {
                Text("Primero crea categorías de gasto")
                    .font(Typo.title)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text("Los presupuestos se asignan a una categoría de tipo gasto. Crea al menos una para empezar.")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xl)
            }

            SecondaryButton(title: "Entendido") { dismiss() }
                .frame(maxWidth: 220)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
