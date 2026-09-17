import SwiftUI

// Crear una meta de ahorro. Paridad con app RN add-savings-goal.tsx: monto meta
// GIGANTE teñido con el color del ícono elegido, nombre, selector de ícono +
// color (presets), fecha límite opcional y cuenta vinculada opcional. Inserta en
// `savings_goals` vía SupabaseClient y refresca AppState.

struct AddGoalView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    /// Si viene una meta, la pantalla opera en MODO EDICIÓN: precarga el
    /// formulario y guarda con un UPDATE (PATCH de la fila). Si es nil, es alta
    /// normal (INSERT). Un mismo view para las dos rutas evita duplicar la UI.
    /// No se edita current_amount: eso lo mueven las contribuciones, aparte.
    var editing: SavingsGoal? = nil
    /// Garantiza que la precarga del modo edición ocurra una sola vez.
    @State private var didSeedEdit = false

    // Formulario
    @State private var amountDigits = ""
    @State private var name = ""
    @State private var preset: AddGoalPreset = AddGoalPreset.all[7] // Ahorro
    @State private var accountId: String?
    @State private var deadline = Date()
    @State private var hasDeadline = false

    @State private var showIconPicker = false
    @State private var showAccountPicker = false
    @State private var isSaving = false
    @State private var saveError: String?

    private var tint: Color { preset.color }

    private var amountValue: Double { Double(amountDigits) ?? 0 }

    private var canSave: Bool {
        amountValue > 0 && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var selectedAccount: Account? {
        app.accounts.first { $0.id == accountId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Velo tenue en vez de opaco: deja leer el material del sheet (glass).
                Palette.bg.opacity(0.6).ignoresSafeArea()
                content
            }
            .navigationTitle(editing == nil ? "Nueva meta" : "Editar meta")
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
        .onAppear(perform: seedEdit)
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

                    selectors
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.l)
            }

            keypad

            HStack(spacing: Space.m) {
                // Píldora de ícono (abre el selector visual)
                Button {
                    showIconPicker = true
                } label: {
                    HStack(spacing: Space.s) {
                        Image(systemName: preset.symbol)
                            .font(.system(size: 16, weight: .semibold))
                        Text(preset.name)
                            .font(Typo.callout)
                    }
                    .foregroundStyle(Palette.bg)
                    .padding(.horizontal, Space.l)
                    .padding(.vertical, Space.l)
                    // Píldora de acento con Liquid Glass teñido, concéntrica con el
                    // PrimaryButton (ambos cápsula) — reemplaza el relleno plano.
                    .liquidGlassTinted(tint, cornerRadius: Radius.pill)
                }
                .pressable()

                PrimaryButton(
                    title: isSaving ? "Guardando…" : (editing == nil ? "Guardar" : "Guardar cambios"),
                    icon: isSaving ? nil : "checkmark",
                    tint: canSave ? Palette.ink : Palette.surfaceElevated,
                    fg: canSave ? Palette.bg : Palette.inkTertiary
                ) {
                    save()
                }
                .disabled(!canSave || isSaving)
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.s)
            .padding(.bottom, Space.s)
        }
    }

    // MARK: - Monto meta gigante

    private var amountDisplay: some View {
        VStack(spacing: Space.xs) {
            Text("META DESEADA")
                .font(Typo.overline)
                .tracking(1.2)
                .foregroundStyle(tint)

            Text(CurrencyFormatter.string(amountValue, currency: app.currency))
                .font(Typo.amountHero(amountFontSize))
                .monospacedDigit()
                .tracking(-0.5) // tracking negativo sutil en cifra display grande
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
            // Nombre
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    AddGoalLeadingIcon(symbol: "target", tint: tint)
                    TextField(
                        "",
                        text: $name,
                        prompt: Text("¿Qué quieres lograr?").foregroundColor(Palette.inkTertiary)
                    )
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .submitLabel(.done)
                }
            }

            // Cuenta vinculada (opcional)
            Button {
                showAccountPicker = true
            } label: {
                Card(padding: Space.m) {
                    HStack(spacing: Space.m) {
                        AddGoalLeadingIcon(symbol: "building.columns.fill", tint: Palette.sky)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Cuenta vinculada")
                                .font(Typo.caption)
                                .foregroundStyle(Palette.inkTertiary)
                            Text(selectedAccount?.name ?? "Solo referencial")
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

            // Fecha límite (opcional)
            Card(padding: Space.m) {
                VStack(spacing: Space.m) {
                    HStack(spacing: Space.m) {
                        AddGoalLeadingIcon(symbol: "calendar", tint: Palette.purple)
                        Text("Fecha límite")
                            .font(Typo.callout)
                            .foregroundStyle(Palette.inkSecondary)
                        Spacer()
                        Toggle("", isOn: $hasDeadline)
                            .labelsHidden()
                            .tint(tint)
                    }
                    if hasDeadline {
                        HStack {
                            Spacer()
                            DatePicker("", selection: $deadline, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(Palette.accent)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showIconPicker) {
            AddGoalIconSheet(selection: $preset)
                .presentationDetents([.medium, .large])
                .glassSheetBackground()
        }
        .sheet(isPresented: $showAccountPicker) {
            AddGoalAccountSheet(accounts: app.accounts, selection: $accountId)
                .presentationDetents([.medium])
                .glassSheetBackground()
        }
    }

    // MARK: - Teclado numérico

    private var keypad: some View {
        VStack(spacing: Space.s) {
            ForEach(keypadRows, id: \.self) { row in
                HStack(spacing: Space.s) {
                    ForEach(row, id: \.self) { key in
                        AddGoalKeypadButton(key: key) { tap(key) }
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

    private func save() {
        // En alta se requiere household; en edición no (la fila ya existe).
        guard canSave else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let isoDeadline = hasDeadline ? Self.isoDate(deadline) : nil
        isSaving = true
        saveError = nil

        Task {
            do {
                if let goal = editing {
                    // UPDATE: PATCH de la fila. current_amount NO se toca aquí (lo
                    // mueven las contribuciones). No inventamos lógica de saldo: el
                    // alta tampoco tocaba cuentas, solo insertaba la fila.
                    let patch = AddGoalPatch(
                        name: trimmedName,
                        target_amount: amountValue,
                        deadline: isoDeadline,
                        icon: preset.symbol,
                        color: preset.hex,
                        account_id: accountId
                    )
                    try await SupabaseClient.shared.update(
                        "savings_goals", values: patch, match: ["id": goal.id]
                    )
                } else {
                    guard let hh = app.household?.id else { isSaving = false; return }
                    let payload = AddGoalInsert(
                        household_id: hh,
                        name: trimmedName,
                        target_amount: amountValue,
                        current_amount: 0,
                        deadline: isoDeadline,
                        icon: preset.symbol,
                        color: preset.hex,
                        account_id: accountId,
                        status: "active"
                    )
                    let _: [SavingsGoal] = try await SupabaseClient.shared.insert("savings_goals", values: payload)
                }
                await app.refreshAll()
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }

    /// Modo edición: vuelca los valores de la meta en el formulario (una sola vez).
    private func seedEdit() {
        guard let goal = editing, !didSeedEdit else { return }
        didSeedEdit = true
        name = goal.name
        amountDigits = String(Int(goal.targetAmount.rounded()))
        accountId = goal.accountId
        if let raw = goal.deadline, let d = Self.parseISO(raw) {
            deadline = d
            hasDeadline = true
        }
        // Preseleccionar el preset por ícono; si no hay coincidencia, por color;
        // y si nada casa, deja el default (el ícono/color de la meta igual se
        // envían tal cual en el patch vía preset.symbol/hex).
        if let match = AddGoalPreset.all.first(where: { $0.symbol == goal.icon })
            ?? AddGoalPreset.all.first(where: { $0.hex.caseInsensitiveCompare(goal.color) == .orderedSame }) {
            preset = match
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    /// Parsea la fecha almacenada (yyyy-MM-dd, o ISO completa) a Date local.
    private static func parseISO(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: String(s.prefix(10))) { return d }
        return ISO8601DateFormatter().date(from: s)
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Presets de ícono + color (paridad con GOAL_ICONS del original)

struct AddGoalPreset: Identifiable, Hashable {
    let id: String
    let symbol: String
    let name: String
    let color: Color
    let hex: String

    /// Presets de meta: ícono + nombre + un color de la paleta ÚNICA de
    /// personalización (CustomPalette), la misma de cuentas y categorías. Los
    /// índices eligen colores bien separados (evita vecinos parecidos).
    static let all: [AddGoalPreset] = {
        let sw = CustomPalette.swatches
        let specs: [(icon: String, name: String, i: Int)] = [
            ("airplane", "Viaje", 2),        // Blue
            ("house.fill", "Vivienda", 10),  // Plum
            ("car.fill", "Vehículo", 3),     // Amber
            ("laptopcomputer", "Tecnología", 0), // Teal
            ("heart.fill", "Salud", 1),      // Coral
            ("book.fill", "Estudios", 11),   // Cyan
            ("star.fill", "Retiro", 4),      // Rose
            ("banknote.fill", "Ahorro", 5),  // Green
        ]
        return specs.enumerated().map { idx, s in
            AddGoalPreset(id: "\(idx + 1)", symbol: s.icon, name: s.name,
                          color: sw[s.i].color, hex: sw[s.i].hex)
        }
    }()
}

// MARK: - Payload de inserción

private struct AddGoalInsert: Encodable {
    let household_id: String
    let name: String
    let target_amount: Double
    let current_amount: Double
    let deadline: String?
    let icon: String
    let color: String
    let account_id: String?
    let status: String
}

// MARK: - Payload de edición (PATCH)
//
// Mismas columnas editables que el Insert, en snake_case. Se omiten id,
// household_id, current_amount y status (no editables desde este formulario).

private struct AddGoalPatch: Encodable {
    let name: String
    let target_amount: Double
    let deadline: String?
    let icon: String
    let color: String
    let account_id: String?
}

// MARK: - Ícono principal de fila

private struct AddGoalLeadingIcon: View {
    let symbol: String
    var tint: Color = Palette.accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            // Radio 36*0.32 = concéntrico con CategoryIcon(size:36) al intercambiarse.
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 11.5, style: .continuous))
    }
}

// MARK: - Selector de ícono visual

private struct AddGoalIconSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: AddGoalPreset

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: Space.m)]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.opacity(0.6).ignoresSafeArea()
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Space.m) {
                        ForEach(AddGoalPreset.all) { p in
                            Button {
                                selection = p
                                dismiss()
                            } label: {
                                cell(p)
                            }
                            .pressable()
                        }
                    }
                    .padding(Space.l)
                }
            }
            .navigationTitle("Elige un ícono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }.foregroundStyle(Palette.accent)
                }
            }
        }
        .tint(Palette.accent)
    }

    private func cell(_ p: AddGoalPreset) -> some View {
        let isSelected = selection.id == p.id
        return VStack(spacing: Space.s) {
            CategoryIcon(systemName: p.symbol, color: p.color, size: 48)
            Text(p.name)
                .font(Typo.caption)
                .foregroundStyle(isSelected ? Palette.ink : Palette.inkSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.m)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(isSelected ? p.color : Palette.stroke, lineWidth: isSelected ? 1.5 : 1)
        )
    }
}

// MARK: - Selector de cuenta vinculada

private struct AddGoalAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    let accounts: [Account]
    @Binding var selection: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.opacity(0.6).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Space.s) {
                        // Ninguna
                        Button {
                            selection = nil
                            dismiss()
                        } label: {
                            Card(padding: Space.m) {
                                HStack(spacing: Space.m) {
                                    AddGoalLeadingIcon(symbol: "circle.slash", tint: Palette.inkSecondary)
                                    Text("Ninguna (solo referencial)")
                                        .font(Typo.callout)
                                        .foregroundStyle(Palette.inkSecondary)
                                    Spacer()
                                    if selection == nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Palette.accent)
                                    }
                                }
                            }
                        }
                        .pressable()

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
            .navigationTitle("Cuenta vinculada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }.foregroundStyle(Palette.accent)
                }
            }
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

// MARK: - Botón de teclado (prefijo único)

private struct AddGoalKeypadButton: View {
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
