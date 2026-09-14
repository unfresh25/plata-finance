import SwiftUI

// Pantalla insignia: registrar un movimiento. Monto GIGANTE con teclado
// numérico propio (más elegante y controlado que el del sistema), PillToggle de
// tipo arriba, y tarjetas selectoras compactas para categoría, cuenta, fecha y
// descripción. Guarda vía Repository().addTransaction y refresca AppState.

struct AddTransactionView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @Namespace private var pillNS

    // Estado del formulario
    @State private var type: TransactionType = .expense
    @State private var amountDigits = ""          // solo dígitos (centavos implícitos = 0)
    @State private var categoryId: String?
    @State private var accountId: String?
    @State private var date = Date()
    @State private var note = ""

    // Presentación
    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                if app.accounts.isEmpty {
                    AddTxNoAccounts { dismiss() }
                } else {
                    content
                }
            }
            .navigationTitle("Nuevo movimiento")
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
        .onAppear(perform: seedDefaults)
        .onChange(of: type) { _, _ in reconcileCategoryForType() }
    }

    // MARK: - Contenido principal

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Space.xl) {
                    PillToggle(options: typeOptions, selection: $type, namespace: pillNS)
                        .padding(.top, Space.s)

                    amountDisplay
                        .padding(.vertical, Space.m)

                    selectors
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.l)
            }
            .scrollDismissesKeyboard(.interactively)

            keypad

            PrimaryButton(
                title: isSaving ? "Guardando…" : "Guardar",
                icon: isSaving ? nil : "checkmark",
                tint: canSave ? typeTint : Palette.surfaceElevated,
                fg: canSave ? Palette.bg : Palette.inkTertiary
            ) {
                save()
            }
            .disabled(!canSave || isSaving)
            .padding(.horizontal, Space.l)
            .padding(.top, Space.m)
            .padding(.bottom, Space.s)
        }
        .alert("No se pudo guardar", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(saveError ?? "Inténtalo de nuevo.")
        }
    }

    // MARK: - Monto gigante

    private var amountDisplay: some View {
        VStack(spacing: Space.xs) {
            Text(type.label.uppercased())
                .font(Typo.overline)
                .tracking(1.2)
                .foregroundStyle(typeTint)

            Text(formattedAmount)
                .font(Typo.amountHero(amountFontSize))
                .monospacedDigit()
                .foregroundStyle(amountValue > 0 ? Palette.ink : Palette.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText(value: amountValue))
                .animation(Motion.value, value: amountValue)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Selectores

    private var selectors: some View {
        VStack(spacing: Space.m) {
            // Categoría
            Button {
                showCategoryPicker = true
            } label: {
                SelectorRow(
                    leading: {
                        if let cat = selectedCategory {
                            CategoryIcon(
                                systemName: TransactionVisual.symbol(for: cat, fallbackType: type),
                                color: TransactionVisual.color(for: cat),
                                size: 36
                            )
                        } else {
                            SelectorPlaceholderIcon(symbol: "square.grid.2x2", tint: typeTint)
                        }
                    },
                    label: "Categoría",
                    value: selectedCategory?.name ?? "Seleccionar"
                )
            }
            .pressable()
            .disabled(categoriesForType.isEmpty)

            // Cuenta
            Button {
                showAccountPicker = true
            } label: {
                SelectorRow(
                    leading: {
                        SelectorPlaceholderIcon(
                            symbol: selectedAccount?.type.sfSymbol ?? "creditcard",
                            tint: Palette.sky
                        )
                    },
                    label: "Cuenta",
                    value: selectedAccount?.name ?? "Seleccionar"
                )
            }
            .pressable()

            // Fecha
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    SelectorPlaceholderIcon(symbol: "calendar", tint: Palette.purple)
                    Text("Fecha")
                        .font(Typo.callout)
                        .foregroundStyle(Palette.inkSecondary)
                    Spacer()
                    DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Palette.accent)
                }
            }

            // Descripción
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    SelectorPlaceholderIcon(symbol: "text.alignleft", tint: Palette.orange)
                    TextField(
                        "",
                        text: $note,
                        prompt: Text("Descripción (opcional)").foregroundColor(Palette.inkTertiary)
                    )
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .submitLabel(.done)
                }
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(
                categories: categoriesForType,
                selection: $categoryId,
                type: type
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Palette.bg)
        }
        .sheet(isPresented: $showAccountPicker) {
            AccountPickerSheet(accounts: app.accounts, selection: $accountId)
                .presentationDetents([.medium])
                .presentationBackground(Palette.bg)
        }
    }

    // MARK: - Teclado numérico propio

    private var keypad: some View {
        VStack(spacing: Space.s) {
            ForEach(keypadRows, id: \.self) { row in
                HStack(spacing: Space.s) {
                    ForEach(row, id: \.self) { key in
                        KeypadButton(key: key) { tap(key) }
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
            if amountDigits.isEmpty && d == "0" { return } // evita ceros a la izquierda
            amountDigits.append(d)
        case .delete:
            if !amountDigits.isEmpty { amountDigits.removeLast() }
        case .clear:
            amountDigits = ""
        }
    }

    // MARK: - Guardar

    private func save() {
        guard canSave, let accountId, let hh = app.household?.id, let uid = app.profile?.id else { return }
        isSaving = true
        saveError = nil

        let payload = NewTransaction(
            accountId: accountId,
            amount: amountValue,
            type: type,
            categoryId: type == .transfer ? nil : categoryId,
            description: note.isEmpty ? nil : note,
            date: Self.isoDate(date)
        )

        Task {
            do {
                try await Repository().addTransaction(payload, householdId: hh, userId: uid)
                await app.refreshAll()
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }

    // MARK: - Derivados

    private var typeOptions: [(value: TransactionType, label: String, tint: Color)] {
        [
            (.expense, "Gasto", Palette.pink),
            (.income, "Ingreso", Palette.green),
            (.transfer, "Transferencia", Palette.sky),
        ]
    }

    private var typeTint: Color {
        switch type {
        case .expense: return Palette.pink
        case .income: return Palette.green
        case .transfer: return Palette.sky
        }
    }

    /// Monto en unidades de moneda. Los dígitos son enteros (sin centavos), como
    /// es común en COP; el teclado escribe pesos completos.
    private var amountValue: Double {
        Double(amountDigits) ?? 0
    }

    private var formattedAmount: String {
        CurrencyFormatter.string(amountValue, currency: app.currency)
    }

    private var amountFontSize: CGFloat {
        switch formattedAmount.count {
        case ...9: return 56
        case 10...12: return 46
        case 13...15: return 38
        default: return 30
        }
    }

    private var categoriesForType: [Category] {
        let want: CategoryType = type == .income ? .income : .expense
        return app.categories.filter { $0.type == want }
    }

    private var selectedCategory: Category? {
        app.category(for: categoryId)
    }

    private var selectedAccount: Account? {
        app.accounts.first { $0.id == accountId }
    }

    private var canSave: Bool {
        amountValue > 0 && accountId != nil
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    // MARK: - Efectos

    private func seedDefaults() {
        if accountId == nil { accountId = app.accounts.first?.id }
        reconcileCategoryForType()
    }

    /// La categoría seleccionada debe coincidir con el tipo actual. Transfer no
    /// usa categoría.
    private func reconcileCategoryForType() {
        guard type != .transfer else { categoryId = nil; return }
        if let current = selectedCategory, current.type == (type == .income ? .income : .expense) {
            return
        }
        categoryId = categoriesForType.first?.id
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Teclado: modelo y botón

enum KeypadKey: Hashable {
    case digit(String)
    case delete
    case clear
}

private struct KeypadButton: View {
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

// MARK: - Fila selectora (Card) + ícono placeholder

private struct SelectorRow<Leading: View>: View {
    @ViewBuilder var leading: () -> Leading
    let label: String
    let value: String

    var body: some View {
        Card(padding: Space.m) {
            HStack(spacing: Space.m) {
                leading()
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                    Text(value)
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
}

private struct SelectorPlaceholderIcon: View {
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

private struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    @Binding var selection: String?
    let type: TransactionType

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
                        LazyVGrid(columns: columns, spacing: Space.m) {
                            ForEach(categories) { cat in
                                Button {
                                    selection = cat.id
                                    dismiss()
                                } label: {
                                    categoryCell(cat)
                                }
                                .pressable()
                            }
                        }
                        .padding(Space.l)
                    }
                }
            }
            .navigationTitle("Categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }.foregroundStyle(Palette.accent)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
    }

    private func categoryCell(_ cat: Category) -> some View {
        let isSelected = selection == cat.id
        let color = TransactionVisual.color(for: cat)
        return VStack(spacing: Space.s) {
            CategoryIcon(
                systemName: TransactionVisual.symbol(for: cat, fallbackType: type),
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
        .background(
            Palette.surface,
            in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(isSelected ? color : Palette.stroke, lineWidth: isSelected ? 1.5 : 1)
        )
    }
}

// MARK: - Picker de cuenta

private struct AccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let accounts: [Account]
    @Binding var selection: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Space.s) {
                        ForEach(accounts) { account in
                            Button {
                                selection = account.id
                                dismiss()
                            } label: {
                                accountRow(account)
                            }
                            .pressable()
                        }
                    }
                    .padding(Space.l)
                }
            }
            .navigationTitle("Cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }.foregroundStyle(Palette.accent)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
    }

    private func accountRow(_ account: Account) -> some View {
        let isSelected = selection == account.id
        let tint = Color(hexString: account.color) ?? Palette.sky
        return Card(padding: Space.m) {
            HStack(spacing: Space.m) {
                Image(systemName: account.type.sfSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(Typo.callout)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(account.type.label)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(isSelected ? Palette.accent : .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Estado sin cuentas

private struct AddTxNoAccounts: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Space.l) {
            Image(systemName: "creditcard")
                .font(.system(size: 36))
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 84, height: 84)
                .background(Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))

            VStack(spacing: Space.xs) {
                Text("Primero crea una cuenta")
                    .font(Typo.title)
                    .foregroundStyle(Palette.ink)
                Text("Necesitas al menos una cuenta (débito, efectivo, ahorros…) para registrar movimientos.")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xl)
            }

            SecondaryButton(title: "Entendido", action: onDismiss)
                .frame(maxWidth: 220)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
