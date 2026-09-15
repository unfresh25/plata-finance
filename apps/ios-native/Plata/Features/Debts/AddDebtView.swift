import SwiftUI

// Crear una deuda. Paridad con app RN add-debt.tsx: dirección "nos deben /
// debemos" con PillToggle, monto GIGANTE teñido según dirección (verde/rosa),
// persona involucrada, descripción, fecha de vencimiento y categoría opcional
// filtrada por el tipo de movimiento resultante (ingreso si nos deben, gasto si
// debemos). Inserta en `debts` vía SupabaseClient y refresca AppState.

struct AddDebtView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @Namespace private var dirNS

    // Formulario
    @State private var direction: DebtDirection = .owedToUs
    @State private var amountDigits = ""
    @State private var person = ""
    @State private var note = ""
    @State private var categoryId: String?
    @State private var dueDate = Date()
    @State private var hasDueDate = true

    @State private var showCategoryPicker = false
    @State private var isSaving = false
    @State private var saveError: String?

    private var isOwed: Bool { direction == .owedToUs }
    private var tint: Color { isOwed ? Palette.green : Palette.pink }

    // El movimiento asociado sería ingreso (nos deben) o gasto (debemos): filtra
    // las categorías igual que el original.
    private var categoriesForDirection: [Category] {
        let want: CategoryType = isOwed ? .income : .expense
        return app.categories.filter { $0.type == want }
    }

    private var selectedCategory: Category? { app.category(for: categoryId) }

    private var amountValue: Double { Double(amountDigits) ?? 0 }

    private var canSave: Bool {
        amountValue > 0 && !person.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                content
            }
            .navigationTitle("Nueva deuda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.bg)
        .onChange(of: direction) { _, _ in
            // La categoría debe coincidir con el nuevo tipo de movimiento.
            if let c = selectedCategory, c.type == (isOwed ? .income : .expense) { return }
            categoryId = nil
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
                    PillToggle(options: directionOptions, selection: $direction, namespace: dirNS)
                        .padding(.top, Space.s)

                    amountDisplay
                        .padding(.vertical, Space.s)

                    selectors
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.l)
            }

            keypad

            PrimaryButton(
                title: isSaving ? "Guardando…" : "Guardar",
                icon: isSaving ? nil : "checkmark",
                tint: canSave ? tint : Palette.surfaceElevated,
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
            Text(isOwed ? "NOS DEBEN" : "DEBEMOS")
                .font(Typo.overline)
                .tracking(1.2)
                .foregroundStyle(tint)

            Text(CurrencyFormatter.string(amountValue, currency: app.currency))
                .font(Typo.amountHero(amountFontSize))
                .monospacedDigit()
                .foregroundStyle(amountValue > 0 ? tint : Palette.inkTertiary)
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

    // MARK: - Selectores

    private var selectors: some View {
        VStack(spacing: Space.m) {
            // Persona
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    AddDebtLeadingIcon(symbol: "person.fill", tint: tint)
                    TextField(
                        "",
                        text: $person,
                        prompt: Text("Persona (Ej. Juan, Banco…)").foregroundColor(Palette.inkTertiary)
                    )
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .submitLabel(.done)
                }
            }

            // Descripción
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    AddDebtLeadingIcon(symbol: "text.alignleft", tint: Palette.orange)
                    TextField(
                        "",
                        text: $note,
                        prompt: Text("Concepto (opcional)").foregroundColor(Palette.inkTertiary)
                    )
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .submitLabel(.done)
                }
            }

            // Categoría
            Button {
                showCategoryPicker = true
            } label: {
                Card(padding: Space.m) {
                    HStack(spacing: Space.m) {
                        if let cat = selectedCategory {
                            CategoryIcon(
                                systemName: TransactionVisual.symbol(for: cat, fallbackType: isOwed ? .income : .expense),
                                color: TransactionVisual.color(for: cat),
                                size: 36
                            )
                        } else {
                            AddDebtLeadingIcon(symbol: "square.grid.2x2", tint: Palette.purple)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Categoría")
                                .font(Typo.caption)
                                .foregroundStyle(Palette.inkTertiary)
                            Text(selectedCategory?.name ?? "Opcional")
                                .font(Typo.callout)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
            }
            .pressable()
            .disabled(categoriesForDirection.isEmpty)

            // Fecha de vencimiento
            Card(padding: Space.m) {
                VStack(spacing: Space.m) {
                    HStack(spacing: Space.m) {
                        AddDebtLeadingIcon(symbol: "calendar", tint: Palette.sky)
                        Text("Fecha límite")
                            .font(Typo.callout)
                            .foregroundStyle(Palette.inkSecondary)
                        Spacer()
                        Toggle("", isOn: $hasDueDate)
                            .labelsHidden()
                            .tint(tint)
                    }
                    if hasDueDate {
                        HStack {
                            Spacer()
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(Palette.accent)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            AddDebtCategorySheet(
                categories: categoriesForDirection,
                selection: $categoryId,
                fallbackType: isOwed ? .income : .expense,
                filterLabel: isOwed ? "Ingresos" : "Gastos"
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Palette.bg)
        }
    }

    // MARK: - Teclado numérico

    private var keypad: some View {
        VStack(spacing: Space.s) {
            ForEach(keypadRows, id: \.self) { row in
                HStack(spacing: Space.s) {
                    ForEach(row, id: \.self) { key in
                        AddDebtKeypadButton(key: key) { tap(key) }
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

    private var directionOptions: [(value: DebtDirection, label: String, tint: Color)] {
        [
            (.owedToUs, "Nos deben", Palette.green),
            (.weOwe, "Debemos", Palette.pink),
        ]
    }

    private func save() {
        guard canSave, let hh = app.household?.id,
              let uid = app.profile?.id ?? SupabaseClient.shared.currentUserId else { return }
        isSaving = true
        saveError = nil

        let payload = AddDebtInsert(
            household_id: hh,
            created_by: uid,
            direction: direction.rawValue,
            person_name: person.trimmingCharacters(in: .whitespaces),
            amount: amountValue,
            amount_paid: 0,
            due_date: hasDueDate ? Self.isoDate(dueDate) : nil,
            description: note.isEmpty ? nil : note,
            category_id: categoryId,
            status: "active"
        )

        Task {
            do {
                let _: [Debt] = try await SupabaseClient.shared.insert("debts", values: payload)
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

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Payload de inserción

// `category_id` se envía siempre (nullable en el schema). El modelo `Debt` no
// decodifica category_id, pero la columna existe en la tabla, así que el insert
// es válido.
private struct AddDebtInsert: Encodable {
    let household_id: String
    let created_by: String
    let direction: String
    let person_name: String
    let amount: Double
    let amount_paid: Double
    let due_date: String?
    let description: String?
    let category_id: String?
    let status: String
}

// MARK: - Ícono principal de fila

private struct AddDebtLeadingIcon: View {
    let symbol: String
    var tint: Color = Palette.accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

// MARK: - Picker de categoría

private struct AddDebtCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    @Binding var selection: String?
    let fallbackType: TransactionType
    let filterLabel: String

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: Space.m)]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                if categories.isEmpty {
                    VStack(spacing: Space.s) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 30))
                            .foregroundStyle(Palette.inkTertiary)
                        Text("No hay categorías de este tipo")
                            .font(Typo.callout)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.m) {
                            Text("Filtrado por: \(filterLabel)")
                                .font(Typo.overline)
                                .tracking(0.8)
                                .foregroundStyle(Palette.inkTertiary)

                            LazyVGrid(columns: columns, spacing: Space.m) {
                                ForEach(categories) { cat in
                                    Button {
                                        selection = cat.id
                                        dismiss()
                                    } label: {
                                        cell(cat)
                                    }
                                    .pressable()
                                }
                            }
                        }
                        .padding(Space.l)
                    }
                }
            }
            .navigationTitle("Categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Quitar") { selection = nil; dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }.foregroundStyle(Palette.accent)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
    }

    private func cell(_ cat: Category) -> some View {
        let isSelected = selection == cat.id
        let color = TransactionVisual.color(for: cat)
        return VStack(spacing: Space.s) {
            CategoryIcon(
                systemName: TransactionVisual.symbol(for: cat, fallbackType: fallbackType),
                color: color,
                size: 48
            )
            Text(cat.name)
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

// MARK: - Botón de teclado (prefijo único)

private struct AddDebtKeypadButton: View {
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
